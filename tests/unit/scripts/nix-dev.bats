#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/nix-dev.sh (SPEC scripts:T12, scripts:V13,
# .:V8, I.cmd `nix-dev`). nix is a stub that decides, from the args a
# tier passes, whether `print-dev-env` succeeds.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../scripts/nix-dev.sh"
    FIXTURES="$BATS_TEST_DIRNAME/../../fixtures/inputs"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    PROJECT="$BATS_TEST_TMPDIR/project"
    export NIX_LOG="$BATS_TEST_TMPDIR/nix.log"
    export NIX_OK_PLAIN=0 NIX_OK_GIT=0 NIX_OK_CHANNEL=0
    mkdir -p "$STUBS" "$PROJECT"
    cp "$FIXTURES/nested/flake.lock" "$PROJECT/flake.lock"

    # print-dev-env: plain, git+https overrides, or a channel override
    # each succeed only when the test says so; a leading installable is
    # set aside first. A failure prints NIX_ERR_FILE, when set, on stderr.
    # develop: echoes its args. eval (config.sh parsing a
    # .claudinix.toml, scripts:T91) is the real nix.
    REAL_NIX="$(command -v nix)"
    export REAL_NIX
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$NIX_LOG"' \
        '[ "$1" != eval ] || exec "$REAL_NIX" "$@"' \
        'cmd="$1"; shift' \
        'case "$cmd" in' \
        'develop) echo "develop $*"; exit 0 ;;' \
        'print-dev-env) ;;' \
        '*) exit 9 ;;' \
        'esac' \
        'case "${1:-}" in -* | "") ;; *) shift ;; esac' \
        'case "$*" in' \
        '"") ok="$NIX_OK_PLAIN" ;;' \
        '*channels.nixos.org*) ok="$NIX_OK_CHANNEL" ;;' \
        '*git+https*) ok="$NIX_OK_GIT" ;;' \
        '*) ok=0 ;;' \
        'esac' \
        '[ "$ok" = 1 ] && exit 0' \
        '[ -z "${NIX_ERR_FILE:-}" ] || { cat "$NIX_ERR_FILE" >&2; exit 1; }' \
        'echo "error: unable to download: HTTP error 403" >&2' \
        'exit 1' >"$STUBS/nix"
    chmod +x "$STUBS/nix"
    export PATH="$STUBS:$PATH"
    unset CLAUDINIX_CONFIG CLAUDINIX_CONFIG_JSON CLAUDINIX_SCRIPTS
    export GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR"
    cd "$PROJECT" || return 1
}

@test "tier 1: plain nix develop works, args passed through, tier logged" {
    NIX_OK_PLAIN=1 run bash "$SCRIPT" --command cargo test
    [ "$status" -eq 0 ]
    [[ "$output" == *"tier 1"* ]]
    [[ "$output" == *"develop --command cargo test"* ]]
    [[ "$output" != *"tier 2"* ]]
}

@test "tier 2: git+https at the locked rev for every github input but nixpkgs" {
    NIX_OK_GIT=1 run bash "$SCRIPT" --command true
    [ "$status" -eq 0 ]
    [ "$(grep -o 'tier [0-9]' <<<"$output" | tail -n 1)" = "tier 2" ]
    dev="$(grep '^develop ' <<<"$output")"
    [[ "$dev" == *"--override-input a git+https://github.com/pr0d1r2/a?rev=1111111111111111111111111111111111111111&shallow=1"* ]]
    [[ "$dev" == *"--override-input b git+https://github.com/pr0d1r2/b?rev=2222222222222222222222222222222222222222&shallow=1"* ]]
    [[ "$dev" == *"--override-input b/e git+https://github.com/owner/e?rev=5555555555555555555555555555555555555555&shallow=1"* ]]
    [[ "$dev" == *"--no-write-lock-file"* ]]
    [[ "$dev" != *"NixOS/nixpkgs"* ]]
    [[ "$dev" == *"--command true" ]]
}

@test "tier 4: nixpkgs from the channel the lock names, others still git+https; warns" {
    NIX_OK_CHANNEL=1 run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(grep -o 'tier [0-9]' <<<"$output" | tail -n 1)" = "tier 4" ]
    [[ "$output" == *"warning"* ]]
    dev="$(grep '^develop ' <<<"$output")"
    [[ "$dev" == *"--override-input a/nixpkgs https://channels.nixos.org/nixos-26.05/nixexprs.tar.xz"* ]]
    [[ "$dev" == *"--override-input b git+https://"* ]]
    [[ "$dev" == *"--no-write-lock-file"* ]]
}

