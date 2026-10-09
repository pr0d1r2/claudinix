#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/nix/rtk-pin-check.sh (SPEC nix:T151, .:C14):
# nix-rtk follows our nixpkgs-lock, so rtk's store path matches the one
# its CI pushed to cachix only while our nixpkgs-lock rev equals the rev
# in nix-rtk's own flake.lock. Any other rev means a cloud setup compiles
# rtk, so the check fails and names both revs.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/nix/rtk-pin-check.sh"
    LOCK="$BATS_TEST_TMPDIR/flake.lock"
    OUT="$BATS_TEST_TMPDIR/out"
    OURS=57c28adf21be97c4eb31b65279a6bfa1c8e34da6
}

# rtk_lock REV: nix-rtk's flake.lock with nixpkgs-lock locked at REV.
rtk_lock() {
    printf '{"nodes":{"nixpkgs-lock":{"locked":{"rev":"%s","type":"github"}},"root":{"inputs":{"nixpkgs-lock":"nixpkgs-lock"}}},"root":"root","version":7}\n' "$1" >"$LOCK"
}

@test "same rev: passes and writes OUT" {
    rtk_lock "$OURS"
    run bash "$SCRIPT" "$OURS" "$LOCK" "$OUT"
    [ "$status" -eq 0 ]
    [ -e "$OUT" ]
}

@test "other rev: fails, names both revs, writes no OUT" {
    rtk_lock 9285cde52c7e8baff0b60685ae755b911db9ebaa
    run bash "$SCRIPT" "$OURS" "$LOCK" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$OURS"* ]]
    [[ "$output" == *"9285cde52c7e8baff0b60685ae755b911db9ebaa"* ]]
    [ ! -e "$OUT" ]
}

@test "lock without nixpkgs-lock: fails and says so" {
    printf '{"nodes":{"root":{}},"root":"root","version":7}\n' >"$LOCK"
    run bash "$SCRIPT" "$OURS" "$LOCK" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"nixpkgs-lock"* ]]
    [ ! -e "$OUT" ]
}

@test "unreadable lock: fails" {
    run bash "$SCRIPT" "$OURS" "$BATS_TEST_TMPDIR/none.lock" "$OUT"
    [ "$status" -eq 1 ]
    [ ! -e "$OUT" ]
}

@test "missing arguments is a usage error" {
    run bash "$SCRIPT" "$OURS" "$LOCK"
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
}
