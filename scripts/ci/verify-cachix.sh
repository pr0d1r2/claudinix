#!/usr/bin/env bash
# Prove the cache push (SPEC V22, C19): every flake attribute's output path
# has a narinfo in the binary cache, answering HTTP 200. A push step that
# exits 0 but pushed nothing, or was refused, is red here.
#
# With `--sources FLAKE` it also proves every eval-time input source of
# FLAKE (`nix flake archive --dry-run --json`, nested inputs included)
# can be substituted (T74, V30): a narinfo 200 in the cache, or in the
# upstream cache, which serves nixpkgs' source.
#
# Usage: verify-cachix.sh [--sources FLAKE] [FLAKE_ATTR...]
#   e.g. verify-cachix.sh --sources . .#devShells.x86_64-linux.default
# Env:   CACHIX_URL (default https://pr0d1r2.cachix.org)
#        UPSTREAM_URL (default https://cache.nixos.org; sources only)

set -euo pipefail

usage="usage: verify-cachix.sh [--sources FLAKE] [FLAKE_ATTR...] -- an empty list proves nothing"
sources=""
if [ "${1:-}" = --sources ]; then
    if [ "$#" -lt 2 ]; then
        echo "$usage" >&2
        exit 2
    fi
    sources="$2"
    shift 2
fi
if [ "$#" -eq 0 ] && [ -z "$sources" ]; then
    echo "$usage" >&2
    exit 2
fi

cache="${CACHIX_URL:-https://pr0d1r2.cachix.org}"
upstream="${UPSTREAM_URL:-https://cache.nixos.org}"
status=0

# The HTTP code of a store path's narinfo in cache $1. An unreachable
# cache is 000 (curl prints it, then fails): a red result, not an abort.
narinfo() {
    local base="${2#/nix/store/}"
    curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 --max-time 30 \
        "$1/${base%%-*}.narinfo" || true
}

for attr in "$@"; do
    if ! path="$(nix eval --raw "$attr.outPath")"; then
        echo "verify-cachix: could not evaluate $attr -- nothing was checked" >&2
        status=1
        continue
    fi
    code="$(narinfo "$cache" "$path")"
    if [ "$code" != 200 ]; then
        echo "verify-cachix: $path is not in $cache (narinfo HTTP $code)" >&2
        status=1
    fi
done

if [ -n "$sources" ]; then
    if ! archive="$(nix flake archive --dry-run --json "$sources")" ||
        ! paths="$(jq -r '.. | .path? // empty' <<<"$archive")"; then
        echo "verify-cachix: could not list the input sources of $sources -- nothing was checked" >&2
        exit 1
    fi
    if [ -z "$paths" ]; then
        echo "verify-cachix: $sources names no source path -- nothing was checked" >&2
        exit 1
    fi
    while IFS= read -r path; do
        code="$(narinfo "$cache" "$path")"
        [ "$code" = 200 ] && continue
        up="$(narinfo "$upstream" "$path")"
        if [ "$up" != 200 ]; then
            echo "verify-cachix: source $path is in neither $cache (narinfo HTTP $code) nor $upstream (HTTP $up)" >&2
            status=1
        fi
    done <<<"$paths"
fi

exit "$status"
