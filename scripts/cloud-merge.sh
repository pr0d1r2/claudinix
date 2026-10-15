#!/usr/bin/env bash
# Merge one reviewed pull request from your terminal, under the strict rule
# (SPEC cloud:T160, cloud:V51, .:C29). Only the owner runs this; a cloud
# session never merges (the cloud permission list denies `gh pr merge`).
#
# PR is a number or a GitHub pull request URL of this repository; it must
# be open, based on main, not from a fork, with plain branch names
# (lib/cloud-launch.sh's cloud_require_open_pr). Then the verdict. It
# merges only when every rule holds, and otherwise stops for the owner,
# naming every reason:
# - CI: every check on the head is success or skipped (none pending, none
#   red, at least one);
# - every review role (a file in review/) posted `Review: <role>`, and a
#   `Fixup:` reply came after the last of them;
# - security's review ends with `Findings: 0` (a missing line stops too);
# - the diff touches none of hk.pkl, .github/, flake.lock and
#   nix/cloud-permissions.json, changes no §C or §V row of a SPEC.md, and
#   raises or adds no .context-limits row.
#
# A y/N answer confirms the merge; --yes skips only that question.
# --dry-run judges and prints the gh command instead. The merge is
# `gh pr merge --rebase --match-head-commit <the head judged>`, so a push
# after the verdict makes gh refuse it. Afterwards, when this work tree is
# on main and clean, `git pull --ff-only` brings the merge in.
#
# Usage: cloud-merge.sh <PR# | URL> [--yes] [--dry-run]

set -euo pipefail

usage() {
    echo "usage: cloud-merge.sh <PR# | URL> [--yes] [--dry-run]" >&2
    exit 2
}

arg=
yes=0
dry=0
while [ "$#" -gt 0 ]; do
    case "$1" in
    --yes) yes=1 ;;
    --dry-run) dry=1 ;;
    -*) usage ;;
    *)
        [ -z "$arg" ] || usage
        arg="$1"
        ;;
    esac
    shift
done
[ -n "$arg" ] || usage

# shellcheck source=/dev/null # lib/cloud-launch.sh, beside this script
source "$(dirname "${BASH_SOURCE[0]}")/lib/cloud-launch.sh"
pr= # set by cloud_parse_pr
head=""
# shellcheck disable=SC2034 # base is set and checked by cloud_require_open_pr
base="" # head and base: set by cloud_require_open_pr
cloud_parse_pr "$arg" || usage

lib="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"
remote="${CLOUD_TASK_REMOTE:-origin}"

cloud_require_remote merge "$remote" || exit 1
cloud_require_open_pr merge "$remote" "$arg" || exit 1

roles="$(cloud_roles "$lib/review" | jq -R . | jq -sc .)"
# </dev/null: gh must not share the terminal the y/N answer comes from (cloud:B19).
if ! info="$(gh pr view "$pr" --json headRefOid,statusCheckRollup,comments </dev/null)"; then
    echo "merge: gh could not read the checks and comments of #$pr" >&2
    exit 1
fi
if ! patch="$(gh pr diff "$pr" </dev/null)"; then
    echo "merge: gh could not read the diff of #$pr" >&2
    exit 1
fi
sha="$(jq -r '.headRefOid' <<<"$info")"

# The reasons from the checks and comments, one per line.
reasons="$(jq -r --argjson roles "$roles" '
    def first_line: split("\n")[0];
    def reviewed($r): (.body | first_line) | test("^#* *Review: " + $r + "\\b");
    (.statusCheckRollup // []) as $checks
    | (if ($checks | length) == 0 then "CI: no check ran on the head"
       elif ($checks | all((.conclusion // "") == "SUCCESS" or (.conclusion // "") == "SKIPPED" or (.state // "") == "SUCCESS")) | not
       then "CI: not every check on the head is green (success or skipped)"
       else empty end),
    ([.comments | to_entries[] | select(.value.body | first_line | test("^#* *Review: "))] ) as $reviews
    | ($roles[] as $r | if ([$reviews[] | select(.value | reviewed($r))] | length) == 0
        then "review: no \"Review: \($r)\" comment" else empty end),
    (([$reviews[].key] | max) as $last
     | if ([.comments | to_entries[] | select(.value.body | startswith("Fixup:")) | select(.key > ($last // -1))] | length) == 0
       then "fixup: no Fixup: reply after the reviews" else empty end),
    ([$reviews[] | select(.value | reviewed("security"))] | last) as $sec
    | (if $sec == null then empty
       else ([$sec.value.body | split("\n")[] | capture("^Findings: *(?<n>[0-9]+) *$")] | last) as $f
       | if $f == null then "security: its review has no Findings: line"
         elif ($f.n | tonumber) > 0 then "security: \($f.n) finding(s) reported"
         else empty end end)
' <<<"$info")"

# The reasons from the diff, one per line.
diff_reasons="$(awk '
    /^diff --git / { file = $NF; sub(/^b\//, "", file); next }
    /^(\+\+\+|---) / { next }
    /^[-+]/ {
        if (file == "hk.pkl" || file == "flake.lock" || file == "nix/cloud-permissions.json" || file ~ /^\.github\//) {
            if (!(file in kept)) { kept[file] = 1; print "diff: changes " file }
        }
        if (file ~ /(^|\/)SPEC\.md$/ && $0 ~ /^[-+](- C[0-9]+:|V[0-9]+:)/) {
            if (!(file in rule)) { rule[file] = 1; print "diff: changes a §C or §V row of " file }
        }
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
' <<<"$patch")"

all_reasons="$(printf '%s\n%s\n' "$reasons" "$diff_reasons" | sed '/^$/d')"
if [ -n "$all_reasons" ]; then
    echo "merge: #$pr stops for the owner:" >&2
    while IFS= read -r reason; do
        echo "  - $reason" >&2
    done <<<"$all_reasons"
    exit 1
fi

if [ "$dry" = 1 ]; then
    echo "merge: #$pr passes the rule; would run: gh pr merge $pr --rebase --match-head-commit $sha"
    exit 0
fi

if [ "$yes" = 0 ]; then
    cloud_flush_input
    printf 'merge: #%s (%s) passes the rule. Rebase-merge it into main now? [y/N] ' "$pr" "$head"
    answer=
    IFS= read -r answer || true
    case "$answer" in
    y | Y | yes) ;;
    *)
        echo "merge: not merged" >&2
        exit 1
        ;;
    esac
fi

if ! gh pr merge "$pr" --rebase --match-head-commit "$sha" </dev/null; then
    echo "merge: gh did not merge #$pr (did its head move since the verdict?)" >&2
    exit 1
fi
echo "merge: merged #$pr ($head) at $sha"

if [ "$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)" = main ] && [ -z "$(git status --porcelain)" ]; then
    git pull --ff-only
fi
