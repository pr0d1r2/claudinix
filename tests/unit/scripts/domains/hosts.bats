#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/domains/hosts.sh (SPEC scripts:T27): the URL to
# host step every detector shares.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/domains/hosts.sh"
}

hosts() {
    printf '%s\n' "$@" | bash "$SCRIPT" TAG
}

@test "a plain https URL gives its host, tagged" {
    run hosts 'see https://registry.npmjs.org/a/-/a-1.0.0.tgz here'
    [ "$status" -eq 0 ]
    [ "$output" = "registry.npmjs.org	TAG" ]
}

@test "scheme prefixes, userinfo and ports are dropped" {
    run hosts 'source = "git+https://github.com/o/r?rev=1#1"' \
        'index = "sparse+https://index.example.org/"' \
        'url = ssh://git@git.example.com:2222/o/r.git' \
        'http://user:pw@mirror.example.net:8080/x'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "github.com	TAG" ]
    [ "${lines[1]}" = "index.example.org	TAG" ]
    [ "${lines[2]}" = "git.example.com	TAG" ]
    [ "${lines[3]}" = "mirror.example.net	TAG" ]
}

@test "scp-like git remotes give their host" {
    run hosts '	url = git@gitlab.example.com:o/r.git'
    [ "$status" -eq 0 ]
    [ "$output" = "gitlab.example.com	TAG" ]
}

@test "hosts are lowercased; names without a dot are not hosts" {
    run hosts 'https://Files.Example.ORG/x' 'http://localhost:3000/' 'file:///etc/hosts'
    [ "$status" -eq 0 ]
    [ "$output" = "files.example.org	TAG" ]
}

@test "text without URLs prints nothing and passes" {
    run hosts 'no urls at all' ''
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "no tag is a usage error" {
    run bash "$SCRIPT" </dev/null
    [ "$status" -eq 2 ]
}
