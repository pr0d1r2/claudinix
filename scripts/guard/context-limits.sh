#!/usr/bin/env bash
# No token ceiling raised to get green (SPEC .:C20, scripts:T150).
#
# Compares `.context-limits` at HEAD with the same file at the merge base
# of HEAD and BASE (default `origin/main`, seam CONTEXT_LIMITS_BASE). A
# row raised or added there fails, each one named, unless a commit in
# that range which changes `.context-limits` carries the owner's trailer
#
#   Owner-Override: context-limits
#
# A raise is the owner's call and its own commit with the measurement in
# `Why:`; the trailer is how that commit says so. The rows are read by
# cloud_diff_reasons, the parser `just merge` stops on (cloud:V51).
#
# Usage: context-limits.sh [BASE]
# A shallow clone hides the merge base, so it is refused with the fix
# (V29); a missing BASE checks nothing and fails (V18).

set -euo pipefail

# shellcheck source=/dev/null # the shared cloud rules, beside this script
source "$(dirname "${BASH_SOURCE[0]}")/../lib/cloud-launch.sh"

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

reasons="$(git diff --no-ext-diff "$fork" HEAD -- .context-limits | cloud_diff_reasons)"
[ -n "$reasons" ] || exit 0

while IFS= read -r commit; do
    [ -n "$commit" ] || continue
    if git log -1 --format='%(trailers:key=Owner-Override,valueonly)' "$commit" |
        grep -qx 'context-limits'; then
        exit 0
    fi
done < <(git rev-list "$fork..HEAD" -- .context-limits)

while IFS= read -r reason; do
    echo "context-limits: this branch ${reason#diff: } (vs $base)" >&2
done <<<"$reasons"
echo "context-limits: never raise a ceiling to get green -- move rows down to the node that owns them, or archive done tasks. A raise is the owner's call: its own commit, the measurement in \`Why:\`, and the trailer \`Owner-Override: context-limits\`." >&2
exit 1
