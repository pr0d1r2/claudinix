#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/nix/rtk-pin-check.sh (SPEC nix:T151, B44,
# .:C14): nix-rtk follows our nixpkgs-lock and rtk-src, so rtk's store
# path matches the one its CI pushed to cachix only while both inputs are
# locked at the revs in nix-rtk's own flake.lock. Any other rev means a
# cloud setup compiles rtk, so the check fails and names both revs.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/nix/rtk-pin-check.sh"
    OURS="$BATS_TEST_TMPDIR/ours.lock"
    THEIRS="$BATS_TEST_TMPDIR/theirs.lock"
    OUT="$BATS_TEST_TMPDIR/out"
    PKGS=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    SRC=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
}

# lock FILE NIXPKGS_LOCK_REV RTK_SRC_REV: a flake.lock whose root input
# nixpkgs-lock and rtk-src are locked at those revs, under node names
# other than the input names (as nix writes them once two inputs clash).
lock() {
    printf '{"nodes":{"nixpkgs-lock_2":{"locked":{"rev":"%s"}},"rtk-src_3":{"locked":{"rev":"%s"}},"root":{"inputs":{"nixpkgs-lock":"nixpkgs-lock_2","rtk-src":"rtk-src_3"}}},"root":"root","version":7}\n' "$2" "$3" >"$1"
}

@test "same revs: passes and writes OUT" {
    lock "$OURS" "$PKGS" "$SRC"
    lock "$THEIRS" "$PKGS" "$SRC"
    run bash "$SCRIPT" "$OURS" "$THEIRS" "$OUT"
    [ "$status" -eq 0 ]
    [ -e "$OUT" ]
}

@test "other nixpkgs-lock rev: fails, names both revs, writes no OUT" {
    lock "$OURS" "$PKGS" "$SRC"
    lock "$THEIRS" cccccccccccccccccccccccccccccccccccccccc "$SRC"
    run bash "$SCRIPT" "$OURS" "$THEIRS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"nixpkgs-lock"* ]]
    [[ "$output" == *"$PKGS"* ]]
    [[ "$output" == *"cccccccccccccccccccccccccccccccccccccccc"* ]]
    [ ! -e "$OUT" ]
}

@test "other rtk-src rev: fails and names it (B44)" {
    lock "$OURS" "$PKGS" "$SRC"
    lock "$THEIRS" "$PKGS" 1111111111111111111111111111111111111111
    run bash "$SCRIPT" "$OURS" "$THEIRS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"rtk-src"* ]]
    [[ "$output" == *"1111111111111111111111111111111111111111"* ]]
    [ ! -e "$OUT" ]
}

@test "both differ: both are reported" {
    lock "$OURS" "$PKGS" "$SRC"
    lock "$THEIRS" cccccccccccccccccccccccccccccccccccccccc 1111111111111111111111111111111111111111
    run bash "$SCRIPT" "$OURS" "$THEIRS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"nixpkgs-lock"* ]]
    [[ "$output" == *"rtk-src"* ]]
}

@test "lock without one of the inputs: fails and names it" {
    lock "$OURS" "$PKGS" "$SRC"
    printf '{"nodes":{"root":{"inputs":{}}},"root":"root","version":7}\n' >"$THEIRS"
    run bash "$SCRIPT" "$OURS" "$THEIRS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"nixpkgs-lock"* ]]
    [ ! -e "$OUT" ]
}

@test "unreadable lock: fails" {
    lock "$OURS" "$PKGS" "$SRC"
    run bash "$SCRIPT" "$OURS" "$BATS_TEST_TMPDIR/none.lock" "$OUT"
    [ "$status" -eq 1 ]
    [ ! -e "$OUT" ]
}

@test "missing arguments is a usage error" {
    run bash "$SCRIPT" "$OURS" "$THEIRS"
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
}
