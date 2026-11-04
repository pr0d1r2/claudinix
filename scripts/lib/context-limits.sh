#!/usr/bin/env bash
# The one reader of `.context-limits` rows in a patch (SPEC scripts:T162,
# gate:C20). Source it; it defines functions only. The context-limits guard
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

# context_limits_judge BASE HEAD: judge two `.context-limits` files per chain
# (gate:V67) and print, one per line, each change that grows what an agent
# loads: a chain row raised; a file row raised while its node's chain row
# does not fall (root's file row is root's chain, so it never may); a chain
# row added above the largest chain row in BASE; a file row added without
# its node's chain row. A split that shrinks every chain prints nothing.
context_limits_judge() {
    awk '
        function node(key) { return key == "SPEC.md" ? "." : substr(key, 1, length(key) - 8) }
        function falls(n) { return (n in bchain) && (n in hchain) && hchain[n] + 0 < bchain[n] + 0 }
        /^[ \t]*#/ || NF != 2 || $2 !~ /^[0-9]+$/ { next }
        {
            file = $1 ~ /(^|\/)SPEC\.md$/
            if (FILENAME == ARGV[1]) {
                if (file) bfile[$1] = $2
                else { bchain[$1] = $2; if ($2 + 0 > max) max = $2 + 0 }
            } else if (file) hfile[$1] = $2
            else hchain[$1] = $2
        }
        END {
            for (k in hchain) {
                if (!(k in bchain)) {
                    if (hchain[k] + 0 > max) print "diff: adds the .context-limits row " k " " hchain[k] ", above the largest chain ceiling at base (" max + 0 ")"
                } else if (hchain[k] + 0 > bchain[k] + 0) print "diff: raises the .context-limits row " k " from " bchain[k] " to " hchain[k]
            }
            for (k in hfile) {
                n = node(k)
                if (!(k in bfile)) {
                    if (!(n in hchain) || (n in bchain)) print "diff: adds the .context-limits row " k " " hfile[k] ", without a new chain row " n
                } else if (hfile[k] + 0 > bfile[k] + 0 && !falls(n)) print "diff: raises the .context-limits row " k " from " bfile[k] " to " hfile[k] " while its chain " n " does not fall"
            }
        }
    ' "$1" "$2" | sort
}
