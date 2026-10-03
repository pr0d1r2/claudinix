#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for setup.sh and the env files beside it (SPEC T2, V1-V4,
# V6, V7). Imported from the owner's private seed repo at 476cf1d
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
    export CLAUDINIX_LIB_DIR="$BATS_TEST_TMPDIR/lib/claudinix"
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

    # timeout: logs the limit and the command, then runs it; a command
    # whose words include $TIMEOUT_EXPIRE "times out" (124) without running.
    export TIMEOUT_LOG="$BATS_TEST_TMPDIR/timeout.log"
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$TIMEOUT_LOG"' \
        'if [ -n "${TIMEOUT_EXPIRE:-}" ] && [[ " $* " == *" $TIMEOUT_EXPIRE "* ]]; then exit 124; fi' \
        'shift' \
        'exec "$@"' >"$BATS_TEST_TMPDIR/stubs/timeout"
    chmod +x "$BATS_TEST_TMPDIR/stubs/timeout"
    export PATH="$BATS_TEST_TMPDIR/stubs:$PATH"
}

# The options every Nix network operation carries (T88, V5).
NIX_NET='--option connect-timeout 10 --option stalled-download-timeout 30'

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

@test "base allowlist is Nix hosts only: crates.io comes from domains (T30)" {
    run ! grep -qx 'index.crates.io' "$ENV_DIR/allowlist.txt"
    run ! grep -qx 'static.crates.io' "$ENV_DIR/allowlist.txt"
    while IFS= read -r host; do
        case "$host" in
        '' | '#'*) ;;
        pr0d1r2.cachix.org | cache.nixos.org | channels.nixos.org | releases.nixos.org | github.com) ;;
        *)
            echo "not a Nix host: $host"
            return 1
            ;;
        esac
    done <"$ENV_DIR/allowlist.txt"
}

@test "env vars leave out ANTHROPIC_MODEL: it does not choose the session model" {
    run ! grep -q '^ANTHROPIC_MODEL=' "$ENV_DIR/env-names.txt"
}

@test "env vars offer BASH_DEFAULT_TIMEOUT_MS=600000, marked optional (T48, V24)" {
    grep -qx 'BASH_DEFAULT_TIMEOUT_MS=600000' "$ENV_DIR/env-names.txt"
    # The comment block right above the line says it is optional.
    above="$(awk '/^#/ { blk = blk $0 "\n"; next } /^BASH_DEFAULT_TIMEOUT_MS=/ { printf "%s", blk; exit } { blk = "" }' "$ENV_DIR/env-names.txt")"
    grep -q '^# Optional' <<<"$above"
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
    [ "$(grep -c '^# BEGIN claudinix' "$conf")" -eq 1 ]
    [ "$(grep -c '^# END claudinix' "$conf")" -eq 1 ]
}

@test "nix.conf: a stale managed block is replaced whole on re-run (V3, B2)" {
    mkdir -p "$NIX_CONF_DIR"
    printf '%s\n' 'build-users-group = nixbld' \
        '# BEGIN claudinix (SPEC V3)' \
        'extra-substituters = https://old.example' \
        '# END claudinix (SPEC V3)' \
        'max-jobs = 4' >"$NIX_CONF_DIR/nix.conf"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    conf="$NIX_CONF_DIR/nix.conf"
    run ! grep -q 'old.example' "$conf"
    grep -qx 'accept-flake-config = true' "$conf"
    grep -qx 'build-users-group = nixbld' "$conf"
    grep -qx 'max-jobs = 4' "$conf"
    [ "$(grep -c '^# BEGIN claudinix' "$conf")" -eq 1 ]
}

# An image-shipped nix in the default profile, as probe 1 found it (C4, C8).
image_nix() {
    mkdir -p "$NIX_DEFAULT_PROFILE/bin"
    printf '#!/bin/sh\necho "nix (Nix) %s"\n' "$1" >"$NIX_DEFAULT_PROFILE/bin/nix"
    chmod +x "$NIX_DEFAULT_PROFILE/bin/nix"
}

@test "image nix at or above the floor: no install, linked and used (V4)" {
    image_nix 2.34.6
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ ! -e "$INSTALLER_LOG" ]
    [[ "$output" == *"nix (Nix) 2.34.6"* ]]
    [ "$("$BIN_DIR/nix" --version)" = "nix (Nix) 2.34.6" ]
}

