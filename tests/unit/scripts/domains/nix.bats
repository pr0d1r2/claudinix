#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/domains/nix.sh (SPEC scripts:T27, I.cmd
# `domains`): nixConfig substituters and non-github flake.lock inputs.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/domains/nix.sh"
    P="$BATS_TEST_TMPDIR/project"
    mkdir -p "$P"
}

@test "flake.nix nixConfig substituters, list or one line; input URLs are not" {
    printf '%s\n' '{' \
        '  # a comment about substituters is not one' \
        '  inputs.x.url = "https://tarballs.example.org/x.tar.gz";' \
        '  nixConfig = {' \
        '    extra-substituters = [' \
        '      "https://one.cachix.org"' \
        '      "https://two.example.com"' \
        '    ];' \
        '    substituters = [ "https://three.example.net" ];' \
        '    extra-trusted-public-keys = [ "one.cachix.org-1:abc=" ];' \
        '  };' \
        '}' >"$P/flake.nix"
    run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "one.cachix.org	flake.nix" ]
    [ "${lines[1]}" = "two.example.com	flake.nix" ]
    [ "${lines[2]}" = "three.example.net	flake.nix" ]
    [ "${#lines[@]}" -eq 3 ]
}

@test "flake.lock: git, tarball, gitlab and sourcehut hosts; github and path skipped" {
    printf '%s' '{"nodes":{' \
        '"a":{"locked":{"type":"github","owner":"o","repo":"a","rev":"1"}},' \
        '"b":{"locked":{"type":"git","url":"https://git.example.org/b"}},' \
        '"c":{"locked":{"type":"tarball","url":"https://dl.example.com/c.tar.gz"}},' \
        '"d":{"locked":{"type":"gitlab","owner":"o","repo":"d","rev":"1"}},' \
        '"e":{"locked":{"type":"sourcehut","owner":"~o","repo":"e","rev":"1"}},' \
        '"f":{"locked":{"type":"path","path":"/tmp/f"}},' \
        '"root":{"inputs":{}}},"root":"root","version":7}' >"$P/flake.lock"
    run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [[ "$output" == *"git.example.org	flake.lock"* ]]
    [[ "$output" == *"dl.example.com	flake.lock"* ]]
    [[ "$output" == *"gitlab.com	flake.lock"* ]]
    [[ "$output" == *"git.sr.ht	flake.lock"* ]]
    [[ "$output" != *"github.com"* ]]
}

@test "no flake files: prints nothing and passes" {
    run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
