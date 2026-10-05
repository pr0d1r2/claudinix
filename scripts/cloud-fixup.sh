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
# The launch rules are lib/cloud-launch.sh's: the remote must exist, the
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

# shellcheck source=/dev/null # lib/cloud-launch.sh, beside this script
source "$(dirname "${BASH_SOURCE[0]}")/lib/cloud-launch.sh"
pr= # set by cloud_parse_pr
cloud_parse_pr "$arg" || usage

lib="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"
remote="${CLOUD_TASK_REMOTE:-origin}"

cloud_require_remote fixup "$remote" || exit 1
remote_url="$(git remote get-url "$remote")"
if [ -n "$url_repo" ]; then
    # owner/repo of the remote, from https://github.com/o/r(.git) or
    # git@github.com:o/r(.git).
    repo="${remote_url%.git}"
    repo="${repo#*github.com[:/]}"
    # GitHub names ignore case; `tr`, as bash 3.2 has no ${var,,}.
    if [ "$(printf %s "$url_repo" | tr '[:upper:]' '[:lower:]')" != "$(printf %s "$repo" | tr '[:upper:]' '[:lower:]')" ]; then
        echo "fixup: $arg is a pull request of $url_repo, but $remote is $repo -- run it from that repository's checkout" >&2
        exit 1
    fi
fi

# </dev/null: gh must not share the terminal the y/N answer comes from (B19).
if ! info="$(gh pr view "$pr" --json number,state,headRefName,baseRefName,url,isCrossRepository \
    --jq '[.number, .state, .headRefName, .baseRefName, .url, .isCrossRepository] | @tsv' </dev/null)"; then
    echo "fixup: gh could not read pull request #$pr -- check the number and that gh is signed in" >&2
    exit 1
fi
IFS="$(printf '\t')" read -r _ state head base url cross <<<"$info"

if [ "$state" != OPEN ]; then
    echo "fixup: #$pr is $state, not OPEN -- nothing to fix up" >&2
    exit 1
fi
if [ "$cross" = true ]; then
    echo "fixup: #$pr is from a fork; its branch $head is not a branch of $remote -- fix it up by hand" >&2
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

cloud_require_pushed_branch fixup "$remote" || exit 1
cloud_resolve_model "$lib" || exit "$?"

prompt="$(cat "$lib/cloud-fixup-prompt.txt")"
cloud_fill @PR@ "$pr"
cloud_fill @BASE@ "$base"
cloud_fill @BRANCH@ "$head"
cloud_fill @URL@ "$url"

if [ "$dry" = 1 ]; then
    printf 'claude --cloud %q --model %q\n' "$prompt" "$model"
    exit 0
fi

if [ "$yes" = 0 ]; then
    cloud_flush_input
    cloud_confirm fixup "$(printf 'fixup: this starts a billed Claude Code cloud session (model %s) that commits fixes for the review findings of #%s and pushes them to %s. Start it? [y/N] ' "$model" "$pr" "$head")" || exit 1
fi

cloud_launch "$prompt" "$model"

echo "cloud: started the fixup of #$pr ($head); it pushes its commits there and gives a thumbs-up to the comments it fixed -- follow it at claude.ai/code"
