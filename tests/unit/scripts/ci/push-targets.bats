#!/usr/bin/env bats
# Unit tests for scripts/ci/push-targets.sh (SPEC T93, .:V30, C28, V6): the
# central cache job. For each flake ref in a targets file whose
# `.claudinix.toml` says `push_sources = true`, push its eval-time sources
# to the cache its `cache.name` names, then verify them. Sources only.

setup() {
    REAL="$BATS_TEST_DIRNAME/../../../../scripts"
    TREE="$BATS_TEST_TMPDIR/tree"
    mkdir -p "$TREE/scripts/ci" "$BATS_TEST_TMPDIR/bin"
    cp "$REAL/ci/push-targets.sh" "$TREE/scripts/ci/"
    SCRIPT="$TREE/scripts/ci/push-targets.sh"
    export CALLS="$BATS_TEST_TMPDIR/calls.log"
    : >"$CALLS"
    # config.sh: reads $CFG_<dirbase>_<key> style via a per-dir file.
    cat >"$TREE/scripts/config.sh" <<'STUB'
#!/usr/bin/env bash
# usage: config.sh --dir D get KEY ; D/cfg holds KEY=VALUE lines
dir="$2"; key="$4"
val="$(sed -n "s/^$key=//p" "$dir/cfg")"
[ -n "$val" ] || { [ "$key" = cache.push_sources ] && val=false; }
printf '%s\n' "$val"
STUB
    for s in push-sources verify-cachix; do
        cat >"$TREE/scripts/ci/$s.sh" <<STUB
#!/usr/bin/env bash
echo "$s \$CACHIX_URL | \$*" >>"\$CALLS"
[ -z "\${FAIL_${s//-/_}:-}" ] || exit 1
STUB
    done
    # nix flake metadata --json REF -> {"path": <dir of that ref>}
    cat >"$BATS_TEST_TMPDIR/bin/nix" <<'STUB'
#!/usr/bin/env bash
ref="${@: -1}"
printf '{"path":"%s/%s"}\n' "$SRC" "${ref##*/}"
STUB
    chmod +x "$TREE"/scripts/config.sh "$TREE"/scripts/ci/*.sh "$BATS_TEST_TMPDIR/bin/nix"
    export SRC="$BATS_TEST_TMPDIR/src"
    PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    TARGETS="$BATS_TEST_TMPDIR/targets.txt"
}

# target NAME PUSH CACHE: a fake fetched flake source.
target() {
    mkdir -p "$SRC/$1"
    printf 'cache.push_sources=%s\ncache.name=%s\n' "$2" "$3" >"$SRC/$1/cfg"
}

@test "a missing targets file is a usage error" {
    run bash "$SCRIPT" "$BATS_TEST_TMPDIR/none.txt"
    [ "$status" -eq 2 ]
    [[ "$output" == *"targets"* ]]
}

@test "an opted-in target is pushed to its own cache name, then verified" {
    target a true cachea
    echo "github:o/a" >"$TARGETS"
    run bash "$SCRIPT" "$TARGETS"
    [ "$status" -eq 0 ]
    grep -qx 'push-sources  | cachea github:o/a' "$CALLS"
    grep -qx 'verify-cachix https://cachea.cachix.org | --sources github:o/a' "$CALLS"
    [ "$(grep -n push-sources "$CALLS" | cut -d: -f1)" -lt "$(grep -n verify-cachix "$CALLS" | cut -d: -f1)" ]
}

@test "a target without push_sources = true is skipped" {
    target a false cachea
    echo "github:o/a" >"$TARGETS"
    run bash "$SCRIPT" "$TARGETS"
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
    [[ "$output" == *"skip"* ]]
}

@test "blank lines and comments are ignored" {
    target a true cachea
    printf '# owner repos\n\ngithub:o/a\n' >"$TARGETS"
    run bash "$SCRIPT" "$TARGETS"
    [ "$status" -eq 0 ]
    [ "$(grep -c push-sources "$CALLS")" -eq 1 ]
}

@test "one failing target does not stop the next, and the run fails" {
    target a true cachea
    target b true cacheb
    printf 'github:o/a\ngithub:o/b\n' >"$TARGETS"
    FAIL_push_sources=1 run bash "$SCRIPT" "$TARGETS"
    [ "$status" -eq 1 ]
    [ "$(grep -c '^push-sources' "$CALLS")" -eq 2 ]
    [ "$(grep -c '^verify-cachix' "$CALLS")" -eq 0 ]
}

@test "a failed verify fails the run" {
    target a true cachea
    echo "github:o/a" >"$TARGETS"
    FAIL_verify_cachix=1 run bash "$SCRIPT" "$TARGETS"
    [ "$status" -eq 1 ]
}

@test "an unfetchable target fails the run and names the ref" {
    echo "github:o/a" >"$TARGETS"
    printf '#!/usr/bin/env bash\nexit 1\n' >"$BATS_TEST_TMPDIR/bin/nix"
    run bash "$SCRIPT" "$TARGETS"
    [ "$status" -eq 1 ]
    [[ "$output" == *"github:o/a"* ]]
}
