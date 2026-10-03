#!/usr/bin/env bats
# Unit tests for scripts/ci/verify-cachix.sh (SPEC T23, V22, V18).

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/ci/verify-cachix.sh"
    BIN="$BATS_TEST_TMPDIR/bin"
    CURL_LOG="$BATS_TEST_TMPDIR/curl.log"
    export CURL_LOG
    mkdir -p "$BIN"
    # nix eval prints a store path named after the attribute's last part;
    # nix flake archive prints $ARCHIVE_JSON (or fails, ARCHIVE_FAIL).
    export ARCHIVE_LOG="$BATS_TEST_TMPDIR/archive.log"
    # config.sh's `nix eval --impure` of a .claudinix.toml is the real nix.
    REAL_NIX="$(command -v nix)"
    export REAL_NIX
    cat >"$BIN/nix" <<'STUB'
#!/usr/bin/env bash
case "$*" in *--impure*) exec "$REAL_NIX" "$@" ;; esac
if [ "$1 $2" = "flake archive" ]; then
    echo "$*" >>"$ARCHIVE_LOG"
    [ -z "${ARCHIVE_FAIL:-}" ] || exit 1
    printf '%s\n' "$ARCHIVE_JSON"
    exit 0
fi
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
    # Out of this repo, whose own .claudinix.toml is not the test's.
    unset CACHIX_URL CLAUDINIX_CONFIG
    export GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR"
    PROJECT="$BATS_TEST_TMPDIR/project"
    mkdir -p "$PROJECT"
    cd "$PROJECT" || return 1
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

# An unreachable cache (T74): curl exits non-zero after printing 000.
# That is a red result with the code, not a silent abort.
stub_curl_down() {
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' 'echo "$*" >>"$CURL_LOG"' 'printf 000' 'exit 7' >"$BIN/curl"
    chmod +x "$BIN/curl"
}

@test "an unreachable cache fails with HTTP 000, not a silent exit (T74)" {
    stub_curl_down
    run bash "$SCRIPT" .#devShells.x86_64-linux.default
    [ "$status" -eq 1 ]
    [[ "$output" == *"000"* ]]
    [[ "$output" == *"-default"* ]]
}

@test "every narinfo request is bounded: --connect-timeout and --max-time (T74)" {
    stub_curl_down
    run bash "$SCRIPT" .#devShells.x86_64-linux.default
    grep -q -- '--connect-timeout' "$CURL_LOG"
    grep -q -- '--max-time' "$CURL_LOG"
}

# Eval-time input sources (T74, V30): every path `nix flake archive`
# names, nested inputs included, has a narinfo in the owner cache or in
# cache.nixos.org (nixpkgs' source is served from there).
ARCHIVE='{"path":"/nix/store/0000self-source","inputs":{"a":{"path":"/nix/store/1111a-source","inputs":{}},"b":{"path":"/nix/store/2222b-source","inputs":{"c":{"path":"/nix/store/3333c-source","inputs":{}}}}}}'

# Answers $CACHE_CODE for the owner cache, $UPSTREAM_CODE for
# cache.nixos.org; logs every URL.
stub_curl_by_host() {
    export CACHE_CODE="$1" UPSTREAM_CODE="$2"
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' 'for a in "$@"; do url="$a"; done' 'echo "$url" >>"$CURL_LOG"' \
        'case "$url" in https://cache.nixos.org/*) printf %s "$UPSTREAM_CODE" ;; *) printf %s "$CACHE_CODE" ;; esac' >"$BIN/curl"
    chmod +x "$BIN/curl"
}

@test "--sources: every input source, nested too, is checked in the cache (T74)" {
    stub_curl_by_host 200 404
    ARCHIVE_JSON="$ARCHIVE" run bash "$SCRIPT" --sources . .#devShells.x86_64-linux.default
    [ "$status" -eq 0 ]
    for h in 0000self 1111a 2222b 3333c; do
        grep -qx "https://pr0d1r2.cachix.org/$h.narinfo" "$CURL_LOG"
    done
    grep -q -- '--dry-run' "$ARCHIVE_LOG"
    grep -q -- '--json' "$ARCHIVE_LOG"
}

