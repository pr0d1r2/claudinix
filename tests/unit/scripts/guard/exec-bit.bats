#!/usr/bin/env bats
# Unit tests for scripts/guard/exec-bit.sh (SPEC T77, V28, B6, V21).

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/guard/exec-bit.sh"
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_PREFIX
    REPO="$BATS_TEST_TMPDIR/repo"
    git init -q "$REPO"
    cd "$REPO" || exit 1
}

# put PATH MODE [FIRST_LINE]: track a file with the given index mode.
put() {
    mkdir -p "$(dirname "$1")"
    printf '%s\necho hi\n' "${3:-#!/usr/bin/env bash}" >"$1"
    git add "$1"
    git update-index --chmod="$2" "$1"
}

@test "empty repository passes" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "executable shebang scripts pass silently" {
    put setup.sh +x
    put scripts/a/b.sh +x
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a shebang script tracked as 100644 fails and names the fix (B6)" {
    put scripts/a/b.sh -x
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"scripts/a/b.sh"* ]]
    [[ "$output" == *"git update-index --chmod=+x scripts/a/b.sh"* ]]
}

@test "every offender is reported, not only the first" {
    put a.sh -x
    put scripts/b.sh -x
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"a.sh"* ]]
    [[ "$output" == *"scripts/b.sh"* ]]
}

@test "a path with spaces is read whole: a 100644 one fails and is named" {
    put "scripts/my dir/a b.sh" -x
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"scripts/my dir/a b.sh has a shebang"* ]]
}

@test "a path with spaces tracked as 100755 passes" {
    put "scripts/my dir/a b.sh" +x
    put " lead.sh" +x
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a path with a leading space is not trimmed: a 100644 one is named" {
    put " lead.sh" -x
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"exec-bit:  lead.sh has a shebang"* ]]
}

@test "a non-ASCII path is read as is, not as git's quoted form" {
    put "scripts/zażółć.sh" -x
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"scripts/zażółć.sh has a shebang"* ]]
}

@test "a sourced library without a shebang may stay 100644" {
    put scripts/lib.sh -x '# shellcheck shell=bash'
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "the index decides, not the worktree mode" {
    put scripts/a.sh -x
    chmod +x scripts/a.sh
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
}

@test "untracked scripts are ignored" {
    printf '#!/usr/bin/env bash\n' >scratch.sh
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "outside a git work tree fails rather than passes" {
    cd "$BATS_TEST_TMPDIR"
    run env GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"nothing could be checked"* ]]
}
