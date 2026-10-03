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
    # each succeed only when the test says so. develop: echoes its args.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$NIX_LOG"' \
        'cmd="$1"; shift' \
        'case "$cmd" in' \
        'develop) echo "develop $*"; exit 0 ;;' \
        'print-dev-env) ;;' \
        '*) exit 9 ;;' \
        'esac' \
        'case "$*" in' \
        '"") ok="$NIX_OK_PLAIN" ;;' \
        '*channels.nixos.org*) ok="$NIX_OK_CHANNEL" ;;' \
        '*git+https*) ok="$NIX_OK_GIT" ;;' \
        '*) ok=0 ;;' \
        'esac' \
        '[ "$ok" = 1 ] && exit 0' \
        'echo "error: unable to download: HTTP error 403" >&2' \
        'exit 1' >"$STUBS/nix"
    chmod +x "$STUBS/nix"
    export PATH="$STUBS:$PATH"
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
    inputs_stub "pr0d1r2/a $A attach" "pr0d1r2/b $B cached" "owner/e $E attach" "NixOS/nixpkgs $N cached"
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
    inputs_stub "pr0d1r2/a $A attach" "pr0d1r2/b $B cached" "owner/e $E cached" "NixOS/nixpkgs $N cached"
    NIX_OK_PLAIN=1 run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(grep -o 'tier [0-9]' <<<"$output" | tail -n 1)" = "tier 3" ]
    [[ "$output" == *"warning"* ]]
    [[ "$(grep '^develop ' <<<"$output")" != *"--override-input"* ]]
}

@test "auto: only nixpkgs uncached, nothing for tier 2 to override" {
    inputs_stub "pr0d1r2/a $A cached" "pr0d1r2/b $B cached" "owner/e $E cached" "NixOS/nixpkgs $N attach"
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
