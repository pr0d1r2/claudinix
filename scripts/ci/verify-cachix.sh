#!/usr/bin/env bash
# Prove the cache push (SPEC V22, C19): every flake attribute's output path
# has a narinfo in the binary cache, answering HTTP 200. A push step that
# exits 0 but pushed nothing, or was refused, is red here.
#
# Usage: verify-cachix.sh FLAKE_ATTR...
#   e.g. verify-cachix.sh .#checks.x86_64-linux.xenolith
# Env:   CACHIX_URL (default https://pr0d1r2.cachix.org)

set -euo pipefail

if [ "$#" -eq 0 ]; then
    echo "usage: verify-cachix.sh FLAKE_ATTR... -- an empty list proves nothing" >&2
    exit 2
fi

cache="${CACHIX_URL:-https://pr0d1r2.cachix.org}"
status=0

for attr in "$@"; do
    if ! path="$(nix eval --raw "$attr.outPath")"; then
        echo "verify-cachix: could not evaluate $attr -- nothing was checked" >&2
        status=1
        continue
    fi
    base="${path#/nix/store/}"
    hash="${base%%-*}"
    code="$(curl -s -o /dev/null -w '%{http_code}' "$cache/$hash.narinfo")"
    if [ "$code" != 200 ]; then
        echo "verify-cachix: $path is not in $cache (narinfo HTTP $code)" >&2
        status=1
    fi
done

exit "$status"
