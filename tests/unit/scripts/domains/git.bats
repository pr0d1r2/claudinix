#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/domains/git.sh (SPEC scripts:T27, I.cmd
# `domains`): submodule hosts from .gitmodules.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/domains/git.sh"
    P="$BATS_TEST_TMPDIR/project"
    mkdir -p "$P"
}

@test ".gitmodules: https and scp-like submodule URLs give their hosts" {
    printf '%s\n' '[submodule "a"]' '	path = a' '	url = https://git.example.org/o/a.git' \
        '[submodule "b"]' '	path = b' '	url = git@code.example.com:o/b.git' >"$P/.gitmodules"
    run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "git.example.org	.gitmodules" ]
    [ "${lines[1]}" = "code.example.com	.gitmodules" ]
}

@test "no .gitmodules: prints nothing and passes" {
    run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
