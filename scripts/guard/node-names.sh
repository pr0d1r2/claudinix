#!/usr/bin/env bash
# No federation node name has a hyphen. The rule and its cause live in
# SPEC V48 and B57 (pr0d1r2/sherd#128); this guard goes when V48 says so.
# The names are the first column of the root spec's §F table. Only that
# table is read: a node's own SPEC.md has none, and the hk step's glob
# names the root spec alone. A spec without a §F table is a failure:
# nothing was checked.
#
# Usage: node-names.sh [SPEC]   (default SPEC.md)

set -euo pipefail

spec="${1:-SPEC.md}"
if [ ! -f "$spec" ]; then
    echo "node-names: $spec not found -- nothing was checked" >&2
    exit 1
fi

# shellcheck source=/dev/null # lib/spec-nodes.sh, beside this script's dir
source "$(dirname "${BASH_SOURCE[0]}")/../lib/spec-nodes.sh"

names="$(spec_f_nodes "$spec")"
if [ -z "$names" ]; then
    echo "node-names: $spec has no §F table rows -- nothing was checked" >&2
    exit 1
fi

status=0
while IFS= read -r name; do
    [ -n "$name" ] || continue
    case "$name" in
    *-*)
        echo "node-names: §F node \"$name\" in $spec has a hyphen -- sherd reads a cite to it as \"${name##*-}:...\"; rename the node (V48)" >&2
        status=1
        ;;
    esac
done <<<"$names"

exit "$status"
