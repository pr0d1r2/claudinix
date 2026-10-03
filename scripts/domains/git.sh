#!/usr/bin/env bash
# `domains` detector for git submodules (SPEC scripts:T27, I.cmd
# `domains`): the host of every `url` in .gitmodules, https or scp-like.
#
# Usage: git.sh PROJECT_DIR   -> `host<TAB>file` lines

set -euo pipefail

dir="${1:?usage: git.sh PROJECT_DIR}"
hosts="$(dirname "${BASH_SOURCE[0]}")/hosts.sh"

if [ -f "$dir/.gitmodules" ]; then
    grep -E '^[[:space:]]*url[[:space:]]*=' "$dir/.gitmodules" |
        bash "$hosts" .gitmodules || true
fi
