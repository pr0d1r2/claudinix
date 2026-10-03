#!/usr/bin/env bats
# Unit tests for scripts/guard/commit-msg.sh (SPEC T1, C17, C21).

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/guard/commit-msg.sh"
    MSG="$BATS_TEST_TMPDIR/COMMIT_EDITMSG"
}

@test "conventional subject with Why: body passes" {
    printf 'feat(setup): T2 import seed\n\nWhy: guardrails first.\nRefs: §T.2, §V.3.\n' >"$MSG"
    run bash "$SCRIPT" "$MSG"
    [ "$status" -eq 0 ]
}

@test "subject without conventional type fails" {
    printf 'add module\n\nWhy: because.\n' >"$MSG"
    run bash "$SCRIPT" "$MSG"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Conventional Commits"* ]]
}

@test "missing Why: line fails" {
    printf 'fix(setup): refuse bad hash\n\nJust a body.\n' >"$MSG"
    run bash "$SCRIPT" "$MSG"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Why:"* ]]
}

@test "Why: inside a git comment line does not count" {
    printf 'fix(setup): refuse bad hash\n\n# Why: comment only\n' >"$MSG"
    run bash "$SCRIPT" "$MSG"
    [ "$status" -eq 1 ]
}

@test "breaking-change bang and no scope are accepted" {
    printf 'refactor!: drop legacy path\n\nWhy: nothing uses it.\n' >"$MSG"
    run bash "$SCRIPT" "$MSG"
    [ "$status" -eq 0 ]
}

@test "git-generated merge and fixup subjects pass untouched" {
    printf 'Merge branch x\n' >"$MSG"
    run bash "$SCRIPT" "$MSG"
    [ "$status" -eq 0 ]
    printf 'fixup! feat(x): y\n' >"$MSG"
    run bash "$SCRIPT" "$MSG"
    [ "$status" -eq 0 ]
}

@test "missing message file is a usage error" {
    run bash "$SCRIPT" "$BATS_TEST_TMPDIR/nope"
    [ "$status" -eq 2 ]
}

@test "cloud session trailer after the Why: line passes (C8)" {
    printf 'fix(setup): keep nix.conf block whole\n\nWhy: B2.\n\nClaude-Session: https://claude.ai/code/x\n' >"$MSG"
    run bash "$SCRIPT" "$MSG"
    [ "$status" -eq 0 ]
}
