#!/usr/bin/env bash
# The RED commit precedes the GREEN one (SPEC C17).
#
# For every commit in the range that ADDS a tracked `*.sh`, the mirrored
# `tests/unit/<same path>.bats` must already exist in the commit's parent.
# Added in the same commit, the test was written with the script in view
# and nobody can show it ever failed. Renames are detected (-M), so moving
# a script adds no code. Modifying a script (REFACTOR) is not policed.
# Adapted from pr0d1r2/xenolith scripts/guard/tdd-order.sh at 8f35175
# (SPEC C17: no flake export exists).
#
# Usage: tdd-order.sh [REV_RANGE]
#   default: @{upstream}..HEAD (what a push publishes), else all of HEAD.
# Needs full history: a shallow clone hides the RED commits (SPEC C8).

set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "tdd-order: not inside a git work tree -- nothing could be checked. This is a failure, not a pass." >&2
    exit 1
fi

if [ "$#" -gt 1 ]; then
    echo "usage: tdd-order.sh [REV_RANGE]" >&2
    exit 2
fi

range="${1:-}"
if [ -z "$range" ]; then
    if git rev-parse --verify --quiet '@{upstream}' >/dev/null 2>&1; then
        range='@{upstream}..HEAD'
    else
        range='HEAD'
    fi
fi

if ! commits="$(git rev-list --reverse "$range" 2>/dev/null)"; then
    echo "tdd-order: cannot resolve the range $range -- nothing was checked, which is a failure rather than a pass." >&2
    exit 1
fi

status=0

fail() {
    echo "tdd-order: $1" >&2
    status=1
}

for commit in $commits; do
    short="$(git rev-parse --short "$commit")"
    while IFS= read -r file; do
        case "$file" in
        tests/*) continue ;;
        *.sh) ;;
        *) continue ;;
        esac
        mirror="tests/unit/${file%.sh}.bats"
        if git cat-file -e "$commit^:$mirror" 2>/dev/null; then
            continue
        fi
        if git cat-file -e "$commit:$mirror" 2>/dev/null; then
            fail "$short adds $file and its test $mirror in the SAME commit -- commit the failing test first (RED)"
        else
            fail "$short adds $file before $mirror existed -- commit the failing test first (RED)"
        fi
    done < <(git show -M --diff-filter=A --name-only --pretty=format: "$commit")
done

exit "$status"
