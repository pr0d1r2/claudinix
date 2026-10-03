#!/usr/bin/env bash
# `nix develop` that survives a cloud session's GitHub proxy (SPEC
# scripts:T12, scripts:T79, scripts:V13, .:V8, I.cmd `nix-dev`).
#
# A `github:` input 403s in a session unless its repo is attached, so the
# dev shell of the flake in the current directory is reached through the
# first tier that works, each one logged on stderr as `tier N`:
#   1. plain: locked inputs substituted by narHash from a cache;
#   2. every github input but nixpkgs that no cache holds as
#      `git+https://github.com/<o>/<r>?rev=<locked rev>&shallow=1`
#      (a git read the proxy lets through; nixpkgs is too big for it);
#   3. `github:` as locked: works only for repos attached to the session;
#   4. tier 2 plus each nixpkgs node from its channel tarball on
#      channels.nixos.org (that node's `nixos-<ver>` | `nixos-unstable` |
#      `nixpkgs-unstable` ref, else nixpkgs-unstable): degraded, the rev
#      differs from the lock.
# nixpkgs is matched case-insensitively (`nixos/nixpkgs` too). Overrides
# are never written to flake.lock (--no-write-lock-file). Tiers 3 and 4
# warn. A tier whose command an earlier tier already ran is skipped. Each
# tier is tried with `nix print-dev-env`, and a failed one logs nix's
# first `error:` line; the winner's arguments go to `nix develop` with the
# caller's ARGS after them. A leading installable (first arg not starting
# with `-`, e.g. `.#ci`) goes first to every one of those commands.
#
# Which inputs a cache holds comes from inputs.sh (scripts:T49, T25):
# tier 1 runs only when every github input is cached, and tier 2
# overrides only the uncached ones, so a flake needs no change. When the
# status cannot be read, tier 1 is tried anyway and tier 2 overrides
# every github input but nixpkgs. Without jq there is no failover at all,
# and a loud warning says so.
#
# Without INSTALLABLE, the project's .claudinix.toml names it
# (devshell.installable, scripts:T91); an INSTALLABLE given wins.
#
# Usage: nix-dev [INSTALLABLE] [ARGS...]   (as for `nix develop`)
# Env:   CLAUDINIX_SCRIPTS  dir holding nix-dev.jq, inputs.sh and config.sh
#                           (default: this script's dir, symlinks followed)

set -euo pipefail

log() {
    echo "nix-dev: $*" >&2
}

