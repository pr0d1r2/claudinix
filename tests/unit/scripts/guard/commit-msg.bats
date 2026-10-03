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
    printf 'refactor!: drop legacy path\n\nWhy: nothing uses it.\nRefs: §T.1\n' >"$MSG"
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

@test "missing Refs: line fails and names it (AGENTS.md)" {
    printf 'fix(setup): refuse bad hash\n\nWhy: B2.\n' >"$MSG"
    run bash "$SCRIPT" "$MSG"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Refs:"* ]]
}

@test "every problem is reported at once, with the types and an example" {
    printf 'add module\n\nJust a body.\n' >"$MSG"
    run bash "$SCRIPT" "$MSG"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Conventional Commits"* ]]
    [[ "$output" == *"Why:"* ]]
    [[ "$output" == *"Refs:"* ]]
    [[ "$output" == *"feat fix docs test refactor chore ci build perf style revert"* ]]
    [[ "$output" == *"example:"* ]]
    [[ "$output" == *"got: add module"* ]]
}

@test "the printed example passes the check itself" {
    printf 'add module\n' >"$MSG"
    run bash "$SCRIPT" "$MSG"
    [ "$status" -eq 1 ]
    printf '%s\n' "$output" | sed -n 's/^  | \{0,1\}//p' >"$MSG"
    [ -s "$MSG" ]
    run bash "$SCRIPT" "$MSG"
    [ "$status" -eq 0 ]
}

@test "git-generated revert subjects pass without Refs:" {
    printf 'Revert "feat(x): y"\n\nThis reverts commit abc.\n' >"$MSG"
    run bash "$SCRIPT" "$MSG"
    [ "$status" -eq 0 ]
}

@test "cloud session trailer after the Why: line passes (C8)" {
    printf 'fix(setup): keep nix.conf block whole\n\nWhy: B2.\nRefs: §B.2\n\nClaude-Session: https://claude.ai/code/x\n' >"$MSG"
    run bash "$SCRIPT" "$MSG"
    [ "$status" -eq 0 ]
}
