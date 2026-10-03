#!/usr/bin/env bash
# `domains` detector for Rust (SPEC scripts:T27, I.cmd `domains`).
#
# A project with Cargo.lock or Cargo.toml needs crates.io's sparse index
# and its download host (probe 4), plus the host of every git dependency,
# alternative registry and `[source]` replacement it names. Cargo.lock
# records crates.io itself as `registry+https://github.com/rust-lang/
# crates.io-index`, which cargo reads through index.crates.io, so that
# line is not a host of its own.
#
# Usage: cargo.sh PROJECT_DIR   -> `host<TAB>file` lines

set -euo pipefail

dir="${1:?usage: cargo.sh PROJECT_DIR}"
hosts="$(dirname "${BASH_SOURCE[0]}")/hosts.sh"
crates_io='registry+https://github.com/rust-lang/crates.io-index'

for file in Cargo.lock Cargo.toml; do
    if [ -f "$dir/$file" ]; then
        printf '%s\t%s\n' index.crates.io "$file" static.crates.io "$file"
        break
    fi
done

if [ -f "$dir/Cargo.lock" ]; then
    grep -E '^source = ' "$dir/Cargo.lock" | grep -vF "$crates_io" |
        bash "$hosts" Cargo.lock || true
fi

for file in Cargo.toml .cargo/config.toml .cargo/config; do
    if [ -f "$dir/$file" ]; then
        grep -E '(git|registry|index)[[:space:]]*=' "$dir/$file" |
            bash "$hosts" "$file" || true
    fi
done
