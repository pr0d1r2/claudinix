#!/usr/bin/env bash
# Fix up one pull request's review findings in a fresh cloud session,
# from your terminal (SPEC scripts:T132, .:C29).
#
# PR is a number or a GitHub pull request URL of this repository (a URL
# of another repository is refused, so the wrong pull request is never
# fixed up). `gh pr view` must find it open, based on `main`, with a head
# other than `main` whose name is a plain ref (letters, digits, `._/-`):
# the name goes into the session's prompt and commands, and its author
# chose it.
#
# The launch rules are cloud-task.sh's: the remote must exist, the
# current branch must be pushed and equal to its upstream (the session
# clones GitHub, not this disk), and a y/N answer must confirm that a
# billed cloud session starts; --yes skips only that question. --dry-run
# runs the same checks, then prints the exact claude command
# (shell-quoted, pasteable) instead of asking or launching. The model:
# --model, else the project's .claudinix.toml session.model
# (scripts/config.sh, scripts:V34), else sonnet.
#
# The prompt is cloud-fixup-prompt.txt with @PR@, @URL@, @BRANCH@ and
# @BASE@ filled in. The session works through the findings one at a
# time, each fixed in its own commits or declined with a reason, runs the
# gate, pushes to the same branch without force, gives a thumbs-up to
# each comment whose findings it fixed, and replies once. It merges and
# approves nothing. This does not wait for the session; follow it at
# claude.ai/code.
#
# Usage: cloud-fixup.sh <PR# | URL> [--model M] [--yes] [--dry-run]
# Env:   CLOUD_TASK_REMOTE  remote that must hold the branch (default origin)
#        CLAUDINIX_SCRIPTS  dir holding cloud-fixup-prompt.txt and
#                           config.sh (default: here)

set -euo pipefail

usage() {
    echo "usage: cloud-fixup.sh <PR# | URL> [--model M] [--yes] [--dry-run]" >&2
    exit 2
}

arg=
model=
yes=0
dry=0
while [ "$#" -gt 0 ]; do
    case "$1" in
    --model)
        [ "$#" -ge 2 ] || usage
        model="$2"
        shift
        ;;
    --yes) yes=1 ;;
    --dry-run) dry=1 ;;
    -*) usage ;;
    *)
        [ -z "$arg" ] || usage
        arg="$1"
        ;;
    esac
    shift
done
[ -n "$arg" ] || usage

url_repo=
if [[ "$arg" =~ ^[0-9]+$ ]]; then
    pr="$arg"
elif [[ "$arg" =~ ^https://github\.com/([^/]+/[^/]+)/pull/([0-9]+)/?$ ]]; then
    url_repo="${BASH_REMATCH[1]}"
    pr="${BASH_REMATCH[2]}"
else
    usage
fi

lib="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"
remote="${CLOUD_TASK_REMOTE:-origin}"

if ! remote_url="$(git remote get-url "$remote" 2>/dev/null)"; then
    echo "fixup: no remote $remote -- push the project to GitHub first" >&2
    exit 1
fi
if [ -n "$url_repo" ]; then
    # owner/repo of the remote, from https://github.com/o/r(.git) or
    # git@github.com:o/r(.git).
    repo="${remote_url%.git}"
    repo="${repo#*github.com[:/]}"
    if [ "$url_repo" != "$repo" ]; then
        echo "fixup: $arg is a pull request of $url_repo, but $remote is $repo -- run it from that repository's checkout" >&2
        exit 1
    fi
fi

# </dev/null: gh must not share the terminal the y/N answer comes from (B19).
if ! info="$(gh pr view "$pr" --json number,state,headRefName,baseRefName,url \
    --jq '[.number, .state, .headRefName, .baseRefName, .url] | @tsv' </dev/null)"; then
    echo "fixup: gh could not read pull request #$pr -- check the number and that gh is signed in" >&2
    exit 1
fi
IFS="$(printf '\t')" read -r _ state head base url <<<"$info"

if [ "$state" != OPEN ]; then
    echo "fixup: #$pr is $state, not OPEN -- nothing to fix up" >&2
    exit 1
fi
if [ "$base" != main ]; then
    echo "fixup: #$pr targets $base, not main -- fix it up by hand" >&2
    exit 1
fi
if [ "$head" = main ]; then
    echo "fixup: #$pr's branch is main; a cloud session never pushes main" >&2
    exit 1
fi
if [[ ! "$head" =~ ^[A-Za-z0-9._/-]+$ ]]; then
    echo "fixup: #$pr's branch $head is not a plain branch name (letters, digits, ._/-) -- it would reach the session's commands" >&2
    exit 1
fi

# The session clones GitHub: the branch must be there as it is here.
if ! current="$(git symbolic-ref --quiet --short HEAD)"; then
    echo "fixup: HEAD is detached -- check out the branch the session should clone" >&2
    exit 1
fi
if ! upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
    echo "fixup: branch $current is not pushed (no upstream) -- push it first: git push -u $remote $current" >&2
    exit 1
fi
if [ "$(git rev-parse HEAD)" != "$(git rev-parse '@{u}')" ]; then
    echo "fixup: branch $current is not up to date with $upstream -- push (or pull) first" >&2
    exit 1
fi

if [ -z "$model" ]; then
    model="$(bash "$lib/config.sh" get session.model)" || exit "$?"
fi

# fill KEY VALUE: replace every KEY in $prompt with VALUE, as written
# (see cloud-task.sh for why not ${prompt//KEY/VALUE}).
fill() {
    local text="$prompt" out=
    while [[ "$text" == *"$1"* ]]; do
        out="$out${text%%"$1"*}$2"
        text="${text#*"$1"}"
    done
    prompt="$out$text"
}
prompt="$(cat "$lib/cloud-fixup-prompt.txt")"
fill @PR@ "$pr"
fill @BASE@ "$base"
fill @BRANCH@ "$head"
fill @URL@ "$url"

if [ "$dry" = 1 ]; then
    printf 'claude --cloud %q --model %q\n' "$prompt" "$model"
    exit 0
fi

if [ "$yes" = 0 ]; then
    # Drop what the terminal left in the input buffer, so only the typed
    # answer is read (B19). Whole seconds: macOS /bin/bash 3.2 has no
    # fractional -t.
    if [ -t 0 ]; then
        while IFS= read -r -t 1 _; do :; done
    fi
    printf 'fixup: this starts a billed Claude Code cloud session (model %s) that commits fixes for the review findings of #%s and pushes them to %s. Start it? [y/N] ' "$model" "$pr" "$head"
    answer=
    IFS= read -r answer || true
    case "$answer" in
    y | Y | yes) ;;
    *)
        echo "fixup: not started" >&2
        exit 1
        ;;
    esac
fi

# util-linux `script` takes the command as a string, BSD `script` as
# arguments; both get a TTY for claude.
if script --version >/dev/null 2>&1; then
    # shellcheck disable=SC2016 # script's shell expands these, not this one
    CLOUD_TASK_PROMPT="$prompt" CLOUD_TASK_MODEL="$model" script -q -e \
        -c 'claude --cloud "$CLOUD_TASK_PROMPT" --model "$CLOUD_TASK_MODEL"' /dev/null
else
    script -q /dev/null claude --cloud "$prompt" --model "$model"
fi

echo "cloud: started the fixup of #$pr ($head); it pushes its commits there and thumbs-up the comments it fixed -- follow it at claude.ai/code"
