#!/usr/bin/env bash
# The one reader of the root spec's §F table (SPEC .:V48, B61) and of a
# spec's §T rows. Source it; it defines functions only. cloud-launch.sh,
# cloud-drain.sh and guard/node-names.sh call it, so each table format is
# parsed in one place.

set -euo pipefail

# spec_f_nodes SPEC: the first column of every row of SPEC's §F table, one
# per line: the rows after its `dir|` header, up to the first blank line.
# Prints nothing for a header-only table or a spec without §F.
spec_f_nodes() {
    awk '
        /^## / { in_f = ($2 == "§F"); header = 0; next }
        in_f && /^dir\|/ { header = 1; next }
        in_f && header && /^$/ { header = 0; next }
        in_f && header && /\|/ { split($0, cell, "|"); print cell[1] }
    ' "$1"
}

# spec_open_tasks SPEC: the id of every open task of SPEC, one per line: the
# §T rows whose status is `.`, without the open questions (a task text
# starting with `?`).
spec_open_tasks() {
    awk -F'|' '
        /^## / { in_t = ($0 ~ /^## §T /); next }
        in_t && $1 ~ /^T[0-9]+$/ && $2 == "." && $3 !~ /^\?/ { print $1 }
    ' "$1"
}
