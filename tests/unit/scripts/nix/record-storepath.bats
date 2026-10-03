#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/nix/record-storepath.sh (SPEC nix:T18, nix:V15,
# V20): write the agent home's activation store path to
# cloud-home.storepath, only once the cache proves it holds that path.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/nix/record-storepath.sh"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    mkdir -p "$STUBS"
    export CLOUD_HOME_STOREPATH="$BATS_TEST_TMPDIR/cloud-home.storepath"
    export CACHIX_URL="https://cache.example"
    export NIX_LOG="$BATS_TEST_TMPDIR/nix.log"
    export CURL_LOG="$BATS_TEST_TMPDIR/curl.log"
    export STORE_PATH="/nix/store/abc123xyz-home-manager-generation"
    export NARINFO_CODE=200
    export NIX_EXIT=0

    # nix: logs its args, prints the store path an eval would print.
    cat >"$STUBS/nix" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$NIX_LOG"
[ "$NIX_EXIT" = 0 ] || exit "$NIX_EXIT"
printf '%s' "$STORE_PATH"
EOF
    # curl: logs the URL and its args, answers with the HTTP code under
    # test, exits CURL_EXIT (7 = could not connect, after printing 000).
    export CURL_ARGS="$BATS_TEST_TMPDIR/curl.args"
    cat >"$STUBS/curl" <<'EOF'
#!/usr/bin/env bash
echo "${*: -1}" >>"$CURL_LOG"
echo "$*" >>"$CURL_ARGS"
printf '%s' "$NARINFO_CODE"
exit "${CURL_EXIT:-0}"
EOF
    chmod +x "$STUBS/nix" "$STUBS/curl"
    export PATH="$STUBS:$PATH"
}

@test "cached path: written to the file, one line" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(cat "$CLOUD_HOME_STOREPATH")" = "$STORE_PATH" ]
    [ "$(wc -l <"$CLOUD_HOME_STOREPATH")" -eq 1 ]
}

@test "evaluates the activation package of the given flake" {
    run bash "$SCRIPT" "git+https://example/repo?rev=abc"
    [ "$status" -eq 0 ]
    grep -q 'git+https://example/repo?rev=abc#homeConfigurations.cloud.activationPackage' "$NIX_LOG"
}

@test "default flake is the current directory" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    grep -q '\.#homeConfigurations.cloud.activationPackage' "$NIX_LOG"
}

@test "asks the cache for the path's narinfo" {
    run bash "$SCRIPT"
    [ "$(cat "$CURL_LOG")" = "https://cache.example/abc123xyz.narinfo" ]
}

@test "path not in the cache: fails, file untouched" {
    echo "/nix/store/old-home" >"$CLOUD_HOME_STOREPATH"
    NARINFO_CODE=404 run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"404"* ]]
    [ "$(cat "$CLOUD_HOME_STOREPATH")" = "/nix/store/old-home" ]
}

@test "evaluation fails: fails as could not run, no file written" {
    NIX_EXIT=1 run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"could not evaluate"* ]]
    [ ! -e "$CLOUD_HOME_STOREPATH" ]
}

@test "not a store path: refused, no file written" {
    STORE_PATH="garbage" run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [ ! -e "$CLOUD_HOME_STOREPATH" ]
}

@test "more than one argument is a usage error" {
    run bash "$SCRIPT" a b
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
}

@test "unreachable cache: fails with HTTP 000, file untouched (T74)" {
    echo "/nix/store/old-home" >"$CLOUD_HOME_STOREPATH"
    NARINFO_CODE=000 CURL_EXIT=7 run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"000"* ]]
    [[ "$output" == *"nothing was recorded"* ]]
    [ "$(cat "$CLOUD_HOME_STOREPATH")" = "/nix/store/old-home" ]
}

@test "the narinfo request is bounded: --connect-timeout and --max-time (T74)" {
    run bash "$SCRIPT"
    grep -q -- '--connect-timeout' "$CURL_ARGS"
    grep -q -- '--max-time' "$CURL_ARGS"
}

@test "a new path: names the file, the old path and the new one (T74)" {
    echo "/nix/store/old-home" >"$CLOUD_HOME_STOREPATH"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"updated"* ]]
    [[ "$output" == *"$CLOUD_HOME_STOREPATH"* ]]
    [[ "$output" == *"/nix/store/old-home"* ]]
    [[ "$output" == *"$STORE_PATH"* ]]
}

@test "the same path again: says it is unchanged (T74)" {
    echo "$STORE_PATH" >"$CLOUD_HOME_STOREPATH"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"unchanged"* ]]
    [ "$(cat "$CLOUD_HOME_STOREPATH")" = "$STORE_PATH" ]
}

@test "no file yet: says it was created (T74)" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"created"* ]]
}
