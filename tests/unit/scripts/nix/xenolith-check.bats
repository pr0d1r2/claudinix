#!/usr/bin/env bats
# Unit tests for scripts/nix/xenolith-check.sh (SPEC T20, C15, V18).

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/nix/xenolith-check.sh"
    BIN="$BATS_TEST_TMPDIR/bin"
    SRC="$BATS_TEST_TMPDIR/src"
    OUT="$BATS_TEST_TMPDIR/out"
    XNL_LOG="$BATS_TEST_TMPDIR/xnl.log"
    export XNL_LOG
    mkdir -p "$BIN" "$SRC"
}

stub_xnl() {
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '#!/usr/bin/env bash\necho "$PWD $*" >>"$XNL_LOG"\nexit %s\n' "$1" >"$BIN/xnl"
    chmod +x "$BIN/xnl"
}

@test "clean tree: runs xnl check in the source dir and writes OUT" {
    stub_xnl 0
    run env PATH="$BIN:$PATH" bash "$SCRIPT" "$SRC" "$OUT"
    [ "$status" -eq 0 ]
    [ -e "$OUT" ]
    [ "$(cat "$XNL_LOG")" = "$SRC check ." ]
}

@test "finding: fails and writes no OUT" {
    stub_xnl 1
    run env PATH="$BIN:$PATH" bash "$SCRIPT" "$SRC" "$OUT"
    [ "$status" -eq 1 ]
    [ ! -e "$OUT" ]
}

@test "missing arguments is a usage error" {
    run bash "$SCRIPT" "$SRC"
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
}
