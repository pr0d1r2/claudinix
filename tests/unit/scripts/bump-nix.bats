#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/bump-nix.sh (SPEC T10, V11, C4): fetch the
# installer's published sha256 for a Nix version and rewrite the version
# and the default sha256 in setup.sh together. `curl` is a stub that logs
# its URL and prints CURL_BODY (exit CURL_RC); nothing leaves the test.

setup() {
    REPO="$BATS_TEST_DIRNAME/../../.."
    SCRIPT="$REPO/scripts/bump-nix.sh"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    export BUMP_SETUP="$BATS_TEST_TMPDIR/setup.sh"
    export CURL_LOG="$BATS_TEST_TMPDIR/curl.log"
    export CURL_BODY=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    export CURL_RC=0
    mkdir -p "$STUBS"
    cp "$REPO/setup.sh" "$BUMP_SETUP"
    cp "$BUMP_SETUP" "$BATS_TEST_TMPDIR/before"
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'for a in "$@"; do case "$a" in https://*) echo "$a" >>"$CURL_LOG" ;; esac; done' \
        '[ "$CURL_RC" = 0 ] || exit "$CURL_RC"' 'printf "%s\n" "$CURL_BODY"' >"$STUBS/curl"
    chmod +x "$STUBS/curl"
    export PATH="$STUBS:$PATH"
}

unchanged() {
    cmp "$BATS_TEST_TMPDIR/before" "$BUMP_SETUP"
}

@test "fetches the installer's sha256 for that version from releases.nixos.org" {
    run bash "$SCRIPT" 2.36.0
    [ "$status" -eq 0 ]
    [ "$(cat "$CURL_LOG")" = "https://releases.nixos.org/nix/nix-2.36.0/install.sha256" ]
}

@test "rewrites the version and the default sha256 together, nothing else (V11)" {
    run bash "$SCRIPT" 2.36.0
    [ "$status" -eq 0 ]
    grep -qx 'version=2.36.0' "$BUMP_SETUP"
    grep -qF "sha256=\"\${NIX_INSTALL_SHA256:-$CURL_BODY}\"" "$BUMP_SETUP"
    [ "$(diff "$BATS_TEST_TMPDIR/before" "$BUMP_SETUP" | grep -c '^>')" -eq 2 ]
    [ "$(diff "$BATS_TEST_TMPDIR/before" "$BUMP_SETUP" | grep -c '^<')" -eq 2 ]
}

@test "the bumped setup.sh still parses" {
    run bash "$SCRIPT" 2.36.0
    [ "$status" -eq 0 ]
    bash -n "$BUMP_SETUP"
}

@test "a published hash with surrounding whitespace is accepted" {
    CURL_BODY="  $CURL_BODY  " run bash "$SCRIPT" 2.36.0
    [ "$status" -eq 0 ]
    grep -qF ":-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}\"" "$BUMP_SETUP"
}

@test "a malformed version is refused before any fetch" {
    for v in 2.36 v2.36.0 '2.36.0;x' '2.36.0 ' '' 2.36.0-pre; do
        run bash "$SCRIPT" "$v"
        [ "$status" -eq 2 ]
    done
    [ ! -e "$CURL_LOG" ]
    unchanged
}

@test "a malformed hash is refused, setup.sh untouched" {
    for h in abc 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' \
        '<html>404</html>' "${CURL_BODY}0" "${CURL_BODY} extra"; do
        CURL_BODY="$h" run bash "$SCRIPT" 2.36.0
        [ "$status" -eq 1 ]
        [[ "$output" == *"sha256"* ]]
    done
    unchanged
}

@test "the fetch failing: refused, setup.sh untouched" {
    CURL_RC=22 run bash "$SCRIPT" 2.36.0
    [ "$status" -eq 1 ]
    unchanged
}

@test "setup.sh without one pin line each: refused, untouched" {
    sed -i.orig '/^version=/d' "$BUMP_SETUP"
    cp "$BUMP_SETUP" "$BATS_TEST_TMPDIR/before"
    run bash "$SCRIPT" 2.36.0
    [ "$status" -eq 1 ]
    unchanged
}

@test "wrong number of arguments is a usage error" {
    run bash "$SCRIPT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
    run bash "$SCRIPT" 2.36.0 2.36.1
    [ "$status" -eq 2 ]
}

@test "just bump-nix runs this script (I.cmd)" {
    grep -qx '    scripts/bump-nix.sh {{ ver }}' "$REPO/justfile"
}
