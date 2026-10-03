#!/usr/bin/env bats
# Unit tests for scripts/guard/bats-mirror.sh (SPEC T19, C16, V19, V21).

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/guard/bats-mirror.sh"
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_PREFIX
    REPO="$BATS_TEST_TMPDIR/repo"
    git init -q "$REPO"
    cd "$REPO" || exit 1
}

put() {
    mkdir -p "$(dirname "$1")"
    : >"$1"
    git add "$1"
}

@test "empty repository passes" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "scripts with mirrored tests pass, root scripts included" {
    put scripts/dev/a.sh
    put tests/unit/scripts/dev/a.bats
    put setup.sh
    put tests/unit/setup.bats
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "script without test fails and names the expected test" {
    put scripts/dev/a.sh
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"tests/unit/scripts/dev/a.bats"* ]]
}

@test "root script without test fails" {
    put probe.sh
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"tests/unit/probe.bats"* ]]
}

@test "orphan test fails and names the missing script" {
    put tests/unit/scripts/dev/gone.bats
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"scripts/dev/gone.sh"* ]]
}

@test "untracked scratch script is ignored" {
    mkdir -p scripts
    : >scripts/scratch.sh
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "outside a git work tree fails rather than passes" {
    cd "$BATS_TEST_TMPDIR"
    run env GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"nothing could be checked"* ]]
}
