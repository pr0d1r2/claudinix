#!/usr/bin/env bash
# Rebase one claude/* pull request onto main in a fresh cloud session,
# from your terminal (SPEC scripts:T126, .:C29).
#
# PR is a number or a GitHub pull request URL. `gh pr view` must find it
# open, with a `claude/*` head (the only branches a cloud session may
# push) and `main` as its base; anything else is refused before a
# session starts.
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
# The prompt is cloud-rebase-prompt.txt with @PR@, @URL@, @BRANCH@ and
# @BASE@ filled in. The session rebases the branch, re-writes generated
# files instead of merging them by hand, runs the gate, and pushes with
# --force-with-lease to the same branch; it opens no new pull request and
# merges nothing. This does not wait for the session; follow it at
# claude.ai/code.
#
# Usage: cloud-rebase.sh <PR# | URL> [--model M] [--yes] [--dry-run]
# Env:   CLOUD_TASK_REMOTE  remote that must hold the branch (default origin)
#        CLAUDINIX_SCRIPTS  dir holding cloud-rebase-prompt.txt and
#                           config.sh (default: here)

set -euo pipefail

usage() {
    echo "usage: cloud-rebase.sh <PR# | URL> [--model M] [--yes] [--dry-run]" >&2
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

if [[ "$arg" =~ ^[0-9]+$ ]]; then
    pr="$arg"
elif [[ "$arg" =~ ^https://github\.com/[^/]+/[^/]+/pull/([0-9]+)/?$ ]]; then
    pr="${BASH_REMATCH[1]}"
else
    usage
fi

lib="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"
remote="${CLOUD_TASK_REMOTE:-origin}"

if ! info="$(gh pr view "$pr" --json number,state,headRefName,baseRefName,url \
    --jq '[.number, .state, .headRefName, .baseRefName, .url] | @tsv')"; then
    echo "rebase: gh could not read pull request #$pr -- check the number and that gh is signed in" >&2
    exit 1
fi
IFS="$(printf '\t')" read -r _ state head base url <<<"$info"

if [ "$state" != OPEN ]; then
    echo "rebase: #$pr is $state, not OPEN -- nothing to rebase" >&2
    exit 1
fi
case "$head" in
claude/*) ;;
*)
    echo "rebase: #$pr's branch is $head; a cloud session may push only claude/* branches" >&2
    exit 1
    ;;
esac
if [ "$base" != main ]; then
    echo "rebase: #$pr targets $base, not main -- rebase it by hand" >&2
    exit 1
fi

if ! git remote get-url "$remote" >/dev/null 2>&1; then
    echo "rebase: no remote $remote -- push the project to GitHub first" >&2
    exit 1
fi

# The session clones GitHub: the branch must be there as it is here.
if ! current="$(git symbolic-ref --quiet --short HEAD)"; then
    echo "rebase: HEAD is detached -- check out the branch the session should clone" >&2
    exit 1
fi
if ! upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
    echo "rebase: branch $current is not pushed (no upstream) -- push it first: git push -u $remote $current" >&2
    exit 1
fi
if [ "$(git rev-parse HEAD)" != "$(git rev-parse '@{u}')" ]; then
    echo "rebase: branch $current is not up to date with $upstream -- push (or pull) first" >&2
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
prompt="$(cat "$lib/cloud-rebase-prompt.txt")"
fill @PR@ "$pr"
fill @BASE@ "$base"
fill @BRANCH@ "$head"
fill @URL@ "$url"

if [ "$dry" = 1 ]; then
    printf 'claude --cloud %q --model %q\n' "$prompt" "$model"
    exit 0
fi

if [ "$yes" = 0 ]; then
    printf 'rebase: this starts a billed Claude Code cloud session (model %s) to rebase #%s (%s) onto %s. Start it? [y/N] ' "$model" "$pr" "$head" "$base"
    answer=
    IFS= read -r answer || true
    case "$answer" in
    y | Y | yes) ;;
    *)
        echo "rebase: not started" >&2
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

echo "cloud: started the rebase of #$pr ($head) onto $base; it force-pushes $head with a lease -- follow it at claude.ai/code"
