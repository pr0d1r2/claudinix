#!/usr/bin/env bash
# Setup script for the Claude Code cloud environment (SPEC T2, I.file,
# I.ext.env). Imported from the owner's private seed repo at 476cf1d
# (cloud/envs/nix/setup.sh). Runs as root on
# Ubuntu 24.04 before Claude Code starts; the result is cached as a
# filesystem snapshot when it ends within ~5 min, and skipped after that.
# Installs pinned upstream Nix (installer hash-checked; it checks its own
# tarball), flakes on, owner cachix as a read-only substituter (V6).
# Git hooks are not installed here (V7): each session is a fresh clone and
# this script does not run on a cached snapshot, so the target repo's
# devShell installs them.
# Usage: setup.sh [SHA]   SHA = the full commit id this file was fetched
#        at (V20); pins the agent home to it.
# Seams: NIX_CONF_DIR, BIN_DIR, SYSTEMD_DIR, NIX_DEFAULT_PROFILE,
#        NIX_INSTALL_URL, NIX_INSTALL_SHA256; agent home (T17):
#        CLOUD_HOME_FLAKE, CLOUD_HOME_STOREPATH (file), CLOUD_HOME_MARKER;
#        nix-dev: NCCC_LIB_DIR, NCCC_RAW_URL, NCCC_REV (default main).

set -euo pipefail

# The SHA the UI line fetched this file at (V20). A short or mistyped id
# would pin nothing, so refuse it before touching the system.
sha="${1:-}"
if [ "$#" -gt 1 ] || { [ -n "$sha" ] && ! [[ "$sha" =~ ^[0-9a-f]{40}$ ]]; }; then
    echo "usage: setup.sh [SHA] -- SHA is a full 40-hex commit id" >&2
    exit 2
fi

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

# nix-dev (I.cmd, scripts:T12): `nix develop` with the scripts:V13 input
# failover, linked onto the same PATH dir. Its files come from the clone
# beside this script, else from the repo at NCCC_REV. A failed fetch only
# warns: nix itself still works (V1).
lib_dir="${NCCC_LIB_DIR:-/usr/local/lib/nix-claude-code-cloud}"
raw="${NCCC_RAW_URL:-https://raw.githubusercontent.com/pr0d1r2/nix-claude-code-cloud/${NCCC_REV:-main}}"
here="$(dirname "${BASH_SOURCE[0]:-.}")"
mkdir -p "$lib_dir"
nix_dev=ok
# inputs.* tell nix-dev which inputs a cache holds (scripts:T49).
for file in nix-dev.sh nix-dev.jq inputs.sh inputs.jq; do
    if [ -f "$here/scripts/$file" ]; then
        cp "$here/scripts/$file" "$lib_dir/$file"
    elif ! curl -fsSL "$raw/scripts/$file" -o "$lib_dir/$file"; then
        nix_dev=failed
    fi
done
if [ "$nix_dev" = ok ]; then
    chmod +x "$lib_dir/nix-dev.sh"
    ln -sf "$lib_dir/nix-dev.sh" "$bin_dir/nix-dev"
else
    echo "setup: could not fetch nix-dev from $raw -- use plain nix develop" >&2
fi

"$bin_dir/nix" --version

# The agent home (T17, nix:V14, nix:V15): activated here, before Claude
# launches, as the user and HOME Claude runs as (root, /root: C8), so the
# skills are in ~/.claude at launch and in the snapshot. Tier 1 builds it
# from the flake over git+https (`github:` is a 403 in the cloud, C6, B3);
# its closure is substituted from cachix. Tier 2 realises the recorded
# store path from cachix without touching GitHub. If both fail, Nix stays
# usable: warn loudly, leave a marker, exit 0.
# With a SHA (V20) both tiers are pinned to it.
repo=pr0d1r2/nix-claude-code-cloud
home_flake="${CLOUD_HOME_FLAKE:-git+https://github.com/$repo?${sha:+rev=$sha&}shallow=1}"
home_storepath="${CLOUD_HOME_STOREPATH:-$(dirname "$0")/cloud-home.storepath}"
home_marker="${CLOUD_HOME_MARKER:-$HOME/.local/state/nix-claude-code-cloud/agent-home.failed}"
home_attr="$home_flake#homeConfigurations.cloud.activationPackage"

# The UI line fetches setup.sh alone, so the recorded path is fetched at
# the same SHA when it is not beside the script. A failed fetch only
# leaves tier 2 with nothing to realise.
fetch_storepath() {
    if [ ! -s "$home_storepath" ] && [ -n "$sha" ]; then
        curl -fsSL --max-time 30 "https://raw.githubusercontent.com/$repo/$sha/cloud-home.storepath" \
            -o "$home_storepath" || true
    fi
    [ -s "$home_storepath" ]
}

home=""
if home="$("$bin_dir/nix" build --no-link --print-out-paths "$home_attr")" && [ -x "$home/activate" ]; then
    echo "agent home: tier 1 (flake build) $home"
elif fetch_storepath && home="$(cat "$home_storepath")" &&
    "$bin_dir/nix-store" -r "$home" >/dev/null && [ -x "$home/activate" ]; then
    echo "agent home: tier 2 (recorded store path) $home"
else
    home=""
fi

if [ -n "$home" ] && PATH="$bin_dir:$PATH" "$home/activate"; then
    rm -f "$home_marker"
else
    echo "WARNING: agent home NOT activated (tier 1 $home_attr, tier 2 $home_storepath): Nix works, ~/.claude skills are missing" >&2
    mkdir -p "$(dirname "$home_marker")"
    touch "$home_marker"
fi
