#!/usr/bin/env bash
# Print the one-line setup script for the claude.ai environment dialog
# (SPEC T24, T69, V20, C19): download setup.sh at a fixed commit into a
# fresh temp dir and run it with the same SHA, which pins the agent home
# too. A bump is a new SHA in this line and nothing else.
#
# Only a commit whose newest CI run on the default branch succeeded gets
# a line: CI is what pushes its agent home to cachix (C19). No run, a run
# still going, a failed one, or a gh that cannot answer all refuse;
# `--force` prints the line anyway and says why it should not have.
#
# Usage: setup-line.sh [--force] [REV]   (default: HEAD)
# Env:   GH_BIN   the GitHub CLI (default: gh); used read-only
# Needs: git, gh (signed in), jq

set -euo pipefail

usage() {
    echo "usage: setup-line.sh [--force] [REV]" >&2
    exit 2
}

repo=pr0d1r2/nix-claude-code-cloud
branch=main
workflow=ci.yml
gh="${GH_BIN:-gh}"

force=0
rev=
while [ "$#" -gt 0 ]; do
    case "$1" in
    --force) force=1 ;;
    -*) usage ;;
    *)
        [ -z "$rev" ] || usage
        rev="$1"
        ;;
    esac
    shift
done
rev="${rev:-HEAD}"

if ! sha="$(git rev-parse --verify --quiet "$rev^{commit}")"; then
    echo "setup-line: cannot resolve $rev to a commit -- no line printed" >&2
    exit 1
fi

# ci_state: prints the newest run's "status conclusion", "none" when
# there is no run, and fails when gh cannot answer.
ci_state() {
    local runs
    command -v "$gh" >/dev/null 2>&1 || return 1
    runs="$("$gh" run list --repo "$repo" --commit "$sha" --branch "$branch" \
        --workflow "$workflow" --json conclusion,status)" || return 1
    jq -r 'if length == 0 then "none" else .[0] | "\(.status) \(.conclusion)" end' <<<"$runs"
}

problem=
if ! state="$(ci_state)"; then
    problem="could not ask GitHub about CI for $sha (is gh installed and signed in?)"
elif [ "$state" = none ]; then
    problem="no CI run on $branch for $sha (is it pushed and merged?)"
elif [ "$state" != "completed success" ]; then
    problem="CI on $branch for $sha is not green (newest run: $state)"
fi

if [ -n "$problem" ]; then
    if [ "$force" = 0 ]; then
        echo "setup-line: $problem -- no line printed; pass --force to print it anyway" >&2
        exit 1
    fi
    echo "setup-line: WARNING: $problem -- printing the line anyway (--force)" >&2
fi

raw="https://raw.githubusercontent.com/$repo/$sha/setup.sh"
# shellcheck disable=SC2016 # printed for the UI shell to expand, not here
printf 'd=$(mktemp -d) && curl -fsSL %s -o "$d/setup.sh" && bash "$d/setup.sh" %s\n' "$raw" "$sha"
