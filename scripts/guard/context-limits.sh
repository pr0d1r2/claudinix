#!/usr/bin/env bash
# No token ceiling raised to get green (SPEC .:C20, scripts:T150).
#
# Compares `.context-limits` at HEAD with the same file at the merge base
# of HEAD and BASE (default `origin/main`, seam CONTEXT_LIMITS_BASE). A
# row raised or added, or the file deleted, fails, each one named. There
# is no override: a raise is the owner's call, made on the merge side
# where `just merge` stops on it too (cloud:V51, scripts:B81). The rows
# are read by context_limits_raises, the parser `just merge` shares.
#
# Usage: context-limits.sh [BASE]
# A shallow clone hides the merge base, so it is refused with the fix
# (scripts:V29); a missing BASE checks nothing and fails (.:V18).

set -euo pipefail

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

if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
    echo "context-limits: this clone is shallow -- the merge base with the base branch may be missing, so nothing was checked. run: git fetch --unshallow" >&2
    exit 1
fi

base="${1:-${CONTEXT_LIMITS_BASE:-origin/main}}"
if ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
    echo "context-limits: cannot resolve the base $base -- nothing was checked, which is a failure rather than a pass. run: git fetch origin" >&2
    exit 1
fi
if ! fork="$(git merge-base HEAD "$base")"; then
    echo "context-limits: HEAD and $base share no commit -- nothing was checked, which is a failure rather than a pass." >&2
    exit 1
fi

reasons="$(git diff --no-ext-diff "$fork" HEAD -- .context-limits | context_limits_raises)"
if git cat-file -e "$fork:.context-limits" 2>/dev/null && ! git cat-file -e "HEAD:.context-limits" 2>/dev/null; then
    reasons+=$'\ndiff: deletes .context-limits'
fi
[ -n "${reasons//$'\n'/}" ] || exit 0

while IFS= read -r reason; do
    [ -n "$reason" ] || continue
    echo "context-limits: this branch ${reason#diff: } (vs $base)" >&2
done <<<"$reasons"
echo "context-limits: never raise a ceiling to get green -- move rows down to the node that owns them, or archive done tasks. A raise is the owner's call, made on the merge side." >&2
exit 1
