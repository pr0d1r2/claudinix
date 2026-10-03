#!/usr/bin/env bash
# Probe a Claude Code cloud session (SPEC T3, I.file, C8): print the
# session facts and the health of Nix, one `key: value` line per check.
#
# Facts are always printed. A failed health check prints `FAIL ...` and
# makes the exit status 1, after every other check has still run. A
# refused `github:` fetch is expected in the cloud (C6) and only reported.
#
# Usage: probe.sh
# Seams: PROC_DIR, SYSTEMD_DIR, CACHIX_URL, CHANNELS_URL,
#        PROBE_STOREPATH (a locked input's store path pushed to cachix).

set -euo pipefail

start=$(date +%s)
proc_dir="${PROC_DIR:-/proc}"
systemd_dir="${SYSTEMD_DIR:-/run/systemd/system}"
cachix_url="${CACHIX_URL:-https://pr0d1r2.cachix.org}"
channels_url="${CHANNELS_URL:-https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz}"
status=0

report() {
    echo "$1: $2"
}

fail() {
    echo "$1: FAIL $2"
    status=1
}

# HTTP status of a HEAD request, following redirects; 000 when unreachable.
http_code() {
    curl -s -o /dev/null -I -L -w '%{http_code}' "$1" || true
}

report id "$(id)"
report pid1 "$(cat "$proc_dir/1/comm" 2>/dev/null || echo unknown)"
if [ -d "$systemd_dir" ]; then
    report systemd yes
else
    report systemd no
fi
if unshare -Ur true 2>/dev/null; then
    report unshare ok
else
    report unshare refused
fi

# V1: nix must resolve in a shell that sourced no profile.
if nix_path="$(command -v nix)"; then
    report nix-path "$nix_path"
    report nix-version "$(nix --version)"
    subs="$(nix config show substituters 2>/dev/null || true)"
    case " $subs " in
    *" $cachix_url "* | *" $cachix_url/ "*) report substituters ok ;;
    *) fail substituters "no $cachix_url in: $subs" ;;
    esac
    if nix flake metadata github:NixOS/nixpkgs >/dev/null 2>&1; then
        report github-fetch ok
    else
        report github-fetch refused
    fi
else
    fail nix-path "nix is not on PATH without sourcing a profile"
fi

code="$(http_code "$cachix_url/nix-cache-info")"
if [ "$code" = 200 ]; then
    report cachix ok
else
    fail cachix "HTTP $code from $cachix_url"
fi

code="$(http_code "$channels_url")"
if [ "$code" = 200 ]; then
    report channels ok
else
    fail channels "HTTP $code from $channels_url"
fi

# V8: a locked input substitutes from cachix by its store path, with no
# GitHub fetch at all.
if [ -n "${PROBE_STOREPATH:-}" ]; then
    base="${PROBE_STOREPATH#/nix/store/}"
    code="$(http_code "$cachix_url/${base%%-*}.narinfo")"
    if [ "$code" = 200 ]; then
        report cachix-input ok
    else
        fail cachix-input "HTTP $code for $PROBE_STOREPATH"
    fi
else
    report cachix-input "skip (set PROBE_STOREPATH)"
fi

# V13: which failover tier nix-dev reached on the flake in this directory.
if command -v nix-dev >/dev/null 2>&1 && [ -f flake.nix ]; then
    tier="$(nix-dev --command true 2>&1 | grep -o 'tier [0-9]' | tail -n 1 || true)"
    report nix-dev "${tier:-no tier logged}"
else
    report nix-dev "skip (needs nix-dev and a flake.nix here)"
fi

report elapsed "$(($(date +%s) - start))s"
exit "$status"
