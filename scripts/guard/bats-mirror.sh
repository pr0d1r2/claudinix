#!/usr/bin/env bash
# Every shell script has a test, and every test has a script (SPEC C16).
#
#   setup.sh          <-> tests/unit/setup.bats
#   scripts/a/b.sh    <-> tests/unit/scripts/a/b.bats
#
# Both directions, because they fail differently: a script with no test is
# visible the moment someone looks; an orphan test passes forever.
# Tracked files only, so an untracked scratch script never fails the gate.
# Adapted from pr0d1r2/xenolith scripts/guard/bats-mirror.sh at 8f35175
# (SPEC C17: no flake export exists).
#
# Usage: bats-mirror.sh

set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "bats-mirror: not inside a git work tree -- the file list comes from git, so nothing could be checked. This is a failure, not a pass." >&2
    exit 1
fi

status=0

fail() {
    echo "bats-mirror: $1" >&2
    status=1
}

while IFS= read -r script; do
    [ -n "$script" ] || continue
    expected="tests/unit/${script%.sh}.bats"
    if ! git ls-files --error-unmatch "$expected" >/dev/null 2>&1; then
        fail "$script has no test -- create $expected"
    fi
done < <(git ls-files '*.sh')

while IFS= read -r test_file; do
    [ -n "$test_file" ] || continue
    script="${test_file#tests/unit/}"
    script="${script%.bats}.sh"
    if ! git ls-files --error-unmatch "$script" >/dev/null 2>&1; then
        fail "$test_file tests nothing: $script does not exist -- delete the test or restore the script"
    fi
done < <(git ls-files 'tests/unit/*.bats')

exit "$status"
