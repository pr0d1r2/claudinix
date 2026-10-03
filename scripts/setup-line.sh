#!/usr/bin/env bash
# Print the one-line setup script for the claude.ai environment dialog
# (SPEC T24, V20, C19): download setup.sh at a fixed commit into a fresh
# temp dir and run it with the same SHA, which pins the agent home too.
# A bump is a new SHA in this line and nothing else.
#
# Use a SHA that is on GitHub and green in CI (its agent home pushed to
# cachix); this script checks neither, it only resolves the revision.
#
# Usage: setup-line.sh [REV]   (default: HEAD)

set -euo pipefail

if [ "$#" -gt 1 ]; then
    echo "usage: setup-line.sh [REV]" >&2
    exit 2
fi

rev="${1:-HEAD}"
if ! sha="$(git rev-parse --verify --quiet "$rev^{commit}")"; then
    echo "setup-line: cannot resolve $rev to a commit -- no line printed" >&2
    exit 1
fi

raw="https://raw.githubusercontent.com/pr0d1r2/nix-claude-code-cloud/$sha/setup.sh"
# shellcheck disable=SC2016 # printed for the UI shell to expand, not here
printf 'd=$(mktemp -d) && curl -fsSL %s -o "$d/setup.sh" && bash "$d/setup.sh" %s\n' "$raw" "$sha"