@test "image nix below the floor: pinned install wins the PATH dir (V4)" {
    image_nix 2.18.1
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(cat "$INSTALLER_LOG")" = "--no-daemon --yes" ]
    [ "$("$BIN_DIR/nix" --version)" = "nix (Nix) 2.35.2" ]
}

@test "NIX_MIN_VERSION seam raises the floor (C4)" {
    image_nix 2.34.6
    NIX_MIN_VERSION=2.40 run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(cat "$INSTALLER_LOG")" = "--no-daemon --yes" ]
}

# The agent home tail (T17, nix:V14, nix:V15). Image nix at the floor, so
# no install; stub `nix` builds (or refuses) the activation package and
# stub `nix-store` realises (or refuses) the recorded path.
agent_home() {
    image_nix 2.34.6
    export HOME_PKG="$BATS_TEST_TMPDIR/activation"
    export ACTIVATE_LOG="$BATS_TEST_TMPDIR/activate.log"
    export NIX_LOG="$BATS_TEST_TMPDIR/nix.log"
    export BUILD_OK=1 STORE_OK=1 ACTIVATE_OK=1
    export CLOUD_HOME_STOREPATH="$BATS_TEST_TMPDIR/cloud-home.storepath"
    export CLOUD_HOME_MARKER="$BATS_TEST_TMPDIR/state/agent-home.failed"
    mkdir -p "$HOME_PKG"
    cat >"$HOME_PKG/activate" <<'EOF'
#!/usr/bin/env bash
echo "HOME=$HOME USER=$USER" >>"$ACTIVATE_LOG"
[ "$ACTIVATE_OK" = 1 ]
EOF
    cat >"$NIX_DEFAULT_PROFILE/bin/nix" <<'EOF'
#!/usr/bin/env bash
case "$1" in
--version) echo "nix (Nix) 2.34.6" ;;
build)
    echo "nix $*" >>"$NIX_LOG"
    [ "$BUILD_OK" = 1 ] || exit 1
    echo "$HOME_PKG"
    ;;
esac
EOF
    cat >"$NIX_DEFAULT_PROFILE/bin/nix-store" <<'EOF'
#!/usr/bin/env bash
echo "nix-store $*" >>"$NIX_LOG"
[ "$STORE_OK" = 1 ]
EOF
    chmod +x "$HOME_PKG/activate" "$NIX_DEFAULT_PROFILE/bin/nix" "$NIX_DEFAULT_PROFILE/bin/nix-store"
}

@test "agent home: tier 1 builds the flake over git+https and activates (nix:V15)" {
    agent_home
    run bash "$SCRIPT" --agent-home
    [ "$status" -eq 0 ]
    [[ "$output" == *"tier 1"* ]]
    grep -q 'build .*git+https://github.com/pr0d1r2/claudinix.*#homeConfigurations.cloud.activationPackage' "$NIX_LOG"
    run ! grep -q 'github:' "$NIX_LOG"
    [ -s "$ACTIVATE_LOG" ]
    [ ! -e "$CLOUD_HOME_MARKER" ]
}

@test "agent home: CLOUD_HOME_FLAKE seam picks the flake" {
    agent_home
    CLOUD_HOME_FLAKE="path:/tmp/elsewhere" run bash "$SCRIPT" --agent-home
    [ "$status" -eq 0 ]
    grep -q 'build .*path:/tmp/elsewhere#homeConfigurations.cloud.activationPackage' "$NIX_LOG"
}

@test "agent home: activates as the setup's user and HOME (nix:V14)" {
    agent_home
    run bash "$SCRIPT" --agent-home
    [ "$status" -eq 0 ]
    [ "$(cat "$ACTIVATE_LOG")" = "HOME=$HOME USER=$USER" ]
}

@test "agent home: tier 1 fails, tier 2 realises the recorded path (nix:V15)" {
    agent_home
    echo "$HOME_PKG" >"$CLOUD_HOME_STOREPATH"
    BUILD_OK=0 run bash "$SCRIPT" --agent-home
    [ "$status" -eq 0 ]
    [[ "$output" == *"tier 2"* ]]
    grep -qx "nix-store -r $NIX_NET $HOME_PKG" "$NIX_LOG"
    [ -s "$ACTIVATE_LOG" ]
    [ ! -e "$CLOUD_HOME_MARKER" ]
}

