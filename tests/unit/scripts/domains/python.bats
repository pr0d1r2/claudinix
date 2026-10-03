#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/domains/python.sh (SPEC scripts:T27, I.cmd
# `domains`): PyPI hosts plus any index or URL the lock files name.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/domains/python.sh"
    P="$BATS_TEST_TMPDIR/project"
    mkdir -p "$P"
}

@test "requirements*.txt: PyPI hosts and extra index hosts" {
    printf '%s\n' '--extra-index-url https://pypi.example.org/simple' 'requests==2.0' >"$P/requirements-dev.txt"
    run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pypi.org	requirements-dev.txt"* ]]
    [[ "$output" == *"files.pythonhosted.org	requirements-dev.txt"* ]]
    [[ "$output" == *"pypi.example.org	requirements-dev.txt"* ]]
}

@test "uv.lock: PyPI hosts and registry hosts" {
    printf '%s\n' '[[package]]' 'name = "a"' \
        'source = { registry = "https://mirror.example.com/simple" }' >"$P/uv.lock"
    run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pypi.org	uv.lock"* ]]
    [[ "$output" == *"mirror.example.com	uv.lock"* ]]
}

@test "no Python lock files: prints nothing and passes" {
    run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
