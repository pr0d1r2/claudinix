#!/usr/bin/env bash
# Setup script for the Claude Code cloud environment (SPEC T2, I.file,
# I.ext.env). Imported from the the owner's private seed repo seed at 476cf1d
# (cloud/envs/nix/setup.sh). Runs as root on
# Ubuntu 24.04 before Claude Code starts; the result is cached as a
# filesystem snapshot when it ends within ~5 min, and skipped after that.
# Installs pinned upstream Nix (installer hash-checked; it checks its own
# tarball), flakes on, owner cachix as a read-only substituter (V6).
# Git hooks are not installed here (V7): each session is a fresh clone and
# this script does not run on a cached snapshot, so the target repo's
# devShell installs them.
# Usage: setup.sh
# Seams: NIX_CONF_DIR, BIN_DIR, SYSTEMD_DIR, NIX_DEFAULT_PROFILE,
#        NIX_INSTALL_URL, NIX_INSTALL_SHA256.

set -euo pipefail

version=2.35.2
min_version="${NIX_MIN_VERSION:-2.34}"
url="${NIX_INSTALL_URL:-https://releases.nixos.org/nix/nix-$version/install}"
sha256="${NIX_INSTALL_SHA256:-9adda97297d9e8ab360df95c729eabff4f4f93d6db091953c3a68f29e3fb130c}"
conf_dir="${NIX_CONF_DIR:-/etc/nix}"
bin_dir="${BIN_DIR:-/usr/local/bin}"
systemd_dir="${SYSTEMD_DIR:-/run/systemd/system}"
default_profile="${NIX_DEFAULT_PROFILE:-/nix/var/nix/profiles/default}"

# The installer reads $USER; a root setup shell may not set it.
export USER="${USER:-$(id -un)}"

# True when nix in profile dir $1 runs and is at least $min_version.
meets_floor() {
    local have
    have="$("$1/nix" --version 2>/dev/null)" || return 1
    have="${have##* }"
    [ "$(printf '%s\n' "$min_version" "$have" | sort -V | head -n 1)" = "$min_version" ]
}

# The image ships Nix in the default profile (probe 1, C8): use it when it
# meets the floor (V4). Otherwise multi-user needs systemd to run
# nix-daemon; without it, single-user.
if meets_floor "$default_profile/bin"; then
    mode=none
    profile_bin="$default_profile/bin"
elif [ -d "$systemd_dir" ]; then
    mode=--daemon
    profile_bin="$default_profile/bin"
else
    mode=--no-daemon
    profile_bin="$HOME/.nix-profile/bin"
fi

if [ "$mode" != none ] && ! meets_floor "$profile_bin"; then
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL "$url" -o "$tmp/install"
    echo "$sha256  $tmp/install" | sha256sum -c --quiet -
    sh "$tmp/install" "$mode" --yes
fi

# A managed block between BEGIN and END markers, replaced whole on every
# run (V3, B2): a changed block reaches VMs that have the old one, and
# lines outside it (the installer's build-users-group) are kept.
mkdir -p "$conf_dir"
conf="$conf_dir/nix.conf"
begin="# BEGIN nix-claude-code-cloud (SPEC V3)"
end="# END nix-claude-code-cloud (SPEC V3)"
kept=()
if [ -f "$conf" ]; then
    inside=0
    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$line" = "$begin" ]; then
            inside=1
        elif [ "$line" = "$end" ]; then
            inside=0
        elif [ "$inside" = 0 ]; then
            kept+=("$line")
        fi
    done <"$conf"
fi
{
    if [ "${#kept[@]}" -gt 0 ]; then
        printf '%s\n' "${kept[@]}"
    fi
    printf '%s\n' "$begin" \
        'experimental-features = nix-command flakes' \
        'accept-flake-config = true' \
        'extra-substituters = https://pr0d1r2.cachix.org' \
        'extra-trusted-public-keys = pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=' \
        "$end"
} >"$conf.tmp"
mv "$conf.tmp" "$conf"

# Claude's Bash tool may not source shell profiles, so put nix on a PATH
# dir every shell already has.
mkdir -p "$bin_dir"
ln -sf "$profile_bin"/* "$bin_dir/"
"$bin_dir/nix" --version