@test "agent home: both tiers fail, nix stays usable, loud warning and marker" {
    agent_home
    echo "$HOME_PKG" >"$CLOUD_HOME_STOREPATH"
    BUILD_OK=0 STORE_OK=0 run bash "$SCRIPT" --agent-home
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]]
    [ -e "$CLOUD_HOME_MARKER" ]
    [ ! -e "$ACTIVATE_LOG" ]
    [ "$("$BIN_DIR/nix" --version)" = "nix (Nix) 2.34.6" ]
}

@test "agent home: no recorded path and tier 1 fails: warning and marker" {
    agent_home
    BUILD_OK=0 run bash "$SCRIPT" --agent-home
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]]
    [ -e "$CLOUD_HOME_MARKER" ]
    run ! grep -q 'nix-store' "$NIX_LOG"
}

@test "agent home: activation itself fails: warning and marker, exit 0" {
    agent_home
    ACTIVATE_OK=0 run bash "$SCRIPT" --agent-home
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]]
    [ -e "$CLOUD_HOME_MARKER" ]
}

@test "agent home: the default marker lives under ~/.local/state/claudinix (T71)" {
    agent_home
    unset CLOUD_HOME_MARKER
    BUILD_OK=0 run bash "$SCRIPT" --agent-home
    [ "$status" -eq 0 ]
    [ -e "$HOME/.local/state/claudinix/agent-home.failed" ]
}

@test "nix-dev: the default lib dir is /usr/local/lib/claudinix (T71)" {
    grep -qF ':-/usr/local/lib/claudinix}' "$SCRIPT"
}

SHA=0123456789abcdef0123456789abcdef01234567

@test "sha arg: tier 1 builds that exact rev over git+https (V20)" {
    agent_home
    run bash "$SCRIPT" "$SHA" --agent-home
    [ "$status" -eq 0 ]
    grep -qF "git+https://github.com/pr0d1r2/claudinix?rev=$SHA&shallow=1#homeConfigurations.cloud.activationPackage" "$NIX_LOG"
}

@test "sha arg not a full commit id: usage error before anything runs (V20)" {
    agent_home
    run bash "$SCRIPT" abc123
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
    [ ! -e "$NIX_CONF_DIR/nix.conf" ]
    [ ! -e "$NIX_LOG" ]
}

@test "sha arg, no recorded path beside the script: fetched at that sha (V20)" {
    agent_home
    export CURL_LOG="$BATS_TEST_TMPDIR/curl.log"
    cat >"$BATS_TEST_TMPDIR/stubs/curl" <<'EOF'
#!/bin/sh
while [ $# -gt 0 ]; do
    case "$1" in -o) out="$2" ;; https://*) url="$1" ;; esac
    shift
done
echo "$url" >>"$CURL_LOG"
echo "$HOME_PKG" >"$out"
EOF
    chmod +x "$BATS_TEST_TMPDIR/stubs/curl"
    BUILD_OK=0 run bash "$SCRIPT" "$SHA" --agent-home
    [ "$status" -eq 0 ]
    [[ "$output" == *"tier 2"* ]]
    grep -qx "https://raw.githubusercontent.com/pr0d1r2/claudinix/$SHA/cloud-home.storepath" "$CURL_LOG"
    grep -qx "nix-store -r $NIX_NET $HOME_PKG" "$NIX_LOG"
}

@test "agent home: a success clears an earlier failure marker" {
    agent_home
    mkdir -p "$(dirname "$CLOUD_HOME_MARKER")"
    touch "$CLOUD_HOME_MARKER"
    run bash "$SCRIPT" --agent-home
    [ "$status" -eq 0 ]
    [ ! -e "$CLOUD_HOME_MARKER" ]
}

