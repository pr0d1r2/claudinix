#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for setup.sh and the env files beside it (SPEC T2, V1-V4,
# V6, V7). Imported from the the owner's private seed repo seed at 476cf1d
# (cloud/envs/nix/), paths moved to the repo root.

setup() {
    ENV_DIR="$BATS_TEST_DIRNAME/../.."
    SCRIPT="$ENV_DIR/setup.sh"
    export HOME="$BATS_TEST_TMPDIR/home"
    export NIX_CONF_DIR="$BATS_TEST_TMPDIR/etc/nix"
    export BIN_DIR="$BATS_TEST_TMPDIR/bin"
    export SYSTEMD_DIR="$BATS_TEST_TMPDIR/no-systemd"
    export NIX_DEFAULT_PROFILE="$BATS_TEST_TMPDIR/profiles/default"
    export INSTALLER_LOG="$BATS_TEST_TMPDIR/installer.args"
    mkdir -p "$HOME" "$BIN_DIR" "$BATS_TEST_TMPDIR/stubs"

    # Fake upstream installer: logs its args, lays down a nix binary where
    # the real one would (per-user profile, or the default profile in daemon mode).
    FAKE_INSTALLER="$BATS_TEST_TMPDIR/install"
    cat >"$FAKE_INSTALLER" <<'EOF'
echo "$@" >>"$INSTALLER_LOG"
case " $* " in *" --daemon "*) bin="$NIX_DEFAULT_PROFILE/bin" ;; *) bin="$HOME/.nix-profile/bin" ;; esac
mkdir -p "$bin"
printf '#!/bin/sh\necho "nix (Nix) 2.35.2"\n' >"$bin/nix"
chmod +x "$bin/nix"
EOF
    export FAKE_INSTALLER
    NIX_INSTALL_SHA256=$(sha256sum "$FAKE_INSTALLER" | cut -d' ' -f1)
    export NIX_INSTALL_SHA256

    cat >"$BATS_TEST_TMPDIR/stubs/curl" <<'EOF'
#!/bin/sh
while [ $# -gt 0 ]; do [ "$1" = -o ] && out="$2"; shift; done
cp "$FAKE_INSTALLER" "$out"
EOF
    chmod +x "$BATS_TEST_TMPDIR/stubs/curl"
    export PATH="$BATS_TEST_TMPDIR/stubs:$PATH"
}

@test "no systemd: single-user install, non-interactive" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(cat "$INSTALLER_LOG")" = "--no-daemon --yes" ]
}

@test "systemd present: multi-user daemon install" {
    export SYSTEMD_DIR="$BATS_TEST_TMPDIR/systemd" && mkdir -p "$SYSTEMD_DIR"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(cat "$INSTALLER_LOG")" = "--daemon --yes" ]
    [ -x "$BIN_DIR/nix" ]
}

@test "installer hash mismatch: abort before running it" {
    NIX_INSTALL_SHA256=0000000000000000000000000000000000000000000000000000000000000000 run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [ ! -e "$INSTALLER_LOG" ]
}

@test "nix.conf: flakes on, owner cachix as substituter with its key" {
    run bash "$SCRIPT"
    conf="$NIX_CONF_DIR/nix.conf"
    grep -qx 'experimental-features = nix-command flakes' "$conf"
    grep -qx 'extra-substituters = https://pr0d1r2.cachix.org' "$conf"
    grep -qx 'extra-trusted-public-keys = pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=' "$conf"
}

@test "nix.conf: trusts flake nixConfig caches (probe 2026-10-03)" {
    run bash "$SCRIPT"
    grep -qx 'accept-flake-config = true' "$NIX_CONF_DIR/nix.conf"
}

@test "nix.conf: keeps what the installer wrote" {
    mkdir -p "$NIX_CONF_DIR" && echo 'build-users-group = nixbld' >"$NIX_CONF_DIR/nix.conf"
    run bash "$SCRIPT"
    grep -qx 'build-users-group = nixbld' "$NIX_CONF_DIR/nix.conf"
}

