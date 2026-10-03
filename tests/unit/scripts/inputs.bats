#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/inputs.sh (SPEC scripts:T25, I.cmd `inputs`,
# .:V8, V21). nix and curl are stubs: no network, no store.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../scripts/inputs.sh"
    FIXTURES="$BATS_TEST_DIRNAME/../../fixtures/inputs"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    PROJECT="$BATS_TEST_TMPDIR/project"
    export CODES="$BATS_TEST_TMPDIR/codes"
    export NIX_LOG="$BATS_TEST_TMPDIR/nix.log"
    export NIX_ARCHIVE="$FIXTURES/nested/archive.json"
    export STUB_ARCHIVE_RC=0
    unset INPUTS_CACHES
    mkdir -p "$STUBS" "$PROJECT" "$CODES"
    cp "$FIXTURES/nested/flake.lock" "$PROJECT/flake.lock"

    # nix: `flake archive --dry-run --json DIR` prints the fixture tree.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$NIX_LOG"' \
        '[ "$1 $2" = "flake archive" ] || exit 9' \
        '[ "$STUB_ARCHIVE_RC" = 0 ] || { echo "error: cannot fetch" >&2; exit "$STUB_ARCHIVE_RC"; }' \
        'cat "$NIX_ARCHIVE"' >"$STUBS/nix"
    # curl: prints the HTTP code stored as $CODES/<host>/<file>, else 404.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'for a in "$@"; do url="$a"; done' \
        'rest="${url#https://}"' \
        'f="$CODES/${rest%%/*}/${rest##*/}"' \
        'if [ -f "$f" ]; then cat "$f"; else printf 404; fi' >"$STUBS/curl"
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"
}

# cached HOST HASH: the cache at HOST has a narinfo for HASH.
cached() {
    mkdir -p "$CODES/$1"
    printf 200 >"$CODES/$1/$2.narinfo"
}

@test "every github input once: nested, deduped, non-github skipped" {
    run --separate-stderr bash "$SCRIPT" "$PROJECT"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 4 ]
    [ "${lines[0]}" = "NixOS/nixpkgs 6666666666666666666666666666666666666666 uncached" ]
    [ "${lines[1]}" = "owner/e 5555555555555555555555555555555555555555 uncached" ]
    [ "${lines[2]}" = "pr0d1r2/a 1111111111111111111111111111111111111111 uncached" ]
    [ "${lines[3]}" = "pr0d1r2/b 2222222222222222222222222222222222222222 uncached" ]
    [[ "$output" != *"example.org"* ]]
}

@test "a narinfo in the owner cachix marks the input cached" {
    cached pr0d1r2.cachix.org aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    cached pr0d1r2.cachix.org ffffffffffffffffffffffffffffffff
    run bash "$SCRIPT" "$PROJECT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pr0d1r2/a 1111111111111111111111111111111111111111 cached"* ]]
    [[ "$output" == *"owner/e 5555555555555555555555555555555555555555 cached"* ]]
    [[ "$output" == *"pr0d1r2/b 2222222222222222222222222222222222222222 uncached"* ]]
}

@test "a narinfo in cache.nixos.org marks the input cached (.:V8, probe 4)" {
    cached cache.nixos.org nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn
    run bash "$SCRIPT" "$PROJECT"
    [[ "$output" == *"NixOS/nixpkgs 6666666666666666666666666666666666666666 cached"* ]]
}

@test "INPUTS_CACHES seam picks the caches asked" {
    cached pr0d1r2.cachix.org bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
    cached other.example bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
    INPUTS_CACHES="https://nowhere.example" run bash "$SCRIPT" "$PROJECT"
    [[ "$output" == *"pr0d1r2/b 2222222222222222222222222222222222222222 uncached"* ]]
    INPUTS_CACHES="https://nowhere.example https://other.example" run bash "$SCRIPT" "$PROJECT"
    [[ "$output" == *"pr0d1r2/b 2222222222222222222222222222222222222222 cached"* ]]
}

@test "--check: exit 1 when any input must be attached" {
    run bash "$SCRIPT" --check "$PROJECT"
    [ "$status" -eq 1 ]
    [[ "$output" == *" uncached"* ]]
}

@test "--check: exit 0 when every input is cached" {
    for h in aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
        ffffffffffffffffffffffffffffffff nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn; do
        cached pr0d1r2.cachix.org "$h"
    done
    run bash "$SCRIPT" "$PROJECT" --check
    [ "$status" -eq 0 ]
    [[ "$output" != *" uncached"* ]]
}

@test "default flake dir is the current directory, passed to nix absolute" {
    cd "$PROJECT"
    run --separate-stderr bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 4 ]
    grep -q "^flake archive --dry-run --json $PROJECT\$" "$NIX_LOG"
}

@test "a relative flake dir is resolved, never read as a registry name" {
    cd "$BATS_TEST_TMPDIR"
    run bash "$SCRIPT" project
    [ "$status" -eq 0 ]
    grep -q "^flake archive --dry-run --json $PROJECT\$" "$NIX_LOG"
}

@test "no flake.lock: fails and says nothing was checked" {
    rm "$PROJECT/flake.lock"
    run bash "$SCRIPT" "$PROJECT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"nothing was checked"* ]]
}

@test "nix flake archive failing is could-not-run, not a clean list" {
    export STUB_ARCHIVE_RC=1
    run bash "$SCRIPT" "$PROJECT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"could not run"* ]]
}

@test "a lock with no github inputs prints nothing and passes --check" {
    printf '%s\n' '{"nodes":{"root":{"inputs":{}}},"root":"root","version":7}' >"$PROJECT/flake.lock"
    run bash "$SCRIPT" --check "$PROJECT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "unknown flag or two dirs is a usage error" {
    run bash "$SCRIPT" --nope
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
    run bash "$SCRIPT" "$PROJECT" "$PROJECT"
    [ "$status" -eq 2 ]
}

@test "a missing flake dir: the error names the argument given, not ." {
    run bash "$SCRIPT" "$BATS_TEST_TMPDIR/nonexistent"
    [ "$status" -eq 1 ]
    [[ "$output" == *"no directory $BATS_TEST_TMPDIR/nonexistent "* ]]
    [[ "$output" == *"nothing was checked"* ]]
}

# scripts:T80 (review R3-4): say what to do about uncached inputs.

@test "uncached inputs: one remedy line on stderr, the list stays on stdout" {
    run --separate-stderr bash "$SCRIPT" "$PROJECT"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 4 ]
    [ "${#stderr_lines[@]}" -eq 1 ]
    [[ "$stderr" == *"nix-dev"* ]]
    [[ "$stderr" == *"git+https://github.com/<owner>/<repo>"* ]]
}

@test "--check keeps its exit codes and prints the remedy once" {
    run --separate-stderr bash "$SCRIPT" --check "$PROJECT"
    [ "$status" -eq 1 ]
    [ "${#stderr_lines[@]}" -eq 1 ]
    [[ "$stderr" == *"nix-dev"* ]]
}

@test "every input cached: no remedy line" {
    for h in aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
        ffffffffffffffffffffffffffffffff nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn; do
        cached pr0d1r2.cachix.org "$h"
    done
    run --separate-stderr bash "$SCRIPT" --check "$PROJECT"
    [ "$status" -eq 0 ]
    [ -z "$stderr" ]
}
