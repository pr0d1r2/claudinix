#!/usr/bin/env bats
# Unit tests for scripts/lib/require-full-history.sh, the one shallow-clone
# refusal that tdd-order, context-limits and spec-ids share (SPEC V29, B7).

setup() {
    unset "${!GIT_@}"
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    LIB="$BATS_TEST_DIRNAME/../../../../scripts/lib/require-full-history.sh"
    # shellcheck source=/dev/null
    source "$LIB"
    REPO="$BATS_TEST_TMPDIR/repo"
    git init -q "$REPO"
    git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m one
    git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m two
}

@test "require_full_history passes in a full clone" {
    cd "$REPO"
    run require_full_history guard "the history is missing"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "require_full_history refuses a shallow clone, naming the guard, the reason and the fix" {
    git clone -q --depth 1 "file://$REPO" "$BATS_TEST_TMPDIR/shallow"
    cd "$BATS_TEST_TMPDIR/shallow"
    run require_full_history guard "the history is missing"
    [ "$status" -eq 1 ]
    [ "$output" = "guard: this clone is shallow -- the history is missing. run: git fetch --unshallow" ]
}
