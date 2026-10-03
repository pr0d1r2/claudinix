#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/domains/cargo.sh (SPEC scripts:T27, I.cmd
# `domains`): a sherd-like Rust project.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/domains/cargo.sh"
    P="$BATS_TEST_TMPDIR/project"
    mkdir -p "$P"
}

@test "Cargo.lock: crates.io hosts, git dep hosts; default registry URL is not a host" {
    printf '%s\n' '[[package]]' 'name = "a"' \
        'source = "registry+https://github.com/rust-lang/crates.io-index"' \
        '[[package]]' 'name = "b"' \
        'source = "git+https://git.example.org/o/b?branch=main#abc"' >"$P/Cargo.lock"
    run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [[ "$output" == *"index.crates.io	Cargo.lock"* ]]
    [[ "$output" == *"static.crates.io	Cargo.lock"* ]]
    [[ "$output" == *"git.example.org	Cargo.lock"* ]]
    [[ "$output" != *"github.com"* ]]
}

@test "Cargo.toml alone: crates.io hosts and git dependency hosts" {
    printf '%s\n' '[dependencies]' \
        'c = { git = "https://code.example.net/o/c" }' \
        'serde = "1"' >"$P/Cargo.toml"
    run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [[ "$output" == *"index.crates.io	Cargo.toml"* ]]
    [[ "$output" == *"code.example.net	Cargo.toml"* ]]
}

@test ".cargo/config.toml [source] and registries add their hosts" {
    printf '%s\n' '[package]' 'name = "x"' >"$P/Cargo.toml"
    mkdir -p "$P/.cargo"
    printf '%s\n' '[source.mirror]' 'registry = "sparse+https://crates.mirror.example/index/"' \
        '[registries.corp]' 'index = "https://corp.example.com/git/index"' >"$P/.cargo/config.toml"
    run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [[ "$output" == *"crates.mirror.example	.cargo/config.toml"* ]]
    [[ "$output" == *"corp.example.com	.cargo/config.toml"* ]]
}

@test "no Cargo files: prints nothing and passes" {
    run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