# A fetcher for nix-dev's files: logs each URL, writes a placeholder, or
# fails when FETCH_FAIL is set. Ahead of the installer stub on PATH.
fetch_stub() {
    export FETCH_LOG="$BATS_TEST_TMPDIR/fetch.log"
    export FETCH_ARGS="$BATS_TEST_TMPDIR/fetch.args"
    mkdir -p "$BATS_TEST_TMPDIR/fetch"
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/bin/sh' 'url=' 'out=' \
        'echo "$*" >>"$FETCH_ARGS"' \
        'while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift ;; --connect-timeout | --max-time) shift ;; -*) ;; *) url="$1" ;; esac; shift; done' \
        'echo "$url" >>"$FETCH_LOG"' \
        '[ -z "${FETCH_FAIL:-}" ] || exit 22' \
        'case "$url" in *"/${FETCH_FAIL_ON:-/}") exit 22 ;; esac' \
        'echo "# fetched $url" >"$out"' >"$BATS_TEST_TMPDIR/fetch/curl"
    chmod +x "$BATS_TEST_TMPDIR/fetch/curl"
    PATH="$BATS_TEST_TMPDIR/fetch:$PATH"
}

@test "nix-dev installed from the clone beside setup.sh, linked onto PATH (scripts:T12)" {
    image_nix 2.34.6
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -x "$BIN_DIR/nix-dev" ]
    cmp "$CLAUDINIX_LIB_DIR/nix-dev.sh" "$ENV_DIR/scripts/nix-dev.sh"
    cmp "$CLAUDINIX_LIB_DIR/nix-dev.jq" "$ENV_DIR/scripts/nix-dev.jq"
    [ "$(readlink "$BIN_DIR/nix-dev")" = "$CLAUDINIX_LIB_DIR/nix-dev.sh" ]
}

@test "setup.sh alone with a SHA: nix-dev fetched at that SHA, not main (T69, V20)" {
    image_nix 2.34.6
    fetch_stub
    cp "$SCRIPT" "$BATS_TEST_TMPDIR/setup.sh"
    run bash "$BATS_TEST_TMPDIR/setup.sh" "$SHA"
    [ "$status" -eq 0 ]
    grep -qx "https://raw.githubusercontent.com/pr0d1r2/claudinix/$SHA/scripts/nix-dev.sh" "$FETCH_LOG"
    grep -qx "https://raw.githubusercontent.com/pr0d1r2/claudinix/$SHA/scripts/nix-dev.jq" "$FETCH_LOG"
    run ! grep -q '/main/' "$FETCH_LOG"
    [ -x "$BIN_DIR/nix-dev" ]
}

@test "setup.sh alone without a SHA: nix-dev fetched from main (T69)" {
    image_nix 2.34.6
    fetch_stub
    cp "$SCRIPT" "$BATS_TEST_TMPDIR/setup.sh"
    run bash "$BATS_TEST_TMPDIR/setup.sh"
    [ "$status" -eq 0 ]
    grep -qx 'https://raw.githubusercontent.com/pr0d1r2/claudinix/main/scripts/nix-dev.sh' "$FETCH_LOG"
    [ -x "$BIN_DIR/nix-dev" ]
}

@test "CLAUDINIX_REV seam still picks the revision nix-dev is fetched at" {
    image_nix 2.34.6
    fetch_stub
    cp "$SCRIPT" "$BATS_TEST_TMPDIR/setup.sh"
    CLAUDINIX_REV=abc123 run bash "$BATS_TEST_TMPDIR/setup.sh" "$SHA"
    [ "$status" -eq 0 ]
    grep -qx 'https://raw.githubusercontent.com/pr0d1r2/claudinix/abc123/scripts/nix-dev.sh' "$FETCH_LOG"
}

@test "nix-dev's cache check (inputs.sh, inputs.jq) lands beside it (scripts:T49)" {
    image_nix 2.34.6
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    cmp "$CLAUDINIX_LIB_DIR/inputs.sh" "$ENV_DIR/scripts/inputs.sh"
    cmp "$CLAUDINIX_LIB_DIR/inputs.jq" "$ENV_DIR/scripts/inputs.jq"
    fetch_stub
    cp "$SCRIPT" "$BATS_TEST_TMPDIR/setup.sh"
    CLAUDINIX_REV=abc123 run bash "$BATS_TEST_TMPDIR/setup.sh"
    grep -qx 'https://raw.githubusercontent.com/pr0d1r2/claudinix/abc123/scripts/inputs.sh' "$FETCH_LOG"
    grep -qx 'https://raw.githubusercontent.com/pr0d1r2/claudinix/abc123/scripts/inputs.jq' "$FETCH_LOG"
}

