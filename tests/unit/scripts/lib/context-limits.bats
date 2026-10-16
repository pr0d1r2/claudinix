#!/usr/bin/env bats
# Unit tests for scripts/lib/context-limits.sh, the `.context-limits` row
# parser the context-limits guard and `just merge` share (SPEC
# scripts:T162, .:C20, cloud:V51).

setup() {
    LIB="$BATS_TEST_DIRNAME/../../../../scripts/lib/context-limits.sh"
    # shellcheck source=/dev/null
    source "$LIB"
}

@test "context_limits_raises: a raised row names both values" {
    run context_limits_raises <<<$'diff --git a/.context-limits b/.context-limits\n-a.md 10\n+a.md 20'
    [ "$status" -eq 0 ]
    [ "$output" = "diff: raises the .context-limits row a.md from 10 to 20" ]
}

@test "context_limits_raises: an added row is named" {
    run context_limits_raises <<<$'diff --git a/.context-limits b/.context-limits\n+b.md 7'
    [ "$output" = "diff: adds the .context-limits row b.md 7" ]
}

@test "context_limits_raises: a lowered row, a comment and another file print nothing" {
    run context_limits_raises <<<$'diff --git a/.context-limits b/.context-limits\n-a.md 20\n+a.md 10\n-# old\n+# new\ndiff --git a/other b/other\n-c.md 1\n+c.md 9'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
