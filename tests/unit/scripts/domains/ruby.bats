#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/domains/ruby.sh (SPEC scripts:T27, I.cmd
# `domains`): Gemfile.lock remotes.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/domains/ruby.sh"
    P="$BATS_TEST_TMPDIR/project"
    mkdir -p "$P"
}

@test "Gemfile.lock: every remote's host" {
    printf '%s\n' 'GIT' '  remote: https://git.example.org/o/g.git' '  specs:' \
        'GEM' '  remote: https://rubygems.org/' '  specs:' '    rake (13.0)' >"$P/Gemfile.lock"
    run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "git.example.org	Gemfile.lock" ]
    [ "${lines[1]}" = "rubygems.org	Gemfile.lock" ]
}

@test "no Gemfile.lock: prints nothing and passes" {
    run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
