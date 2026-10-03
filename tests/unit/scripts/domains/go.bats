#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/domains/go.sh (SPEC scripts:T27, I.cmd
# `domains`): the Go module proxy and checksum database.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/domains/go.sh"
    P="$BATS_TEST_TMPDIR/project"
    mkdir -p "$P"
}

@test "go.sum: proxy.golang.org and sum.golang.org" {
    printf '%s\n' 'golang.org/x/text v0.3.0 h1:abc=' >"$P/go.sum"
    run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "proxy.golang.org	go.sum" ]
    [ "${lines[1]}" = "sum.golang.org	go.sum" ]
    [ "${#lines[@]}" -eq 2 ]
}

@test "no go.sum: prints nothing and passes" {
    run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
