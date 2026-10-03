#!/usr/bin/env bash
# Every tracked `*.sh` with a shebang is executable (SPEC V28, B6).
#
# The docs say "run scripts/x.sh"; a script committed as 100644 answers
# "permission denied", and tests that call it through `bash` never see
# it. The INDEX mode decides, because that is what a clone gets: a local
# `chmod +x` that was never staged fixes nothing. A file without a
# shebang is a sourced library and may stay 100644.
#
# Usage: exec-bit.sh

set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "exec-bit: not inside a git work tree -- the file list comes from git, so nothing could be checked. This is a failure, not a pass." >&2
    exit 1
fi

status=0

while read -r mode _ _ path; do
    [ "$mode" = 100755 ] && continue
    [ "$(git cat-file blob ":$path" | head -c 2)" = '#!' ] || continue
    echo "exec-bit: $path has a shebang but is tracked as $mode -- run: git update-index --chmod=+x $path" >&2
    status=1
done < <(git ls-files --stage -- '*.sh')

exit "$status"
