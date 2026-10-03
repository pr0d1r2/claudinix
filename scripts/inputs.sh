#!/usr/bin/env bash
# Which of a flake's github inputs a cloud session can get without GitHub
# (SPEC scripts:T25, I.cmd `inputs`, .:V8, C6).
#
# A `github:` input fetches an archive tarball that the session's proxy
# refuses unless the repository is attached to the session. One whose
# source is already in a binary cache is substituted by its narHash and
# never touches GitHub. So every github node of flake.lock (nested and
# deduped) prints one line:
#
#   owner/repo rev cached   -- a cache has its source's narinfo
#   owner/repo rev uncached -- no cache has it: GitHub must serve it
#
# When any input is uncached, one line on stderr says what to do: nix-dev
# fetches them over git, or the flake can name them as
# `git+https://github.com/<owner>/<repo>` (scripts:T80).
#
# Store paths come from `nix flake archive --dry-run --json`, which fetches
# nothing. Run it from the project you will send to the cloud.
#
# Usage: inputs.sh [--check] [FLAKE_DIR]   (default: the current directory)
#   --check  exit 1 when any input is uncached
# Env:   INPUTS_CACHES  cache URLs, space-separated (default: the cachix
#                       `cache.name` in FLAKE_DIR/.claudinix.toml names,
#                       else the owner's, and cache.nixos.org)
#        CLAUDINIX_SCRIPTS  dir holding inputs.jq and config.sh (default:
#                           this script's dir)

set -euo pipefail

usage() {
    echo "usage: inputs.sh [--check] [FLAKE_DIR]" >&2
    exit 2
}

check=0
dir=
for arg in "$@"; do
    case "$arg" in
    --check) check=1 ;;
    -*) usage ;;
    *)
        [ -z "$dir" ] || usage
        dir="$arg"
        ;;
    esac
done

lib="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"

# Absolute, so nix never reads a bare name as a flake registry entry.
given="${dir:-.}"
if ! dir="$(cd "$given" 2>/dev/null && pwd)"; then
    echo "inputs: no directory $given -- nothing was checked" >&2
    exit 1
fi

# INPUTS_CACHES wins; else the flake dir's cache.name (scripts:T91, V34;
# default pr0d1r2) beside cache.nixos.org. A bad file exits 2. A lib
# dir without config.sh (an older nix-dev install) reads no file.
name=pr0d1r2
if [ -n "${INPUTS_CACHES:-}" ]; then
    caches="$INPUTS_CACHES"
else
    if [ -f "$lib/config.sh" ]; then
        name="$(bash "$lib/config.sh" --dir "$given" get cache.name)" || exit "$?"
    fi
    caches="https://$name.cachix.org https://cache.nixos.org"
fi
if [ ! -f "$dir/flake.lock" ]; then
    echo "inputs: no flake.lock in $dir -- nothing was checked (run nix flake lock first)" >&2
    exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if ! nix flake archive --dry-run --json "$dir" >"$tmp/archive.json"; then
    echo "inputs: nix flake archive could not run on $dir -- nothing was checked" >&2
    exit 1
fi

jq -r -n --slurpfile lock "$dir/flake.lock" --slurpfile arch "$tmp/archive.json" \
    -f "$lib/inputs.jq" >"$tmp/inputs"

# cached PATH: some cache answers 200 for the path's narinfo. Bounded
# like verify-cachix.sh (T88): a stalled cache is a miss, not a hang.
cached() {
    local base="${1#/nix/store/}" cache code
    [ -n "$base" ] || return 1
    for cache in $caches; do
        code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 --max-time 30 \
            "$cache/${base%%-*}.narinfo" || true)"
        [ "$code" != 200 ] || return 0
    done
    return 1
}

status=0
while read -r name rev path; do
    if cached "${path:-}"; then
        echo "$name $rev cached"
    else
        echo "$name $rev uncached"
        status=1
    fi
done <"$tmp/inputs"

if [ "$status" = 1 ]; then
    echo "inputs: uncached inputs come from GitHub: nix-dev fetches them over git, or rewrite each as git+https://github.com/<owner>/<repo> in flake.nix" >&2
fi

if [ "$check" = 1 ]; then
    exit "$status"
fi