# Installed as a symlink in a PATH dir: find the real file's dir.
self="${BASH_SOURCE[0]}"
while [ -L "$self" ]; do
    target="$(readlink "$self")"
    case "$target" in
    /*) self="$target" ;;
    *) self="$(dirname "$self")/$target" ;;
    esac
done
lib="${CLAUDINIX_SCRIPTS:-$(dirname "$self")}"

# A leading installable names the flake; its lock is the one that counts.
# Without one, the project's devshell.installable (scripts:T91, V34),
# read by config.sh at the repo's top level; `.` is a bare develop. A
# bad file exits 2. A lib dir without config.sh (an older install) or a
# PATH without jq reads no file.
installable=()
case "${1:-}" in
-* | "")
    if [ -f "$lib/config.sh" ] && command -v jq >/dev/null 2>&1; then
        from_file="$(bash "$lib/config.sh" get devshell.installable)" || exit "$?"
        if [ "$from_file" != . ]; then
            installable=("$from_file")
            log "installable $from_file from .claudinix.toml (devshell.installable)"
        fi
    fi
    ;;
*)
    installable=("$1")
    shift
    ;;
esac
flake=.
if [ "${#installable[@]}" -gt 0 ]; then
    flake="${installable[0]%%#*}"
    flake="${flake:-.}"
fi

if [ ! -d "$flake" ]; then
    log "tier 1: plain nix develop (${installable[0]} is not a local flake dir, so no failover)"
    exec nix develop "${installable[@]}" "$@"
fi
if [ ! -f "$flake/flake.lock" ]; then
    log "tier 1: plain nix develop (no flake.lock here, so no failover)"
    exec nix develop "${installable[@]+"${installable[@]}"}" "$@"
fi
if ! command -v jq >/dev/null 2>&1; then
    log "WARNING: jq is not on PATH -- failover is off, running plain nix develop as tier 1 (install jq for the scripts:V13 tiers)"
    exec nix develop "${installable[@]+"${installable[@]}"}" "$@"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
jq -r -f "$lib/nix-dev.jq" "$flake/flake.lock" >"$tmp/github"

# why FILE: nix's first `error:` line in FILE, else its last non-empty one.
why() {
    local line
    line="$(grep -m 1 -E '^[[:space:]]*error:' "$1" || true)"
    [ -n "$line" ] || line="$(grep -v '^[[:space:]]*$' "$1" | tail -n 1 || true)"
    line="${line#"${line%%[![:space:]]*}"}"
    printf '%s' "${line:-no output}"
}

# `owner/repo rev cached|uncached` per github input (scripts:T25).
if bash "$lib/inputs.sh" "$flake" >"$tmp/status" 2>"$tmp/status.err"; then
    known=1
else
    known=0
    log "cache status unknown (inputs.sh: $(why "$tmp/status.err")) -- trying every tier"
fi

# uncached NAME REV: no cache holds it, or nobody knows.
uncached() {
    [ "$known" = 0 ] || grep -qxF "$1 $2 uncached" "$tmp/status"
}

git_overrides=()
channel_overrides=()
channels=()
while read -r path name rev ref; do
    if [ "$(tr '[:upper:]' '[:lower:]' <<<"$name")" = nixos/nixpkgs ]; then
        case "$ref" in
        nixos-[0-9]*.[0-9]* | nixos-unstable | nixpkgs-unstable) channel="$ref" ;;
        *) channel=nixpkgs-unstable ;;
        esac
        channel_overrides+=(--override-input "$path" "https://channels.nixos.org/$channel/nixexprs.tar.xz")
        case " ${channels[*]-} " in
        *" $channel "*) ;;
        *) channels+=("$channel") ;;
        esac
    elif uncached "$name" "$rev"; then
        git_overrides+=(--override-input "$path" "git+https://github.com/$name?rev=$rev&shallow=1")
    fi
done <"$tmp/github"
channel="${channels[*]-}"

tried="$tmp/tried"
: >"$tried"
chosen=()

# attempt N WHAT ARGS...: true, and ARGS chosen, when the dev shell builds.
attempt() {
    local tier="$1" what="$2" key
    shift 2
    key="${*:-plain}"
    if grep -qxF -- "$key" "$tried"; then
        log "tier $tier skipped: same command as an earlier tier"
        return 1
    fi
    echo "$key" >>"$tried"
    if nix print-dev-env "${installable[@]+"${installable[@]}"}" "$@" >/dev/null 2>"$tmp/err"; then
        chosen=("$@")
        log "using tier $tier: $what"
        return 0
    fi
    log "tier $tier failed ($what): $(why "$tmp/err")"
    return 1
}

missing=0
if [ "$known" = 1 ]; then
    missing="$(grep -c ' uncached$' "$tmp/status" || true)"
fi

if [ "$missing" -gt 0 ]; then
    log "tier 1 skipped: $missing github input(s) in no cache"
fi
if [ "$missing" = 0 ] && attempt 1 "locked inputs from a cache"; then
    :
elif [ "${#git_overrides[@]}" -gt 0 ] &&
    attempt 2 "github inputs as git+https at the locked rev" \
        --no-write-lock-file "${git_overrides[@]}"; then
    :
elif attempt 3 "github: as locked (attached repos only)"; then
    log "warning: tier 3 reached -- only repos attached to the session can be fetched (scripts:V13)"
elif [ "${#channel_overrides[@]}" -gt 0 ] &&
    attempt 4 "nixpkgs from the $channel channel" \
        --no-write-lock-file "${git_overrides[@]+"${git_overrides[@]}"}" "${channel_overrides[@]}"; then
    log "warning: tier 4 reached -- nixpkgs comes from the $channel channel, not the locked rev (scripts:V13)"
else
    log "every tier failed -- see the errors above (scripts:V13)"
    exit 1
fi

# exec skips the EXIT trap, so clean up first.
rm -rf "$tmp"
exec nix develop "${installable[@]+"${installable[@]}"}" "${chosen[@]+"${chosen[@]}"}" "$@"
