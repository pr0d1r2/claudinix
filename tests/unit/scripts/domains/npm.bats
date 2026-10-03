#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/domains/npm.sh (SPEC scripts:T27, I.cmd
# `domains`): `resolved` hosts from the JavaScript lock files.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/domains/npm.sh"
    P="$BATS_TEST_TMPDIR/project"
    mkdir -p "$P"
}

@test "package-lock.json resolved hosts; homepage URLs are not fetched" {
    printf '%s\n' '{' '  "packages": {' '    "node_modules/a": {' \
        '      "resolved": "https://registry.npmjs.org/a/-/a-1.0.0.tgz",' \
        '      "funding": "https://funding.example.org/a"' '    }' '  }' '}' >"$P/package-lock.json"
    run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [ "$output" = "registry.npmjs.org	package-lock.json" ]
}

@test "yarn.lock and pnpm-lock.yaml resolved and tarball hosts" {
    printf '%s\n' 'a@^1.0.0:' '  version "1.0.0"' \
        '  resolved "https://registry.yarnpkg.com/a/-/a-1.0.0.tgz#abc"' >"$P/yarn.lock"
    printf '%s\n' 'packages:' '  /b@1.0.0:' \
        '    resolution: {tarball: https://npm.example.com/b/-/b-1.0.0.tgz}' >"$P/pnpm-lock.yaml"
    run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [[ "$output" == *"registry.yarnpkg.com	yarn.lock"* ]]
    [[ "$output" == *"npm.example.com	pnpm-lock.yaml"* ]]
}

@test "no lock files: prints nothing and passes" {
    run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
