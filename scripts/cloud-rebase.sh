#!/usr/bin/env bash
# Rebase one pull request onto main in a fresh cloud session,
# from your terminal (SPEC scripts:T126, scripts:T145, .:C29).
#
# PR is a number or a GitHub pull request URL. `gh pr view` must find it
# open, from this repository (not a fork), with `main` as its base and a
# head that is any branch but `main` with a plain name (letters, digits,
# ._/-); a URL must name the remote's repository (case folded). Both are
# cloud_require_open_pr's checks (lib/cloud-launch.sh); anything else is
# refused before a session starts.
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
head=""
base=""
url="" # head, base and url: set by cloud_require_open_pr
cloud_parse_pr "$arg" || usage

lib="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"
remote="${CLOUD_TASK_REMOTE:-origin}"

cloud_require_remote rebase "$remote" || exit 1
cloud_require_open_pr rebase "$remote" "$arg" || exit 1

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
