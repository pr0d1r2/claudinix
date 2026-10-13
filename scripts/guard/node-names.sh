#!/usr/bin/env bash
# No federation node name has a hyphen (SPEC V48, B57).
#
# sherd 0.5.3 reads a cite's node name only after its last hyphen, so
# `agent-home:C33` was looked up as `home:C33`: a hyphenated node cannot
# be cited from another node, and a cite to a node that does not exist
# can pass (pr0d1r2/sherd#128). The names are the first column of the
# root spec's §F table. A spec without a §F table is a failure: nothing
# was checked.
#
# Usage: node-names.sh [SPEC]   (default SPEC.md)

set -euo pipefail

spec="${1:-SPEC.md}"
if [ ! -f "$spec" ]; then
    echo "node-names: $spec not found -- nothing was checked" >&2
    exit 1
fi

# The §F table's node names: rows after its `dir|` header, up to the next
# section.
names="$(awk '
    /^## / { in_f = ($2 == "§F"); header = 0; next }
    in_f && /^dir\|/ { header = 1; seen = 1; next }
    in_f && header && /\|/ { split($0, cell, "|"); print cell[1] }
    END { if (!seen) exit 3 }
' "$spec")" || {
    echo "node-names: $spec has no §F table -- nothing was checked" >&2
    exit 1
}

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