@test "--sources: a source only cache.nixos.org holds passes (V30)" {
    stub_curl_by_host 404 200
    ARCHIVE_JSON="$ARCHIVE" run bash "$SCRIPT" --sources .
    [ "$status" -eq 0 ]
    grep -qx 'https://cache.nixos.org/1111a.narinfo' "$CURL_LOG"
}

@test "--sources: a source in neither cache fails and names it (V30)" {
    stub_curl_by_host 404 404
    ARCHIVE_JSON="$ARCHIVE" run bash "$SCRIPT" --sources .
    [ "$status" -eq 1 ]
    [[ "$output" == *"/nix/store/3333c-source"* ]]
    [[ "$output" == *"404"* ]]
}

@test "--sources: an archive that fails to list is could not run (V18)" {
    stub_curl_by_host 200 200
    ARCHIVE_FAIL=1 run bash "$SCRIPT" --sources .
    [ "$status" -eq 1 ]
    [[ "$output" == *"could not"* ]]
}

@test "--sources: an archive naming no path proves nothing and fails" {
    stub_curl_by_host 200 200
    ARCHIVE_JSON='{}' run bash "$SCRIPT" --sources .
    [ "$status" -eq 1 ]
    [[ "$output" == *"no source"* ]]
}

@test "--sources without a flake is a usage error" {
    stub_curl 200
    run bash "$SCRIPT" --sources
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
}

@test "UPSTREAM_URL seam picks the fallback cache for sources" {
    stub_curl_by_host 404 404
    ARCHIVE_JSON="$ARCHIVE" UPSTREAM_URL=https://up.example run bash "$SCRIPT" --sources .
    grep -q '^https://up.example/' "$CURL_LOG"
}

# .claudinix.toml (scripts:T91, scripts:V34): cache.name picks the cachix.

@test "cache.name in the cwd's .claudinix.toml picks the cache to verify" {
    stub_curl 200
    printf '%s\n' 'version = 1' '[cache]' 'name = "forker"' >"$PROJECT/.claudinix.toml"
    run bash "$SCRIPT" .#checks.x86_64-linux.xenolith
    [ "$status" -eq 0 ]
    grep -q '^https://forker.cachix.org/' "$CURL_LOG"
    run grep -q 'pr0d1r2' "$CURL_LOG"
    [ "$status" -ne 0 ]
}

@test "--sources DIR: that flake's .claudinix.toml names the cache" {
    stub_curl_by_host 200 404
    other="$BATS_TEST_TMPDIR/other"
    mkdir -p "$other"
    printf '%s\n' 'version = 1' '[cache]' 'name = "forker"' >"$other/.claudinix.toml"
    ARCHIVE_JSON="$ARCHIVE" run bash "$SCRIPT" --sources "$other"
    [ "$status" -eq 0 ]
    grep -qx 'https://forker.cachix.org/1111a.narinfo' "$CURL_LOG"
}

@test "CACHIX_URL still wins over cache.name (V34)" {
    stub_curl 200
    printf '%s\n' 'version = 1' '[cache]' 'name = "forker"' >"$PROJECT/.claudinix.toml"
    run env CACHIX_URL=https://other.cachix.org bash "$SCRIPT" .#checks.x86_64-linux.xenolith
    [ "$status" -eq 0 ]
    grep -q '^https://other.cachix.org/' "$CURL_LOG"
}

@test "a bad .claudinix.toml: exit 2 naming the file and key, nothing verified" {
    stub_curl 200
    printf '%s\n' 'version = 1' '[cache]' 'url = "https://forker.cachix.org"' >"$PROJECT/.claudinix.toml"
    run bash "$SCRIPT" .#checks.x86_64-linux.xenolith
    [ "$status" -eq 2 ]
    [[ "$output" == *".claudinix.toml"* ]]
    [[ "$output" == *"cache.url"* ]]
    [ ! -e "$CURL_LOG" ]
}
