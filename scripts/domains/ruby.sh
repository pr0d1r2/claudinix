#!/usr/bin/env bash
# `domains` detector for Ruby (SPEC scripts:T27, I.cmd `domains`): the
# host of every `remote:` in Gemfile.lock (gem sources and git gems).
#
# Usage: ruby.sh PROJECT_DIR   -> `host<TAB>file` lines

set -euo pipefail

dir="${1:?usage: ruby.sh PROJECT_DIR}"
hosts="$(dirname "${BASH_SOURCE[0]}")/hosts.sh"

if [ -f "$dir/Gemfile.lock" ]; then
    grep -E '^[[:space:]]*remote:' "$dir/Gemfile.lock" |
        bash "$hosts" Gemfile.lock || true
fi
