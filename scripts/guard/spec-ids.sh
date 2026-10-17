#!/usr/bin/env bash
# No spec id lost, no archive pointer left dangling (SPEC scripts:T173, B91).
#
# An id (T V B C) defined in a `SPEC*.md` at the merge base of HEAD and BASE
# (default `origin/main`, seam SPEC_IDS_BASE) must still be defined in some
# `SPEC*.md` at HEAD, in any node: ids are never reused and a cite to one
# must resolve. An id an `ARCHIVED to SPEC-ARCHIVE.md` pointer names, as a
# row (`T106|x|ARCHIVED to ...`) or as a list (`B19-B22, B24: ARCHIVED to
# ...`), must be a row of that node's `SPEC-ARCHIVE.md`. `mth archive`
# rewrote an archive without the bug rows moved there by hand, and nothing
# noticed (B91). Every offender is named.
#
# Usage: spec-ids.sh [BASE]
# A shallow clone hides the merge base, so it is refused with the fix
# (scripts:V29); a missing BASE checks nothing and fails (.:V18).

set -euo pipefail

# defined_and_pointed: read a spec on stdin; print "D<TAB>id" per id it
# defines (a row or list item start, or a pointer list member) and
# "P<TAB>id" per id an ARCHIVED pointer sends to the archive, and
# "E<TAB>problem" per pointer line it refuses.
defined_and_pointed() {
    awk -v max_range=1000 '
        function emit(kind, id) { print kind "\t" id }
        function pointed(id) { emit("D", id); emit("P", id) }
        /ARCHIVED to SPEC-ARCHIVE\.md/ && /^[TVBC][0-9]+(-[TVBC][0-9]+)?(, *[TVBC][0-9]+(-[TVBC][0-9]+)?)*:/ {
            list = $0
            sub(/:.*/, "", list)
            n = split(list, items, /, */)
            for (i = 1; i <= n; i++) {
                split(items[i], ends, "-")
                kind = substr(ends[1], 1, 1)
                first = substr(ends[1], 2) + 0
                last = (2 in ends) ? substr(ends[2], 2) + 0 : first
                if (last < first || last - first > max_range) {
                    emit("E", "line " NR ": bad range " items[i])
                    continue
                }
                for (k = first; k <= last; k++) pointed(kind k)
            }
            next
        }
        match($0, /^(- )?[TVBC][0-9]+[|:]/) {
            id = substr($0, RSTART, RLENGTH - 1)
            sub(/^- /, "", id)
            if ($0 ~ /\|ARCHIVED to SPEC-ARCHIVE\.md/) pointed(id)
            else emit("D", id)
        }
    '
}

# spec_files REV: the SPEC*.md paths tracked at REV.
spec_files() {
    git ls-tree -r --name-only "$1" | grep -E '(^|/)SPEC[^/]*\.md$' || true
}

if [ "$#" -gt 1 ]; then
    echo "usage: spec-ids.sh [BASE]" >&2
    exit 2
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "spec-ids: not inside a git work tree -- nothing was checked, which is a failure rather than a pass." >&2
    exit 1
fi

if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
    echo "spec-ids: this clone is shallow -- the merge base with the base branch may be missing, so nothing was checked. run: git fetch --unshallow" >&2
    exit 1
fi

base="${1:-${SPEC_IDS_BASE:-origin/main}}"
if ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
    echo "spec-ids: cannot resolve the base $base -- nothing was checked, which is a failure rather than a pass. run: git fetch origin" >&2
    exit 1
fi
if ! fork="$(git merge-base HEAD "$base")"; then
    echo "spec-ids: HEAD and $base share no commit -- nothing was checked, which is a failure rather than a pass." >&2
    exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
: >"$work/base_ids" # id<TAB>file, at the merge base
: >"$work/head_ids" # id, at HEAD
status=0

while IFS= read -r file; do
    [ -n "$file" ] || continue
    git show "$fork:$file" | defined_and_pointed | awk -F'\t' -v f="$file" '$1 == "D" { print $2 "\t" f }' >>"$work/base_ids"
done <<<"$(spec_files "$fork")"

while IFS= read -r file; do
    [ -n "$file" ] || continue
    parsed="$(git show "HEAD:$file" | defined_and_pointed)"
    awk -F'\t' '$1 == "D" { print $2 }' <<<"$parsed" >>"$work/head_ids"
    while IFS=$'\t' read -r _ problem; do
        [ -n "$problem" ] || continue
        echo "spec-ids: $file: $problem" >&2
        status=1
    done <<<"$(awk -F'\t' '$1 == "E"' <<<"$parsed")"
    case "$file" in
    */SPEC-ARCHIVE.md | SPEC-ARCHIVE.md) continue ;;
    esac
    archive="$(dirname "$file")/SPEC-ARCHIVE.md"
    archive="${archive#./}"
    if git cat-file -e "HEAD:$archive" 2>/dev/null; then
        git show "HEAD:$archive" | defined_and_pointed | awk -F'\t' '$1 == "D" { print $2 }' >"$work/archive_ids"
    else
        : >"$work/archive_ids"
    fi
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        echo "spec-ids: $id is archived by a pointer in $file but is not a row of $archive" >&2
        status=1
    done <<<"$(awk -F'\t' 'FILENAME == ARGV[1] { have[$1]; next } $1 == "P" && !($2 in have) { print $2 }' "$work/archive_ids" - <<<"$parsed")"
done <<<"$(spec_files HEAD)"

while IFS=$'\t' read -r id file; do
    [ -n "$id" ] || continue
    echo "spec-ids: $id was defined in $file at $base and is in no SPEC*.md now -- ids are never reused; restore the row (B91)" >&2
    status=1
done <<<"$(awk -F'\t' 'FILENAME == ARGV[1] { here[$1]; next } !($1 in here)' "$work/head_ids" "$work/base_ids")"

exit "$status"
