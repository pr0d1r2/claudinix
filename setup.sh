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
# Usage: setup.sh [SHA] [--agent-home]
#        SHA = the full commit id this file was fetched at (V20); pins
#        nix-dev and the agent home to it. --agent-home (or
#        CLAUDINIX_AGENT_HOME=1) also activates the agent home, which is
#        opt-in (C24): without it setup is Nix and nix-dev only.
# Seams: NIX_CONF_DIR, BIN_DIR, SYSTEMD_DIR, NIX_DEFAULT_PROFILE,
#        NIX_INSTALL_URL, NIX_INSTALL_SHA256; agent home (T17):
#        CLOUD_HOME_FLAKE, CLOUD_HOME_STOREPATH (file), CLOUD_HOME_MARKER;
#        nix-dev: CLAUDINIX_LIB_DIR, CLAUDINIX_RAW_URL, CLAUDINIX_REV
#        (default: the SHA argument, else main); CLAUDINIX_NIX_TIMEOUT
#        (seconds each of the installer and the two agent home tiers may
#        take, default 120: T88, V5).

set -euo pipefail

# Everything owner-specific, and nothing else (C11): a fork edits only
# this block. The cache is read-only and its key is public (V6).
# BEGIN fork config (SPEC C11)
cache_host=pr0d1r2.cachix.org
cache_key=pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=
repo=pr0d1r2/claudinix
# END fork config (SPEC C11)

# The SHA the UI line fetched this file at (V20), and whether to add the
# agent home (C24). A short or mistyped id would pin nothing and a
# mistyped flag would silently drop the agent home, so anything else is
# refused before touching the system.
usage="usage: setup.sh [SHA] [--agent-home] -- SHA is a full 40-hex commit id; --agent-home (or CLAUDINIX_AGENT_HOME=1) also activates the agent home"
sha=""
agent_home="${CLAUDINIX_AGENT_HOME:-0}"
case "$agent_home" in
0 | 1) ;;
*)
    echo "$usage; CLAUDINIX_AGENT_HOME must be 0 or 1, not '$agent_home'" >&2
    exit 2
    ;;
esac
for arg in "$@"; do
    case "$arg" in
    --agent-home) agent_home=1 ;;
    *)
        if [ -n "$sha" ] || ! [[ "$arg" =~ ^[0-9a-f]{40}$ ]]; then
            echo "$usage" >&2
            exit 2
        fi
        sha="$arg"
        ;;
    esac
done

# The directory this file sits in, when it is a file. Read from stdin it
# has none, and the cwd is not it: everything beside the script is then
# fetched from the repo at the SHA instead.
here=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Every network step is bounded: a stalled host must not eat the ~5 min
# the snapshot is cached within (C1, V5, T88). curl gets a connect and a
# total limit; Nix gets a connect and a stall limit on every download,
# and the installer and both agent home tiers run under `timeout`.
nix_timeout="${CLAUDINIX_NIX_TIMEOUT:-120}"
if ! [[ "$nix_timeout" =~ ^[1-9][0-9]*$ ]]; then
    echo "setup: CLAUDINIX_NIX_TIMEOUT must be a whole number of seconds, not '$nix_timeout'" >&2
    exit 2
fi
nix_net=(--option connect-timeout 10 --option stalled-download-timeout 30)

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fetch() {
    curl -fsSL --connect-timeout 10 --max-time 60 "$1" -o "$2"
}

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

installed=no
if [ "$mode" != none ] && ! meets_floor "$profile_bin"; then
    fetch "$url" "$work/install"
    echo "$sha256  $work/install" | sha256sum -c --quiet -
    timeout "$nix_timeout" sh "$work/install" "$mode" --yes
    installed=yes
fi

# A managed block between BEGIN and END markers, replaced whole on every
# run (V3, B2): a changed block reaches VMs that have the old one, and
# lines outside it (the installer's build-users-group) are kept.
mkdir -p "$conf_dir"
conf="$conf_dir/nix.conf"
begin="# BEGIN claudinix (SPEC V3)"
end="# END claudinix (SPEC V3)"
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
        "extra-substituters = https://$cache_host" \
        "extra-trusted-public-keys = $cache_key" \
        "$end"
} >"$conf.tmp"
mv "$conf.tmp" "$conf"

