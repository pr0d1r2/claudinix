#!/usr/bin/env bash
# Record the agent home's activation store path in cloud-home.storepath
# (SPEC nix:T18), the path `setup.sh` substitutes from cachix when it
# cannot build the flake (nix:V15 tier 2). Writes only after the cache
# answers 200 for the path's narinfo (V22): a recorded path that is not
# in the cache would send every session to a dead end.
#
# The activation derivation does not read this file (V20), so committing
# it after CI has pushed the path leaves the path unchanged. Run from the
# repo after CI is green on main, then commit the file.
#
# Usage: record-storepath.sh [FLAKE]   (default: .)
# Env:   CLOUD_HOME_STOREPATH (default cloud-home.storepath)
#        CACHIX_URL (default https://pr0d1r2.cachix.org)

set -euo pipefail

if [ "$#" -gt 1 ]; then
    echo "usage: record-storepath.sh [FLAKE]" >&2
    exit 2
fi

flake="${1:-.}"
file="${CLOUD_HOME_STOREPATH:-cloud-home.storepath}"
cache="${CACHIX_URL:-https://pr0d1r2.cachix.org}"
attr="$flake#homeConfigurations.cloud.activationPackage"

if ! path="$(nix eval --raw "$attr.outPath")"; then
    echo "record-storepath: could not evaluate $attr -- nothing was recorded" >&2
    exit 1
fi

case "$path" in
/nix/store/?*) ;;
*)
    echo "record-storepath: '$path' is not a store path -- nothing was recorded" >&2
    exit 1
    ;;
esac

base="${path#/nix/store/}"
hash="${base%%-*}"
code="$(curl -s -o /dev/null -w '%{http_code}' "$cache/$hash.narinfo")"
if [ "$code" != 200 ]; then
    echo "record-storepath: $path is not in $cache (narinfo HTTP $code) -- push it first, nothing was recorded" >&2
    exit 1
fi

printf '%s\n' "$path" >"$file.tmp"
mv "$file.tmp" "$file"
echo "record-storepath: $file = $path"