@test "tier 4: a nixpkgs ref that is not a channel falls back to nixpkgs-unstable" {
    jq '.nodes.nixpkgs.original.ref = "release-26.05"' "$PROJECT/flake.lock" >"$PROJECT/l" && mv "$PROJECT/l" "$PROJECT/flake.lock"
    NIX_OK_CHANNEL=1 run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz"* ]]
}

@test "tier 4: nixpkgs-unstable and nixos-unstable refs are kept" {
    jq '.nodes.nixpkgs.original.ref = "nixos-unstable"' "$PROJECT/flake.lock" >"$PROJECT/l" && mv "$PROJECT/l" "$PROJECT/flake.lock"
    NIX_OK_CHANNEL=1 run bash "$SCRIPT"
    [[ "$output" == *"channels.nixos.org/nixos-unstable/nixexprs.tar.xz"* ]]
}

@test "every tier failing: exit 1, says so, never runs nix develop" {
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"every tier failed"* ]]
    run ! grep -q '^develop' "$NIX_LOG"
}

@test "the same command is never tried twice" {
    run bash "$SCRIPT"
    [ "$(grep -cx 'print-dev-env' "$NIX_LOG")" -eq 1 ]
}

@test "no flake.lock: plain nix develop, logged as tier 1" {
    rm "$PROJECT/flake.lock"
    run bash "$SCRIPT" -c true
    [ "$status" -eq 0 ]
    [[ "$output" == *"tier 1"* ]]
    [[ "$output" == *"develop -c true"* ]]
}

@test "a lock without nixpkgs skips tier 4" {
    jq 'del(.nodes.nixpkgs) | del(.nodes.a.inputs.nixpkgs)' "$PROJECT/flake.lock" >"$PROJECT/l" && mv "$PROJECT/l" "$PROJECT/flake.lock"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    run ! grep -q 'channels.nixos.org' "$NIX_LOG"
}

# Auto-overrides (scripts:T49): the cache status comes from inputs.sh,
# stubbed here through CLAUDINIX_SCRIPTS beside a copy of nix-dev.jq.
inputs_stub() {
    export CLAUDINIX_SCRIPTS="$BATS_TEST_TMPDIR/lib"
    mkdir -p "$CLAUDINIX_SCRIPTS"
    cp "$BATS_TEST_DIRNAME/../../../scripts/nix-dev.jq" "$CLAUDINIX_SCRIPTS/"
    printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/inputs.out"
    printf '#!/usr/bin/env bash\ncat "%s"\n' "$BATS_TEST_TMPDIR/inputs.out" >"$CLAUDINIX_SCRIPTS/inputs.sh"
}

A=1111111111111111111111111111111111111111
B=2222222222222222222222222222222222222222
E=5555555555555555555555555555555555555555
N=6666666666666666666666666666666666666666

@test "auto: every input cached, tier 1 runs plain" {
    inputs_stub "pr0d1r2/a $A cached" "pr0d1r2/b $B cached" "owner/e $E cached" "NixOS/nixpkgs $N cached"
    NIX_OK_PLAIN=1 run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(grep -o 'tier [0-9]' <<<"$output" | tail -n 1)" = "tier 1" ]
}

@test "auto: uncached inputs skip tier 1; tier 2 overrides only those" {
    inputs_stub "pr0d1r2/a $A uncached" "pr0d1r2/b $B cached" "owner/e $E uncached" "NixOS/nixpkgs $N cached"
    NIX_OK_PLAIN=1 NIX_OK_GIT=1 run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"tier 1 skipped"* ]]
    [ "$(grep -o 'tier [0-9]' <<<"$output" | tail -n 1)" = "tier 2" ]
    [ "$(grep -c '^print-dev-env' "$NIX_LOG")" -eq 1 ]
    dev="$(grep '^develop ' <<<"$output")"
    [[ "$dev" == *"--override-input a git+https://github.com/pr0d1r2/a?rev=$A&shallow=1"* ]]
    [[ "$dev" == *"--override-input b/a git+https://"* ]]
    [[ "$dev" == *"--override-input b/e git+https://github.com/owner/e?rev=$E&shallow=1"* ]]
    [[ "$dev" != *"--override-input b git+https"* ]]
}

