#!/usr/bin/env bash
# Bump the pinned Nix in setup.sh (SPEC T10, V11, C4): fetch the sha256
# releases.nixos.org publishes for that version's installer and rewrite
# the version and the default installer sha256 together, so they can
# only change in one commit. Runs nothing else: review the diff, run
# the gate, commit.
#
# Usage: bump-nix.sh VERSION   (e.g. 2.36.0)
# Env:   BUMP_SETUP         the setup.sh to rewrite (default: repo root)
#        NIX_RELEASES_URL   default https://releases.nixos.org/nix

set -euo pipefail

usage() {
    echo "usage: bump-nix.sh VERSION   (MAJOR.MINOR.PATCH, e.g. 2.36.0)" >&2
    exit 2
}

[ "$#" -eq 1 ] || usage
version="$1"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || usage

setup="${BUMP_SETUP:-$(dirname "${BASH_SOURCE[0]}")/../setup.sh}"
url="${NIX_RELEASES_URL:-https://releases.nixos.org/nix}/nix-$version/install.sha256"

fail() {
    echo "bump-nix: $* -- setup.sh not changed" >&2
    exit 1
}

version_re='^version=[0-9.]+$'
sha_re='^sha256="\$\{NIX_INSTALL_SHA256:-[0-9a-f]{64}\}"$'
[ "$(grep -cE "$version_re" "$setup")" = 1 ] || fail "$setup needs exactly one version= line"
[ "$(grep -cE "$sha_re" "$setup")" = 1 ] || fail "$setup needs exactly one default sha256 line"

body="$(curl -fsSL "$url")" || fail "could not fetch $url"
hash="$(tr -d '[:space:]' <<<"$body")"
[[ "$hash" =~ ^[0-9a-f]{64}$ ]] || fail "$url did not return one sha256 (64 hex)"
[ "$(wc -w <<<"$body")" -eq 1 ] || fail "$url did not return one sha256 (64 hex)"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
sed -E -e "s/$version_re/version=$version/" \
    -e "s/^(sha256=\"\\$\\{NIX_INSTALL_SHA256:-)[0-9a-f]{64}(\\}\")$/\\1$hash\\2/" \
    "$setup" >"$tmp"
cat "$tmp" >"$setup"
echo "bump-nix: setup.sh now pins Nix $version, installer sha256 $hash"