@test "nix-dev fetch failing: setup still passes with nix, warns, links no nix-dev (V1)" {
    image_nix 2.34.6
    fetch_stub
    cp "$SCRIPT" "$BATS_TEST_TMPDIR/setup.sh"
    FETCH_FAIL=1 run bash "$BATS_TEST_TMPDIR/setup.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"nix-dev"* ]]
    [ -x "$BIN_DIR/nix" ]
    [ ! -e "$BIN_DIR/nix-dev" ]
}

# The fork config block (C11, T68): the owner's values live only between
# its markers, so a fork edits that block and nothing else.
OWNER_KEY='pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM='

@test "fork config: owner values appear in setup.sh only inside the block (C11)" {
    grep -qx '# BEGIN fork config (SPEC C11)' "$SCRIPT"
    grep -qx '# END fork config (SPEC C11)' "$SCRIPT"
    outside="$(sed '/^# BEGIN fork config/,/^# END fork config/d' "$SCRIPT")"
    run ! grep -n 'pr0d1r2' <<<"$outside"
    inside="$(sed -n '/^# BEGIN fork config/,/^# END fork config/p' "$SCRIPT")"
    grep -qF 'pr0d1r2.cachix.org' <<<"$inside"
    grep -qF "$OWNER_KEY" <<<"$inside"
    grep -qF 'pr0d1r2/claudinix' <<<"$inside"
}

@test "fork config: editing only the block retargets the cache and the repo (C11, T68)" {
    agent_home
    fetch_stub
    mkdir -p "$BATS_TEST_TMPDIR/fork"
    sed -e '/^# BEGIN fork config/,/^# END fork config/{' \
        -e "s|$OWNER_KEY|fork.cachix.org-1:Zm9yaw==|" \
        -e 's|pr0d1r2\.cachix\.org|fork.cachix.org|' \
        -e 's|pr0d1r2/claudinix|forker/claudinix|' \
        -e '}' "$SCRIPT" >"$BATS_TEST_TMPDIR/fork/setup.sh"
    BUILD_OK=0 run bash "$BATS_TEST_TMPDIR/fork/setup.sh" "$SHA" --agent-home
    [ "$status" -eq 0 ]
    conf="$NIX_CONF_DIR/nix.conf"
    grep -qx 'extra-substituters = https://fork.cachix.org' "$conf"
    grep -qx 'extra-trusted-public-keys = fork.cachix.org-1:Zm9yaw==' "$conf"
    grep -qx "https://raw.githubusercontent.com/forker/claudinix/$SHA/scripts/nix-dev.sh" "$FETCH_LOG"
    grep -qx "https://raw.githubusercontent.com/forker/claudinix/$SHA/cloud-home.storepath" "$FETCH_LOG"
    grep -qF "git+https://github.com/forker/claudinix?rev=$SHA&shallow=1#" "$NIX_LOG"
    run ! grep -r 'pr0d1r2' "$conf" "$FETCH_LOG" "$NIX_LOG"
}

# The agent home is opt-in (C24, T73): the default setup is Nix and
# nix-dev only, and says in one line how to ask for the agent home.

@test "agent home off by default: nothing built, one line says how to enable it (C24)" {
    agent_home
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ ! -e "$NIX_LOG" ]
    [ ! -e "$ACTIVATE_LOG" ]
    [ ! -e "$CLOUD_HOME_MARKER" ]
    [ "$(grep -c 'agent home' <<<"$output")" -eq 1 ]
    [[ "$output" == *"--agent-home"* ]]
    [[ "$output" == *"CLAUDINIX_AGENT_HOME=1"* ]]
    run ! grep -q 'WARNING' <<<"$output"
}

@test "agent home: --agent-home may come before the SHA (C24)" {
    agent_home
    run bash "$SCRIPT" --agent-home "$SHA"
    [ "$status" -eq 0 ]
    grep -qF "git+https://github.com/pr0d1r2/claudinix?rev=$SHA&shallow=1#homeConfigurations.cloud.activationPackage" "$NIX_LOG"
    [ -s "$ACTIVATE_LOG" ]
}

@test "agent home: CLAUDINIX_AGENT_HOME=1 opts in without the flag (C24)" {
    agent_home
    CLAUDINIX_AGENT_HOME=1 run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"tier 1"* ]]
    [ -s "$ACTIVATE_LOG" ]
}