@test "auto: tier 2 failing falls to tier 3, github: as locked, warned" {
    inputs_stub "pr0d1r2/a $A uncached" "pr0d1r2/b $B cached" "owner/e $E cached" "NixOS/nixpkgs $N cached"
    NIX_OK_PLAIN=1 run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(grep -o 'tier [0-9]' <<<"$output" | tail -n 1)" = "tier 3" ]
    [[ "$output" == *"warning"* ]]
    [[ "$(grep '^develop ' <<<"$output")" != *"--override-input"* ]]
}

@test "auto: only nixpkgs uncached, nothing for tier 2 to override" {
    inputs_stub "pr0d1r2/a $A cached" "pr0d1r2/b $B cached" "owner/e $E cached" "NixOS/nixpkgs $N uncached"
    NIX_OK_CHANNEL=1 run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    run ! grep -q 'git+https' "$NIX_LOG"
    grep -q 'channels.nixos.org/nixos-26.05' "$NIX_LOG"
}

@test "auto: cache status unknown, every github input but nixpkgs overridden" {
    inputs_stub
    printf '#!/usr/bin/env bash\nexit 1\n' >"$CLAUDINIX_SCRIPTS/inputs.sh"
    NIX_OK_GIT=1 run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"cache status unknown"* ]]
    [ "$(grep -o 'tier [0-9]' <<<"$output" | tail -n 1)" = "tier 2" ]
    [[ "$(grep '^develop ' <<<"$output")" == *"--override-input b git+https"* ]]
}

# scripts:T79 (review R1-1,2,8,9,11).

@test "nixpkgs is matched case-insensitively: nixos/nixpkgs is never fetched over git" {
    jq '.nodes.nixpkgs.locked.owner = "nixos"' "$PROJECT/flake.lock" >"$PROJECT/l" && mv "$PROJECT/l" "$PROJECT/flake.lock"
    NIX_OK_CHANNEL=1 run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(grep -o 'tier [0-9]' <<<"$output" | tail -n 1)" = "tier 4" ]
    [[ "$(grep '^develop ' <<<"$output")" == *"--override-input a/nixpkgs https://channels.nixos.org/nixos-26.05/nixexprs.tar.xz"* ]]
    run ! grep -qi 'git+https://github.com/nixos/nixpkgs' "$NIX_LOG"
}

@test "a leading installable goes to every tier's print-dev-env and to nix develop" {
    NIX_OK_CHANNEL=1 run bash "$SCRIPT" '.#ci' -c true
    [ "$status" -eq 0 ]
    [ "$(grep -c '^print-dev-env' "$NIX_LOG")" -eq 3 ]
    [ "$(grep -c '^print-dev-env \.#ci' "$NIX_LOG")" -eq 3 ]
    dev="$(grep '^develop ' <<<"$output")"
    [[ "$dev" == "develop .#ci --no-write-lock-file "* ]]
    [[ "$dev" == *" -c true" ]]
    [ "$(grep -o '\.#ci' <<<"$dev" | wc -l | tr -d ' ')" -eq 1 ]
}

@test "a leading installable with a working plain tier: tier 1, installable kept" {
    NIX_OK_PLAIN=1 run bash "$SCRIPT" '.#ci' --command true
    [ "$status" -eq 0 ]
    grep -qx 'print-dev-env .#ci' "$NIX_LOG"
    [[ "$output" == *"develop .#ci --command true"* ]]
}

@test "a failing tier logs nix's error: line, not its last line" {
    printf '%s\n' 'warning: Git tree is dirty' \
        'error: unable to download https://github.com/x: HTTP error 403' \
        '       … while fetching the input' '' \
        '(use --show-trace to show detailed location information)' >"$BATS_TEST_TMPDIR/err"
    NIX_ERR_FILE="$BATS_TEST_TMPDIR/err" run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"tier 2 failed (github inputs as git+https at the locked rev): error: unable to download https://github.com/x: HTTP error 403"* ]]
    run ! grep -q 'failed.*--show-trace' <<<"$output"
}

@test "a failing tier without an error: line logs its last non-empty line" {
    printf '%s\n' 'something odd' 'the real last words' '' '' >"$BATS_TEST_TMPDIR/err"
    NIX_ERR_FILE="$BATS_TEST_TMPDIR/err" run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"tier 2 failed (github inputs as git+https at the locked rev): the real last words"* ]]
}

