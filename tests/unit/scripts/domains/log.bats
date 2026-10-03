#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/domains/log.sh (SPEC scripts:T27, I.cmd
# `domains --from-log`): hosts the session proxy refused.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/domains/log.sh"
    LOG="$BATS_TEST_TMPDIR/session.log"
}

@test "Host not in allowlist and CONNECT 403 lines with a URL give hosts" {
    printf '%s\n' 'fetching...' \
        'error: Host not in allowlist: index.crates.io' \
        "curl: (56) CONNECT tunnel failed, response 403 for https://static.crates.io/crates/a" \
        'warning: see https://docs.example.org/help for more' \
        'CONNECT tunnel failed, response 403' >"$LOG"
    run bash "$SCRIPT" "$LOG"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "index.crates.io	log" ]
    [ "${lines[1]}" = "static.crates.io	log" ]
    [ "${#lines[@]}" -eq 2 ]
}

@test "a log with no refusals prints nothing and passes" {
    printf '%s\n' 'all good' >"$LOG"
    run bash "$SCRIPT" "$LOG"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a missing log fails and says nothing was read" {
    run bash "$SCRIPT" "$BATS_TEST_TMPDIR/none.log"
    [ "$status" -eq 1 ]
    [[ "$output" == *"nothing was read"* ]]
}
