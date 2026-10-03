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
#   default: @{upstream}..HEAD (what a push publishes); with no upstream,
#   $(git merge-base HEAD origin/HEAD)..HEAD (this branch); else all of
#   HEAD.
# A shallow clone hides the RED commits and makes its oldest commit look
# like it adds every script, so it is refused with the fix (V29, B7).
# A refusal prints a split recipe that needs no interactive rebase.

set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "tdd-order: not inside a git work tree -- nothing could be checked. This is a failure, not a pass." >&2
    exit 1
fi

if [ "$#" -gt 1 ]; then
    echo "usage: tdd-order.sh [REV_RANGE]" >&2
    exit 2
fi

if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
    echo "tdd-order: this clone is shallow -- the commits before its oldest one are missing, so the RED commits cannot be seen and nothing was checked. run: git fetch --unshallow" >&2
    exit 1
fi

range="${1:-}"
if [ -z "$range" ]; then
    if git rev-parse --verify --quiet '@{upstream}' >/dev/null 2>&1; then
        range='@{upstream}..HEAD'
    elif git rev-parse --verify --quiet refs/remotes/origin/HEAD >/dev/null &&
        base="$(git merge-base HEAD refs/remotes/origin/HEAD)"; then
        range="$base..HEAD"
    else
        range='HEAD'
    fi
fi

if ! commits="$(git rev-list --reverse "$range" 2>/dev/null)"; then
    echo "tdd-order: cannot resolve the range $range -- nothing was checked, which is a failure rather than a pass." >&2
    exit 1
fi

status=0
# The first offence, for the recipe: commit, mirror, where the test is.
first=
first_mirror=
first_source=

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
            source="$short"
        else
            fail "$short adds $file before $mirror existed -- commit the failing test first (RED)"
            source=HEAD
        fi
        if [ -z "$first" ]; then
            first="$short"
            first_mirror="$mirror"
            first_source="$source"
        fi
    done < <(git show -M --diff-filter=A --name-only --pretty=format: "$commit")
done

if [ -n "$first" ]; then
    branch="$(git symbolic-ref --quiet --short HEAD || git rev-parse --short HEAD)"
    {
        echo "tdd-order: to split $first into RED then GREEN (no interactive rebase), run from a clean tree:"
        echo "    git switch -c tdd-split $first^"
        echo "    git restore --source=$first_source --staged --worktree -- $first_mirror"
        echo "    git commit -m \"test: $first_mirror (RED, split from $first)\" -m \"Why: the test must fail before the script exists (C17).\" -m \"Refs: §C.17\""
        echo "    git restore --source=$first --staged --worktree -- :/"
        echo "    git commit -C $first"
        if [ "$(git rev-parse "$first")" != "$(git rev-parse HEAD)" ]; then
            echo "    git cherry-pick $first..$branch"
        fi
        if git symbolic-ref --quiet HEAD >/dev/null; then
            echo "    git branch -f $branch tdd-split"
            echo "    git switch $branch"
            echo "    git branch -D tdd-split"
        fi
        if [ "$first_source" = HEAD ]; then
            echo "tdd-order: the commit that later added $first_mirror may now conflict or come out empty: keep the test, and 'git cherry-pick --skip' an empty one."
        fi
        echo "tdd-order: then rerun this check; repeat for any other commit named above."
    } >&2
fi

exit "$status"
