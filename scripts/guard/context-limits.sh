#!/usr/bin/env bash
# No token ceiling raised to get green (SPEC gate:C20, scripts:T150).
#
# Compares `.context-limits` at HEAD with the same file at the merge base
# of HEAD and BASE (default `origin/main`, seam CONTEXT_LIMITS_BASE),
# judged per chain (gate:V67, scripts:T185, B120): a chain row raised, a
# file row raised while its node's chain row does not fall, a chain row
# added above the largest base chain, a file row added without its node's
# chain row, or the file deleted fails, each one named. A split that
# shrinks every chain passes. There is no override: a raise is the owner's
# call, made on the merge side, where `just merge` still stops on any
# raised or added row (cloud:V51, scripts:B81). context_limits_judge in
# scripts/lib reads both files.
#
# Usage: context-limits.sh [BASE]
# A shallow clone hides the merge base, so it is refused with the fix
# (scripts:V29); a missing BASE checks nothing and fails (.:V18).

set -euo pipefail

# shellcheck source=/dev/null # the shallow-clone refusal, in scripts/lib
source "$(dirname "${BASH_SOURCE[0]}")/../lib/require-full-history.sh"

# shellcheck source=/dev/null # the row parser, in scripts/lib
source "$(dirname "${BASH_SOURCE[0]}")/../lib/context-limits.sh"

if [ "$#" -gt 1 ]; then
    echo "usage: context-limits.sh [BASE]" >&2
    exit 2
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "context-limits: not inside a git work tree -- nothing was checked, which is a failure rather than a pass." >&2
    exit 1
fi

require_full_history context-limits "the merge base with the base branch may be missing, so nothing was checked" || exit 1

base="${1:-${CONTEXT_LIMITS_BASE:-origin/main}}"
if ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
    echo "context-limits: cannot resolve the base $base -- nothing was checked, which is a failure rather than a pass. run: git fetch origin" >&2
    exit 1
fi
if ! fork="$(git merge-base HEAD "$base")"; then
    echo "context-limits: HEAD and $base share no commit -- nothing was checked, which is a failure rather than a pass." >&2
    exit 1
fi

# Judged per chain (gate:V67): both files whole, not the row diff. A file
# absent at a side is empty there; one present but unreadable fails (.:V18).
base_rows="" head_rows="" had_base=""
for side in "$fork" HEAD; do
    # The tree entry tells absent from unreadable; cat-file -e cannot.
    if ! entry="$(git ls-tree --full-tree "$side" -- .context-limits)"; then
        echo "context-limits: cannot list the tree at $side -- gate could not run, which is a failure rather than a pass." >&2
        exit 1
    fi
    [ -n "$entry" ] || continue
    [ "$side" = HEAD ] || had_base=1
    if ! rows="$(git show "$side:.context-limits")"; then
        echo "context-limits: cannot read .context-limits at $side -- gate could not run, which is a failure rather than a pass." >&2
        exit 1
    fi
    if [ "$side" = HEAD ]; then head_rows="$rows"; else base_rows="$rows"; fi
done
if ! reasons="$(context_limits_judge <(printf '%s\n' "$base_rows") <(printf '%s\n' "$head_rows"))"; then
    echo "context-limits: the per-chain judge failed -- gate could not run, which is a failure rather than a pass." >&2
    exit 1
fi
if [ -n "$had_base" ] && [ -z "$(git ls-tree --full-tree HEAD -- .context-limits)" ]; then
    reasons+=$'\ndiff: deletes .context-limits'
fi
[ -n "${reasons//$'\n'/}" ] || exit 0

while IFS= read -r reason; do
    [ -n "$reason" ] || continue
    echo "context-limits: this branch ${reason#diff: } (vs $base)" >&2
done <<<"$reasons"
echo "context-limits: never raise a ceiling to get green -- move rows down to the node that owns them, or archive done tasks. A raise is the owner's call, made on the merge side." >&2
exit 1