@test "re-run: no second install, no duplicate config" {
    bash "$SCRIPT"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(wc -l <"$INSTALLER_LOG")" -eq 1 ]
    [ "$(grep -c '^extra-substituters' "$NIX_CONF_DIR/nix.conf")" -eq 1 ]
}

@test "nix linked onto a PATH dir every shell sees, and smoke-tested" {
    run bash "$SCRIPT"
    [ -x "$BIN_DIR/nix" ]
    [[ "$output" == *"nix (Nix) 2.35.2"* ]]
}

@test "cachix is read-only: no push token in the env files (V6)" {
    run ! grep -q 'CACHIX_AUTH_TOKEN' "$ENV_DIR/setup.sh" "$ENV_DIR/allowlist.txt" "$ENV_DIR/env-names.txt"
}

@test "allowlist adds owner cachix on top of the default list" {
    grep -qx 'pr0d1r2.cachix.org' "$ENV_DIR/allowlist.txt"
}

@test "allowlist names nixos.org hosts the proxy refused (probe 2026-10-03)" {
    grep -qx 'cache.nixos.org' "$ENV_DIR/allowlist.txt"
    grep -qx 'channels.nixos.org' "$ENV_DIR/allowlist.txt"
    grep -qx 'releases.nixos.org' "$ENV_DIR/allowlist.txt"
}

@test "allowlist names crates.io hosts cargo needs (probe 4, 2026-10-03)" {
    grep -qx 'index.crates.io' "$ENV_DIR/allowlist.txt"
    grep -qx 'static.crates.io' "$ENV_DIR/allowlist.txt"
}

@test "env vars keep ANTHROPIC_MODEL, marked as not choosing the model (probe 6)" {
    grep -qx 'ANTHROPIC_MODEL=claude-sonnet-5-5' "$ENV_DIR/env-names.txt"
    grep -q 'Does NOT choose the session model' "$ENV_DIR/env-names.txt"
}

@test "env vars carry no secret-looking values (V6)" {
    run ! grep -E -i '(TOKEN|SECRET|KEY|PASSWORD)=' "$ENV_DIR/env-names.txt"
}

@test "allowlist names github.com for third-party git reads (sherd #97, 2026-10-03)" {
    grep -qx 'github.com' "$ENV_DIR/allowlist.txt"
}

@test "env files sit at the repo root (SPEC I.file)" {
    [ -f "$ENV_DIR/setup.sh" ]
    [ -f "$ENV_DIR/allowlist.txt" ]
    [ -f "$ENV_DIR/env-names.txt" ]
}

@test "nix.conf: managed block sits between begin and end markers (V3)" {
    run bash "$SCRIPT"
    conf="$NIX_CONF_DIR/nix.conf"
    [ "$(grep -c '^# BEGIN nix-claude-code-cloud' "$conf")" -eq 1 ]
    [ "$(grep -c '^# END nix-claude-code-cloud' "$conf")" -eq 1 ]
}

@test "nix.conf: a stale managed block is replaced whole on re-run (V3, B2)" {
    mkdir -p "$NIX_CONF_DIR"
    printf '%s\n' 'build-users-group = nixbld' \
        '# BEGIN nix-claude-code-cloud (SPEC V3)' \
        'extra-substituters = https://old.example' \
        '# END nix-claude-code-cloud (SPEC V3)' \
        'max-jobs = 4' >"$NIX_CONF_DIR/nix.conf"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    conf="$NIX_CONF_DIR/nix.conf"
    run ! grep -q 'old.example' "$conf"
    grep -qx 'accept-flake-config = true' "$conf"
    grep -qx 'build-users-group = nixbld' "$conf"
    grep -qx 'max-jobs = 4' "$conf"
    [ "$(grep -c '^# BEGIN nix-claude-code-cloud' "$conf")" -eq 1 ]
}