@test "no jq: one loud warning that failover is off, then plain nix develop" {
    nojq="$BATS_TEST_TMPDIR/nojq"
    mkdir -p "$nojq"
    for tool in bash dirname readlink cat; do
        ln -s "$(command -v "$tool")" "$nojq/$tool"
    done
    ln -s "$STUBS/nix" "$nojq/nix"
    PATH="$nojq" run "$nojq/bash" "$SCRIPT" -c true
    [ "$status" -eq 0 ]
    [ "$(grep -c 'WARNING' <<<"$output")" -eq 1 ]
    warning="$(grep 'WARNING' <<<"$output")"
    [[ "$warning" == *"jq"* ]]
    [[ "$warning" == *"failover is off"* ]]
    [[ "$warning" == *"tier 1"* ]]
    [[ "$output" == *"develop -c true"* ]]
}

@test "tier 4: each nixpkgs node gets the channel its own lock entry names" {
    jq '.nodes.nixpkgs_2 = (.nodes.nixpkgs | .original.ref = "nixos-unstable" | .locked.rev = "7777777777777777777777777777777777777777")
        | .nodes.b.inputs.nixpkgs = "nixpkgs_2"' "$PROJECT/flake.lock" >"$PROJECT/l" && mv "$PROJECT/l" "$PROJECT/flake.lock"
    NIX_OK_CHANNEL=1 run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    dev="$(grep '^develop ' <<<"$output")"
    [[ "$dev" == *"--override-input a/nixpkgs https://channels.nixos.org/nixos-26.05/nixexprs.tar.xz"* ]]
    [[ "$dev" == *"--override-input b/nixpkgs https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz"* ]]
}

@test "an installable in another dir reads that dir's lock" {
    mkdir "$PROJECT/sub"
    mv "$PROJECT/flake.lock" "$PROJECT/sub/flake.lock"
    NIX_OK_GIT=1 run bash "$SCRIPT" './sub#ci' -c true
    [ "$status" -eq 0 ]
    [[ "$(grep '^develop ' <<<"$output")" == "develop ./sub#ci --no-write-lock-file --override-input a git+https://"* ]]
}

@test "a remote installable: plain nix develop, named as given, no failover" {
    run bash "$SCRIPT" 'github:o/r#ci' -c true
    [ "$status" -eq 0 ]
    [[ "$output" == *"tier 1"*"github:o/r#ci is not a local flake dir"* ]]
    [[ "$output" == *"develop github:o/r#ci -c true"* ]]
    run ! grep -q '^print-dev-env' "$NIX_LOG"
}

# .claudinix.toml (scripts:T91, scripts:V34): devshell.installable is the
# installable when none is given.

@test "no installable given: devshell.installable from .claudinix.toml, logged" {
    printf '%s\n' 'version = 1' '[devshell]' 'installable = ".#ci"' >"$PROJECT/.claudinix.toml"
    NIX_OK_PLAIN=1 run bash "$SCRIPT" --command true
    [ "$status" -eq 0 ]
    grep -qx 'print-dev-env .#ci' "$NIX_LOG"
    [[ "$output" == *"develop .#ci --command true"* ]]
    [[ "$output" == *".#ci"*".claudinix.toml"* ]]
}

@test "an installable given still wins over .claudinix.toml" {
    printf '%s\n' 'version = 1' '[devshell]' 'installable = ".#ci"' >"$PROJECT/.claudinix.toml"
    NIX_OK_PLAIN=1 run bash "$SCRIPT" '.#other' --command true
    [ "$status" -eq 0 ]
    [[ "$output" == *"develop .#other --command true"* ]]
    run ! grep -q '#ci' "$NIX_LOG"
}

@test "devshell.installable = . is a bare nix develop, as without a file" {
    printf '%s\n' 'version = 1' '[devshell]' 'installable = "."' >"$PROJECT/.claudinix.toml"
    NIX_OK_PLAIN=1 run bash "$SCRIPT" --command true
    [ "$status" -eq 0 ]
    [[ "$output" == *"develop --command true"* ]]
}

# A bad .claudinix.toml never blocks the dev shell (scripts:T98): it
# warns and runs with the defaults; the repo's gate refuses the file.

