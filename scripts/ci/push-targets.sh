#!/usr/bin/env bash
# The central cache job (SPEC T93, .:V30, .:C28, V6): for every flake ref
# in the targets file whose `.claudinix.toml` says `push_sources = true`,
# push its eval-time input sources to the cache its `cache.name` names,
# then prove they arrived. Sources only: a target's build outputs are
# never built or pushed here, so the cache holds nothing it did not
# choose to share (trust). One bad target does not hide the next; the
# run fails at the end.
#
# Usage: push-targets.sh [TARGETS_FILE]   (default: cache-targets.txt)
#        one flake ref per line; blank lines and `#` comments are ignored

set -euo pipefail

if [ "$#" -gt 1 ]; then
    echo "usage: push-targets.sh [TARGETS_FILE]" >&2
    exit 2
fi
targets="${1:-cache-targets.txt}"
if [ ! -f "$targets" ]; then
    echo "push-targets: no targets file $targets -- nothing was pushed" >&2
    exit 2
fi

here="$(dirname "${BASH_SOURCE[0]}")"
config="$here/../config.sh"
status=0

# push_target REF: skip, or push and verify; non-zero when REF failed.
push_target() {
    local ref="$1" meta dir opted name
    if ! meta="$(nix flake metadata --json "$ref")" ||
        ! dir="$(jq -er '.path' <<<"$meta")"; then
        echo "push-targets: could not fetch $ref" >&2
        return 1
    fi
    if ! opted="$(bash "$config" --dir "$dir" get cache.push_sources)"; then
        echo "push-targets: bad .claudinix.toml in $ref" >&2
        return 1
    fi
    if [ "$opted" != true ]; then
        echo "push-targets: skip $ref (push_sources is not true)"
        return 0
    fi
    name="$(bash "$config" --dir "$dir" get cache.name)" || return 1
    bash "$here/push-sources.sh" "$name" "$ref" || return 1
    CACHIX_URL="https://$name.cachix.org" bash "$here/verify-cachix.sh" --sources "$ref"
}

while IFS= read -r ref || [ -n "$ref" ]; do
    ref="${ref%%#*}"
    ref="$(echo "$ref" | tr -d '[:space:]')"
    [ -n "$ref" ] || continue
    if ! push_target "$ref"; then
        echo "push-targets: $ref failed" >&2
        status=1
    fi
done <"$targets"

exit "$status"
