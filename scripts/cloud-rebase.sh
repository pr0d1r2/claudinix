#!/usr/bin/env bash
# Rebase one pull request onto main in a fresh cloud session,
# from your terminal (SPEC scripts:T126, scripts:T145, .:C29).
#
# PR is a number or a GitHub pull request URL. `gh pr view` must find it
# open, from this repository (not a fork), with `main` as its base and a
# head that is any branch but `main` with a plain name (letters, digits,
# ._/-), as cloud-fixup.sh checks it; a URL must name the remote's
# repository (case folded). Anything else is refused before a session
# starts.
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

# shellcheck source=/dev/null # lib/cloud-launch.sh, beside this script
source "$(dirname "${BASH_SOURCE[0]}")/lib/cloud-launch.sh"
pr= # set by cloud_parse_pr
cloud_parse_pr "$arg" || usage

lib="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"
remote="${CLOUD_TASK_REMOTE:-origin}"

cloud_require_remote rebase "$remote" || exit 1
remote_url="$(git remote get-url "$remote")"
if [ -n "$url_repo" ]; then
    # owner/repo of the remote, from https://github.com/o/r(.git) or
    # git@github.com:o/r(.git).
    repo="${remote_url%.git}"
    repo="${repo#*github.com[:/]}"
    # GitHub names ignore case; `tr`, as bash 3.2 has no ${var,,}.
    if [ "$(printf %s "$url_repo" | tr '[:upper:]' '[:lower:]')" != "$(printf %s "$repo" | tr '[:upper:]' '[:lower:]')" ]; then
        echo "rebase: $arg is a pull request of $url_repo, but $remote is $repo -- run it from that repository's checkout" >&2
        exit 1
    fi
fi

if ! info="$(gh pr view "$pr" --json number,state,headRefName,baseRefName,url,isCrossRepository \
    --jq '[.number, .state, .headRefName, .baseRefName, .url, .isCrossRepository] | @tsv' </dev/null)"; then
    echo "rebase: gh could not read pull request #$pr -- check the number and that gh is signed in" >&2
    exit 1
fi
IFS="$(printf '\t')" read -r _ state head base url cross <<<"$info"

if [ "$state" != OPEN ]; then
    echo "rebase: #$pr is $state, not OPEN -- nothing to rebase" >&2
    exit 1
fi
if [ "$cross" = true ]; then
    echo "rebase: #$pr is from a fork; its branch $head is not a branch of $remote -- rebase it by hand" >&2
    exit 1
fi
if [ "$head" = main ]; then
    echo "rebase: #$pr's branch is main; a cloud session never pushes main" >&2
    exit 1
fi
if [[ ! "$head" =~ ^[A-Za-z0-9._/-]+$ ]]; then
    echo "rebase: #$pr's branch $head is not a plain branch name (letters, digits, ._/-) -- it would reach the session's commands" >&2
    exit 1
fi
if [ "$base" != main ]; then
    echo "rebase: #$pr targets $base, not main -- rebase it by hand" >&2
    exit 1
fi

cloud_require_pushed_branch rebase "$remote" || exit 1
cloud_resolve_model "$lib" || exit "$?"

prompt="$(cat "$lib/cloud-rebase-prompt.txt")"
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
    cloud_confirm rebase "$(printf 'rebase: this starts a billed Claude Code cloud session (model %s) to rebase #%s (%s) onto %s. Start it? [y/N] ' "$model" "$pr" "$head" "$base")" || exit 1
fi

cloud_launch "$prompt" "$model"

echo "cloud: started the rebase of #$pr ($head) onto $base; it force-pushes $head with a lease -- follow it at claude.ai/code"
