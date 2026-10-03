#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for probe.sh (SPEC T3, C8, V8, V9, V21).

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../probe.sh"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    export PROC_DIR="$BATS_TEST_TMPDIR/proc"
    export SYSTEMD_DIR="$BATS_TEST_TMPDIR/no-systemd"
    export CODES="$BATS_TEST_TMPDIR/codes"
    export STUB_SUBS="https://cache.nixos.org/ https://pr0d1r2.cachix.org"
    export STUB_FLAKE_RC=0
    unset PROBE_STOREPATH
    mkdir -p "$STUBS" "$PROC_DIR/1" "$CODES"
    echo process_api >"$PROC_DIR/1/comm"

    # nix: version, substituters, flake metadata exit code.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'case "$1 ${2:-} ${3:-}" in' \
        '"--version  ") echo "nix (Nix) 2.34.6" ;;' \
        '"config show substituters") echo "$STUB_SUBS" ;;' \
        '"flake metadata "*) exit "$STUB_FLAKE_RC" ;;' \
        '*) exit 9 ;;' \
        'esac' >"$STUBS/nix"
    # curl: prints the HTTP code stored for the URL's host, default 200.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'for a in "$@"; do url="$a"; done' \
        'host="${url#https://}"; host="${host%%/*}"' \
        'if [ -f "$CODES/$host" ]; then cat "$CODES/$host"; else printf 200; fi' >"$STUBS/curl"
    printf '#!/bin/sh\nexit 0\n' >"$STUBS/unshare"
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"
}

code() {
    printf %s "$2" >"$CODES/$1"
}

@test "healthy session: prints the C8 facts and exits 0" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"id: uid="* ]]
    [[ "$output" == *"pid1: process_api"* ]]
    [[ "$output" == *"systemd: no"* ]]
    [[ "$output" == *"unshare: ok"* ]]
    [[ "$output" == *"nix-version: nix (Nix) 2.34.6"* ]]
    [[ "$output" == *"substituters: ok"* ]]
}

@test "systemd present is reported" {
    export SYSTEMD_DIR="$BATS_TEST_TMPDIR/systemd"
    mkdir -p "$SYSTEMD_DIR"
    run bash "$SCRIPT"
    [[ "$output" == *"systemd: yes"* ]]
}

@test "nix reachable without sourcing a profile is reported with its path (V1)" {
    run bash "$SCRIPT"
    [[ "$output" == *"nix-path: $STUBS/nix"* ]]
}

@test "nix missing: FAIL, other facts still printed, exit 1" {
    rm "$STUBS/nix"
    run env PATH="$STUBS:/usr/bin:/bin" bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"nix-path: FAIL"* ]]
    [[ "$output" == *"pid1: process_api"* ]]
}

@test "substituters without the owner cachix: FAIL" {
    export STUB_SUBS="https://cache.nixos.org/"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"substituters: FAIL"* ]]
}

@test "github: fetch refused is reported, not a failure (C6)" {
    export STUB_FLAKE_RC=1
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"github-fetch: refused"* ]]
}

@test "channels.nixos.org refused: FAIL with the HTTP code (B1)" {
    code channels.nixos.org 403
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"channels: FAIL"*"403"* ]]
}

@test "owner cachix unreachable: FAIL with the HTTP code" {
    code pr0d1r2.cachix.org 403
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"cachix: FAIL"*"403"* ]]
}

@test "no locked input to look up: cachix-input is skipped" {
    run bash "$SCRIPT"
    [[ "$output" == *"cachix-input: skip"* ]]
}

@test "locked input in the cache: narinfo hit (V8)" {
    run env PROBE_STOREPATH=/nix/store/abcdabcdabcdabcdabcdabcdabcdabcd-source bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"cachix-input: ok"* ]]
}

@test "locked input missing from the cache: FAIL (V8)" {
    code pr0d1r2.cachix.org 404
    run env PROBE_STOREPATH=/nix/store/abcdabcdabcdabcdabcdabcdabcdabcd-source bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"cachix-input: FAIL"* ]]
}

@test "nix-dev not installed: skipped" {
    run bash "$SCRIPT"
    [[ "$output" == *"nix-dev: skip"* ]]
}

@test "ends with the elapsed time in whole seconds" {
    run bash "$SCRIPT"
    [[ "${lines[-1]}" =~ ^elapsed:\ [0-9]+s$ ]]
}