@test "a bad .claudinix.toml: config's message, a warning, then defaults (scripts:T98)" {
    printf '%s\n' 'version = 1' '[devshell]' 'installable = ".#ci"' 'bogus = 1' >"$PROJECT/.claudinix.toml"
    NIX_OK_PLAIN=1 run bash "$SCRIPT" --command true
    [ "$status" -eq 0 ]
    [[ "$output" == *"config: "*"devshell.bogus"* ]]
    [[ "$output" == *"nix-dev: WARNING: ./.claudinix.toml is invalid -- using defaults (the repo's gate refuses it at commit)"* ]]
    grep -qx 'print-dev-env' "$NIX_LOG"
    [[ "$output" == *"develop --command true"* ]]
    run ! grep -q '#ci' "$NIX_LOG"
    [ "$(grep -c '^eval ' "$NIX_LOG")" -eq 1 ]
}

@test "a .claudinix.toml that is not TOML: warning, defaults, dev shell runs" {
    printf '%s\n' 'this is [not toml' >"$PROJECT/.claudinix.toml"
    NIX_OK_PLAIN=1 run bash "$SCRIPT" --command true
    [ "$status" -eq 0 ]
    [[ "$output" == *"cannot be read as TOML"* ]]
    [[ "$output" == *"nix-dev: WARNING: ./.claudinix.toml is invalid -- using defaults"* ]]
    [[ "$output" == *"develop --command true"* ]]
}

@test "a bad file named by CLAUDINIX_CONFIG: the warning names it as given (V26)" {
    printf '%s\n' 'version = 2' >"$BATS_TEST_TMPDIR/my.toml"
    CLAUDINIX_CONFIG="$BATS_TEST_TMPDIR/my.toml" NIX_OK_PLAIN=1 run bash "$SCRIPT" --command true
    [ "$status" -eq 0 ]
    [[ "$output" == *"nix-dev: WARNING: $BATS_TEST_TMPDIR/my.toml is invalid -- using defaults"* ]]
    [[ "$output" == *"develop --command true"* ]]
}

@test "no .claudinix.toml: no warning, bare develop" {
    NIX_OK_PLAIN=1 run bash "$SCRIPT" --command true
    [ "$status" -eq 0 ]
    [[ "$output" != *"WARNING"* ]]
    [[ "$output" == *"develop --command true"* ]]
    run ! grep -q '^eval ' "$NIX_LOG"
}

@test "config.sh failing otherwise (exit 1): nix-dev exits 1, no dev shell" {
    lib="$BATS_TEST_TMPDIR/lib"
    mkdir -p "$lib"
    for f in nix-dev.sh nix-dev.jq inputs.sh inputs.jq; do
        cp "$BATS_TEST_DIRNAME/../../../scripts/$f" "$lib/"
    done
    printf '%s\n' '#!/usr/bin/env bash' 'echo "config: nix is not on PATH" >&2' 'exit 1' >"$lib/config.sh"
    NIX_OK_PLAIN=1 run bash "$lib/nix-dev.sh" --command true
    [ "$status" -eq 1 ]
    [[ "$output" == *"config: nix is not on PATH"* ]]
    [[ "$output" != *"using defaults"* ]]
    run ! grep -q '^develop' "$NIX_LOG"
}

@test "one nix eval per run: inputs.sh gets the config nix-dev read (scripts:T96)" {
    printf '%s\n' 'version = 1' '[devshell]' 'installable = ".#ci"' >"$PROJECT/.claudinix.toml"
    NIX_OK_PLAIN=1 run bash "$SCRIPT" --command true
    [ "$status" -eq 0 ]
    [[ "$output" == *"develop .#ci --command true"* ]]
    grep -q '^flake archive' "$NIX_LOG"
    [ "$(grep -c '^eval ' "$NIX_LOG")" -eq 1 ]
}

@test "an install without config.sh (older setup): no config, still works" {
    lib="$BATS_TEST_TMPDIR/lib"
    mkdir -p "$lib"
    for f in nix-dev.sh nix-dev.jq inputs.sh inputs.jq; do
        cp "$BATS_TEST_DIRNAME/../../../scripts/$f" "$lib/"
    done
    printf '%s\n' 'version = 1' '[devshell]' 'installable = ".#ci"' >"$PROJECT/.claudinix.toml"
    NIX_OK_PLAIN=1 run bash "$lib/nix-dev.sh" --command true
    [ "$status" -eq 0 ]
    [[ "$output" == *"develop --command true"* ]]
    run ! grep -q '#ci' "$NIX_LOG"
}