@test "agent home: CLAUDINIX_AGENT_HOME=0 keeps it off (C24)" {
    agent_home
    CLAUDINIX_AGENT_HOME=0 run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ ! -e "$NIX_LOG" ]
}

@test "an unknown argument is a usage error naming --agent-home, nothing touched" {
    agent_home
    run bash "$SCRIPT" --frobnicate
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
    [[ "$output" == *"--agent-home"* ]]
    [ ! -e "$NIX_CONF_DIR/nix.conf" ]
    [ ! -e "$NIX_LOG" ]
}

@test "two SHAs are a usage error (V20)" {
    run bash "$SCRIPT" "$SHA" "$SHA"
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
    [ ! -e "$NIX_CONF_DIR/nix.conf" ]
}

# nix-dev's files land together or not at all (T73): a half-fetched set
# would link a nix-dev that cannot find its jq program.

@test "nix-dev: one file failing replaces nothing, removes a stale link, warns (T73)" {
    image_nix 2.34.6
    fetch_stub
    cp "$SCRIPT" "$BATS_TEST_TMPDIR/setup.sh"
    mkdir -p "$CLAUDINIX_LIB_DIR"
    echo old >"$CLAUDINIX_LIB_DIR/nix-dev.sh"
    ln -s "$CLAUDINIX_LIB_DIR/nix-dev.sh" "$BIN_DIR/nix-dev"
    FETCH_FAIL_ON=inputs.jq run bash "$BATS_TEST_TMPDIR/setup.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"nix-dev"* ]]
    [ "$(cat "$CLAUDINIX_LIB_DIR/nix-dev.sh")" = old ]
    [ ! -e "$CLAUDINIX_LIB_DIR/nix-dev.jq" ]
    [ ! -L "$BIN_DIR/nix-dev" ]
    [ -x "$BIN_DIR/nix" ]
}

@test "every curl in setup.sh is bounded: --connect-timeout and --max-time (T73)" {
    calls="$(grep -v '^[[:space:]]*#' "$SCRIPT" | grep -E '(^|[^-[:alnum:]])curl ')"
    [ -n "$calls" ]
    while IFS= read -r line; do
        [[ "$line" == *"--connect-timeout"* ]] || {
            echo "unbounded: $line"
            return 1
        }
        [[ "$line" == *"--max-time"* ]] || {
            echo "unbounded: $line"
            return 1
        }
    done <<<"$calls"
}

@test "nix-dev fetch passes the timeouts to curl (T73)" {
    image_nix 2.34.6
    fetch_stub
    cp "$SCRIPT" "$BATS_TEST_TMPDIR/setup.sh"
    run bash "$BATS_TEST_TMPDIR/setup.sh"
    [ "$status" -eq 0 ]
    [ "$(grep -c -- '--connect-timeout' "$FETCH_ARGS")" -eq 4 ]
    [ "$(grep -c -- '--max-time' "$FETCH_ARGS")" -eq 4 ]
}

@test "script read from stdin: never copies nix-dev from the cwd, fetches it (T73)" {
    image_nix 2.34.6
    fetch_stub
    mkdir -p "$BATS_TEST_TMPDIR/cwd/scripts"
    for f in nix-dev.sh nix-dev.jq inputs.sh inputs.jq; do
        echo "# cwd copy" >"$BATS_TEST_TMPDIR/cwd/scripts/$f"
    done
    # shellcheck disable=SC2016 # $1 expands in the inner shell
    run bash -c 'cd "$1" && bash -s' _ "$BATS_TEST_TMPDIR/cwd" <"$SCRIPT"
    [ "$status" -eq 0 ]
    grep -qx 'https://raw.githubusercontent.com/pr0d1r2/claudinix/main/scripts/nix-dev.sh' "$FETCH_LOG"
    run ! grep -q 'cwd copy' "$CLAUDINIX_LIB_DIR/nix-dev.sh"
}

# After an install, the nix Claude's Bash tool finds first is the default
# profile's (C8): warn when that one is still below the floor (V1, V4).

@test "install leaves an old nix first on Claude's PATH: warns (T73, V4)" {
    image_nix 2.18.1
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]]
    [[ "$output" == *"2.18.1"* ]]
    [[ "$output" == *"$NIX_DEFAULT_PROFILE/bin"* ]]
}

