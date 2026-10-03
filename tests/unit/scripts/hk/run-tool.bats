#!/usr/bin/env bats
# Unit tests for scripts/hk/run-tool.sh (SPEC V18, T1).

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/hk/run-tool.sh"
    BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$BIN"
}

stub() {
    printf '#!/usr/bin/env bash\n%s\n' "$2" >"$BIN/$1"
    chmod +x "$BIN/$1"
}

@test "no arguments is a usage error" {
    run bash "$SCRIPT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
}

@test "missing tool fails and says nothing was checked" {
    run env PATH="$BIN:/usr/bin:/bin" bash "$SCRIPT" no-such-tool-here a.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"no-such-tool-here"* ]]
    [[ "$output" == *"gate could not run"* ]]
}

@test "present tool runs with its arguments" {
    stub fake 'echo "args: $*"'
    run env PATH="$BIN:/usr/bin:/bin" bash "$SCRIPT" fake one two
    [ "$status" -eq 0 ]
    [ "$output" = "args: one two" ]
}

@test "tool exit status is passed through as a finding" {
    stub fake 'echo finding; exit 3'
    run env PATH="$BIN:/usr/bin:/bin" bash "$SCRIPT" fake
    [ "$status" -eq 3 ]
    [ "$output" = "finding" ]
}
