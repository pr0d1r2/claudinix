#!/usr/bin/env bash
# The one reader of `.context-limits` rows in a patch (SPEC scripts:T162,
# .:C20). Source it; it defines functions only. The context-limits guard
# and cloud_diff_reasons (the parser `just merge` stops on, cloud:V51)
# call it, so a new row format changes one place.

set -euo pipefail

# context_limits_raises: read a patch on stdin and print, one per line, each
# `.context-limits` ceiling it raises or adds. Other files, comments and
# lowered rows print nothing.
context_limits_raises() {
    awk '
        /^diff --git / { file = $0; sub(/^diff --git .* b\//, "", file); next }
        /^(\+\+\+|---) / { next }
        /^[-+]/ {
            if (file == ".context-limits" && $0 !~ /^[-+]#/ && NF == 2 && $2 ~ /^[0-9]+$/) {
                key = substr($1, 2)
                if ($0 ~ /^-/) old[key] = $2; else new[key] = $2
            }
        }
        END {
            for (key in new) {
                if (!(key in old)) print "diff: adds the .context-limits row " key " " new[key]
                else if (new[key] + 0 > old[key] + 0) print "diff: raises the .context-limits row " key " from " old[key] " to " new[key]
            }
        }
    '
}
