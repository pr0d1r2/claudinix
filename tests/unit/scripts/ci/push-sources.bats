#!/usr/bin/env bats
# Unit tests for scripts/ci/push-sources.sh (SPEC T74, V30, V18): push
# every eval-time input source `nix flake archive` names to the cache,
# so a cloud session can substitute what it cannot fetch from GitHub.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/ci/push-sources.sh"
    BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$BIN"
    export NIX_LOG="$BATS_TEST_TMPDIR/nix.log"
    export CACHIX_LOG="$BATS_TEST_TMPDIR/cachix.log"
    export CACHIX_STDIN="$BATS_TEST_TMPDIR/cachix.stdin"
    export ARCHIVE_JSON='{"path":"/nix/store/0000self-source","inputs":{"a":{"path":"/nix/store/1111a-source","inputs":{}},"b":{"path":"/nix/store/2222b-source","inputs":{"c":{"path":"/nix/store/3333c-source","inputs":{}}}}}}'
    # nix flake archive: logs its args, prints $ARCHIVE_JSON or fails.
    cat >"$BIN/nix" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$NIX_LOG"
[ -z "${ARCHIVE_FAIL:-}" ] || exit 1
printf '%s\n' "$ARCHIVE_JSON"
STUB
    # cachix push: logs its args and the paths it read on stdin.
    cat >"$BIN/cachix" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$CACHIX_LOG"
cat >>"$CACHIX_STDIN"
[ -z "${CACHIX_FAIL:-}" ] || exit 1
STUB
    chmod +x "$BIN/nix" "$BIN/cachix"
    PATH="$BIN:$PATH"
}

@test "no cache named is a usage error" {
    run bash "$SCRIPT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
    [ ! -e "$CACHIX_LOG" ]
}

@test "more than two arguments is a usage error" {
    run bash "$SCRIPT" cache . extra
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
}

@test "every source, nested inputs too, goes to cachix push CACHE" {
    run bash "$SCRIPT" mycache
    [ "$status" -eq 0 ]
    [ "$(cat "$CACHIX_LOG")" = "push mycache" ]
    for p in 0000self 1111a 2222b 3333c; do
        grep -qx "/nix/store/$p-source" "$CACHIX_STDIN"
    done
    [ "$(wc -l <"$CACHIX_STDIN" | tr -d ' ')" -eq 4 ]
}

@test "archives the flake into the store (not a dry run), default ." {
    run bash "$SCRIPT" mycache
    [ "$status" -eq 0 ]
    grep -q '^flake archive --json \.$' "$NIX_LOG"
    run ! grep -q -- '--dry-run' "$NIX_LOG"
}

@test "the FLAKE argument picks the flake" {
    run bash "$SCRIPT" mycache "git+https://example/repo?rev=abc"
    [ "$status" -eq 0 ]
    grep -qF 'flake archive --json git+https://example/repo?rev=abc' "$NIX_LOG"
}

@test "says how many paths it pushed" {
    run bash "$SCRIPT" mycache
    [[ "$output" == *"4"* ]]
    [[ "$output" == *"mycache"* ]]
}

@test "archive fails: could not run, nothing pushed (V18)" {
    ARCHIVE_FAIL=1 run bash "$SCRIPT" mycache
    [ "$status" -eq 1 ]
    [[ "$output" == *"could not"* ]]
    [ ! -e "$CACHIX_LOG" ]
}

@test "archive names no path: fails, nothing pushed" {
    ARCHIVE_JSON='{}' run bash "$SCRIPT" mycache
    [ "$status" -eq 1 ]
    [[ "$output" == *"no source"* ]]
    [ ! -e "$CACHIX_LOG" ]
}

@test "cachix push fails: fails and says so" {
    CACHIX_FAIL=1 run bash "$SCRIPT" mycache
    [ "$status" -eq 1 ]
    [[ "$output" == *"cachix push"* ]]
}
