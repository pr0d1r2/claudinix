#!/usr/bin/env bash
# `domains` detector for JavaScript (SPEC scripts:T27, I.cmd `domains`):
# the hosts packages are `resolved` from (or pnpm's `tarball`) in
# package-lock.json, yarn.lock and pnpm-lock.yaml. Other URLs in them
# (homepage, funding) are never fetched, so they are left out.
#
# Usage: npm.sh PROJECT_DIR   -> `host<TAB>file` lines

set -euo pipefail

dir="${1:?usage: npm.sh PROJECT_DIR}"
hosts="$(dirname "${BASH_SOURCE[0]}")/hosts.sh"

for file in package-lock.json yarn.lock pnpm-lock.yaml; do
    if [ -f "$dir/$file" ]; then
        grep -E 'resolved|tarball' "$dir/$file" | bash "$hosts" "$file" || true
    fi
done