# Claude's Bash tool may not source shell profiles, so put nix on a PATH
# dir every shell already has.
mkdir -p "$bin_dir"
ln -sf "$profile_bin"/* "$bin_dir/"

# Claude's Bash tool finds the default profile's nix before this PATH dir
# (C8). A single-user install lands elsewhere, so an older image nix can
# still win there: say so rather than leave the session on it (V1, V4).
if [ "$installed" = yes ]; then
    first="$bin_dir"
    if [ -x "$default_profile/bin/nix" ]; then
        first="$default_profile/bin"
    fi
    if ! meets_floor "$first"; then
        have="$("$first/nix" --version 2>/dev/null || echo "a nix that does not run")"
        echo "WARNING: $first comes first on Claude's PATH and its nix ($have) is below $min_version -- the installed one is in $bin_dir" >&2
    fi
fi

# nix-dev (I.cmd, scripts:T12): `nix develop` with the scripts:V13 input
# failover, linked onto the same PATH dir. Its files come from the clone
# beside this script, else from the repo at the SHA this script was
# fetched at (T69, V20), or `main` when none was given. They are staged
# in "$lib_dir.new", beside the live dir so the swap never crosses a
# filesystem, and swapped in whole with one mv (T73, T88): a partial set
# would link a nix-dev that cannot find its jq program, and files nix-dev
# no longer ships do not linger. A failed fetch only warns and drops any
# older link: nix itself still works (V1).
lib_dir="${CLAUDINIX_LIB_DIR:-/usr/local/lib/claudinix}"
raw="${CLAUDINIX_RAW_URL:-https://raw.githubusercontent.com/$repo/${CLAUDINIX_REV:-${sha:-main}}}"
# inputs.* tell nix-dev which inputs a cache holds (scripts:T49); config.*
# read the project's .claudinix.toml for both (scripts:T91). setup.sh
# itself never reads that file (C28).
nix_dev_files=(nix-dev.sh nix-dev.jq inputs.sh inputs.jq config.sh config.jq)
stage="$lib_dir.new"
# A staging dir a killed run left behind is never installed.
rm -rf "$stage"
mkdir -p "$stage"
nix_dev=ok
for file in "${nix_dev_files[@]}"; do
    if [ -n "$here" ] && [ -f "$here/scripts/$file" ]; then
        cp "$here/scripts/$file" "$stage/$file"
    elif ! fetch "$raw/scripts/$file" "$stage/$file"; then
        nix_dev=failed
        break
    fi
done
if [ "$nix_dev" = ok ]; then
    chmod +x "$stage/nix-dev.sh"
    rm -rf "$lib_dir"
    mv "$stage" "$lib_dir"
    ln -sf "$lib_dir/nix-dev.sh" "$bin_dir/nix-dev"
else
    rm -rf "$stage"
    if [ -L "$bin_dir/nix-dev" ]; then
        rm -f "$bin_dir/nix-dev"
    fi
    echo "setup: could not fetch nix-dev from $raw -- use plain nix develop" >&2
fi

"$bin_dir/nix" --version

# The agent home is opt-in (C24): it changes how Claude behaves, so a
# setup that did not ask for it stops at Nix and nix-dev.
if [ "$agent_home" != 1 ]; then
    echo "agent home: skipped -- opt in with setup.sh [SHA] --agent-home, or CLAUDINIX_AGENT_HOME=1"
    exit 0
fi

# The agent home (T17, nix:V14, nix:V15): activated here, before Claude
# launches, as the user and HOME Claude runs as (root, /root: C8), so the
# skills are in ~/.claude at launch and in the snapshot. Tier 1 builds it
# from the flake over git+https (`github:` is a 403 in the cloud, C6, B3);
# its closure is substituted from cachix. Tier 2 realises the recorded
# store path from cachix without touching GitHub. If both fail, Nix stays
# usable: warn loudly, leave a marker, exit 0.
# With a SHA (V20) both tiers are pinned to it.
home_flake="${CLOUD_HOME_FLAKE:-git+https://github.com/$repo?${sha:+rev=$sha&}shallow=1}"
home_storepath="${CLOUD_HOME_STOREPATH:-${here:-$work}/cloud-home.storepath}"
home_marker="${CLOUD_HOME_MARKER:-$HOME/.local/state/claudinix/agent-home.failed}"
home_attr="$home_flake#homeConfigurations.cloud.activationPackage"

# The UI line fetches setup.sh alone, so the recorded path is fetched at
# the same SHA when it is not beside the script. A failed fetch only
# leaves tier 2 with nothing to realise.
fetch_storepath() {
    if [ ! -s "$home_storepath" ] && [ -n "$sha" ]; then
        fetch "https://raw.githubusercontent.com/$repo/$sha/cloud-home.storepath" "$home_storepath" || true
    fi
    [ -s "$home_storepath" ]
}

home=""
if home="$(timeout "$nix_timeout" "$bin_dir/nix" build "${nix_net[@]}" --no-link --print-out-paths "$home_attr")" &&
    [ -x "$home/activate" ]; then
    echo "agent home: tier 1 (flake build) $home"
elif fetch_storepath && home="$(cat "$home_storepath")" &&
    timeout "$nix_timeout" "$bin_dir/nix-store" -r "${nix_net[@]}" "$home" >/dev/null &&
    [ -x "$home/activate" ]; then
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
