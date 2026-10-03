#!/usr/bin/env bash
# Push every eval-time input source of a flake to a binary cache (SPEC
# T74, V30, B8). A cloud session evaluates the agent home and the dev
# shell before it builds anything; an input it cannot fetch from GitHub
# there must be substitutable by its narHash. The cachix-action daemon
# pushes only built paths, so the sources go here: `nix flake archive`
# copies each locked input (nested ones too) into the store and names
# it, and `cachix push` reads the list.
#
# Usage: push-sources.sh CACHE [FLAKE]   (FLAKE default: .)
#   e.g. push-sources.sh pr0d1r2

set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "usage: push-sources.sh CACHE [FLAKE]" >&2
    exit 2
fi

cache="$1"
flake="${2:-.}"

if ! archive="$(nix flake archive --json "$flake")"; then
    echo "push-sources: could not archive $flake -- nothing was pushed" >&2
    exit 1
fi

paths="$(jq -r '.. | .path? // empty' <<<"$archive")"
if [ -z "$paths" ]; then
    echo "push-sources: $flake names no source path -- nothing was pushed" >&2
    exit 1
fi

count="$(wc -l <<<"$paths" | tr -d ' ')"
if ! cachix push "$cache" <<<"$paths"; then
    echo "push-sources: cachix push $cache failed for $count source paths" >&2
    exit 1
fi
echo "push-sources: pushed $count source paths of $flake to $cache"