@test "install that upgrades the default profile: no floor warning (T73, V4)" {
    mkdir -p "$BATS_TEST_TMPDIR/systemd"
    image_nix 2.18.1
    SYSTEMD_DIR="$BATS_TEST_TMPDIR/systemd" run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    run ! grep -q 'WARNING' <<<"$output"
}

# Every Nix network operation is bounded (T88, V5): a stalled substituter
# or installer must not eat the ~5 min the snapshot is cached within.

@test "installer runs under timeout, its limit from CLAUDINIX_NIX_TIMEOUT (T88, V5)" {
    CLAUDINIX_NIX_TIMEOUT=7 run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    grep -qE '^7 sh .*/install --no-daemon --yes$' "$TIMEOUT_LOG"
}

@test "installer timeout has a default limit in seconds (T88, V5)" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    grep -qE '^[1-9][0-9]* sh .*/install --no-daemon --yes$' "$TIMEOUT_LOG"
}

@test "installer timing out fails setup before nix.conf is written (T88, V5)" {
    TIMEOUT_EXPIRE=--no-daemon run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [ ! -e "$INSTALLER_LOG" ]
    [ ! -e "$NIX_CONF_DIR/nix.conf" ]
}

@test "tier 1 build: bounded connect and stall, under timeout (T88, nix:V15)" {
    agent_home
    CLAUDINIX_NIX_TIMEOUT=9 run bash "$SCRIPT" --agent-home
    [ "$status" -eq 0 ]
    grep -qF "nix build $NIX_NET --no-link --print-out-paths " "$NIX_LOG"
    grep -qE "^9 .*/nix build " "$TIMEOUT_LOG"
}

@test "tier 2 realise: bounded connect and stall, under timeout (T88, nix:V15)" {
    agent_home
    echo "$HOME_PKG" >"$CLOUD_HOME_STOREPATH"
    BUILD_OK=0 CLAUDINIX_NIX_TIMEOUT=9 run bash "$SCRIPT" --agent-home
    [ "$status" -eq 0 ]
    grep -qx "nix-store -r $NIX_NET $HOME_PKG" "$NIX_LOG"
    grep -qE "^9 .*/nix-store -r " "$TIMEOUT_LOG"
}

@test "tier 1 timing out falls over to tier 2 (T88, nix:V15)" {
    agent_home
    echo "$HOME_PKG" >"$CLOUD_HOME_STOREPATH"
    TIMEOUT_EXPIRE=build run bash "$SCRIPT" --agent-home
    [ "$status" -eq 0 ]
    [[ "$output" == *"tier 2"* ]]
    [ -s "$ACTIVATE_LOG" ]
}

@test "both tiers timing out: Nix usable, warning and marker, exit 0 (T88, V1)" {
    agent_home
    echo "$HOME_PKG" >"$CLOUD_HOME_STOREPATH"
    TIMEOUT_EXPIRE=--option run bash "$SCRIPT" --agent-home
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]]
    [ -e "$CLOUD_HOME_MARKER" ]
}

@test "CLAUDINIX_NIX_TIMEOUT not a positive integer: usage error, nothing touched (T88)" {
    CLAUDINIX_NIX_TIMEOUT=soon run bash "$SCRIPT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"CLAUDINIX_NIX_TIMEOUT"* ]]
    [ ! -e "$NIX_CONF_DIR/nix.conf" ]
}

# CLAUDINIX_AGENT_HOME is 0 or 1 (T88, C24): any other value is a typo
# that would silently drop the agent home, so it is refused like a flag.

@test "CLAUDINIX_AGENT_HOME other than 0 or 1: usage error, nothing touched (T88, C24)" {
    agent_home
    for value in yes true 2 on; do
        CLAUDINIX_AGENT_HOME="$value" run bash "$SCRIPT"
        [ "$status" -eq 2 ]
        [[ "$output" == *"usage"* ]]
        [[ "$output" == *"CLAUDINIX_AGENT_HOME"* ]]
        [ ! -e "$NIX_CONF_DIR/nix.conf" ]
        [ ! -e "$NIX_LOG" ]
    done
}

@test "CLAUDINIX_AGENT_HOME empty counts as unset: agent home off (T88, C24)" {
    agent_home
    CLAUDINIX_AGENT_HOME='' run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ ! -e "$NIX_LOG" ]
}
