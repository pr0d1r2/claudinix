#!/usr/bin/env bats
# Unit tests for scripts/ci/verify-cachix.sh (SPEC T23, V22, V18).

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/ci/verify-cachix.sh"
    BIN="$BATS_TEST_TMPDIR/bin"
    CURL_LOG="$BATS_TEST_TMPDIR/curl.log"
    export CURL_LOG
    mkdir -p "$BIN"
    # nix eval prints a store path named after the attribute's last part.
    cat >"$BIN/nix" <<'STUB'
#!/usr/bin/env bash
[ "$1 $2" = "eval --raw" ] || exit 9
case "$3" in
*broken*) echo "error: attribute missing" >&2; exit 1 ;;
esac
name="${3%.outPath}"
name="${name##*.}"
printf '/nix/store/%s-%s' "aaaabbbbccccddddeeeeffffgggghhh${#name}" "$name"
STUB
    chmod +x "$BIN/nix"
    PATH="$BIN:$PATH"
}

stub_curl() {
    # Prints the HTTP code curl's -w would; logs the URL it was asked for.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '#!/usr/bin/env bash\nfor a in "$@"; do url="$a"; done\necho "$url" >>"$CURL_LOG"\nprintf %s\n' "$1" >"$BIN/curl"
    chmod +x "$BIN/curl"
}

@test "no attributes is a usage error: an empty list proves nothing" {
    stub_curl 200
    run bash "$SCRIPT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
}

@test "every path has a narinfo: passes and asks the cache for each" {
    stub_curl 200
    run bash "$SCRIPT" .#checks.x86_64-linux.xenolith .#devShells.x86_64-linux.default
    [ "$status" -eq 0 ]
    [ "$(wc -l <"$CURL_LOG" | tr -d ' ')" -eq 2 ]
    grep -q '^https://pr0d1r2.cachix.org/aaaabbbbccccddddeeeeffffgggghhh8.narinfo$' "$CURL_LOG"
}

@test "a missing narinfo fails and names the path and the code" {
    stub_curl 404
    run bash "$SCRIPT" .#checks.x86_64-linux.xenolith
    [ "$status" -eq 1 ]
    [[ "$output" == *"-xenolith"* ]]
    [[ "$output" == *"404"* ]]
}

@test "a refused request (403) fails too" {
    stub_curl 403
    run bash "$SCRIPT" .#checks.x86_64-linux.xenolith
    [ "$status" -eq 1 ]
    [[ "$output" == *"403"* ]]
}

@test "an attribute that does not evaluate fails as could not run" {
    stub_curl 200
    run bash "$SCRIPT" .#checks.x86_64-linux.broken
    [ "$status" -eq 1 ]
    [[ "$output" == *"could not"* ]]
}

@test "CACHIX_URL seam picks another cache" {
    stub_curl 200
    run env CACHIX_URL=https://other.cachix.org bash "$SCRIPT" .#checks.x86_64-linux.xenolith
    [ "$status" -eq 0 ]
    grep -q '^https://other.cachix.org/' "$CURL_LOG"
}
