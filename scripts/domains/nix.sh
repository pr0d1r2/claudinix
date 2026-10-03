#!/usr/bin/env bash
# `domains` detector for Nix (SPEC scripts:T27, I.cmd `domains`).
#
# flake.nix: the substituters its `nixConfig` adds, which a session uses
# because setup.sh sets accept-flake-config (.:V25). flake.lock: the host
# of every input that is neither `github` (those go through the GitHub
# proxy, see `inputs`) nor a local path: git and tarball URLs, gitlab,
# sourcehut.
#
# Usage: nix.sh PROJECT_DIR   -> `host<TAB>file` lines

set -euo pipefail

dir="${1:?usage: nix.sh PROJECT_DIR}"
hosts="$(dirname "${BASH_SOURCE[0]}")/hosts.sh"

# The lines of every `substituters = ...;` assignment, which may span
# lines as a list; comments (from `#` on) and input URLs elsewhere are
# left out.
substituters() {
    local line inside=0 assign='substituters[[:space:]]*='
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        if [[ "$line" =~ $assign ]]; then
            inside=1
        fi
        if [ "$inside" = 1 ]; then
            printf '%s\n' "$line"
            case "$line" in
            *";"*) inside=0 ;;
            esac
        fi
    done <"$1"
}

if [ -f "$dir/flake.nix" ]; then
    substituters "$dir/flake.nix" | bash "$hosts" flake.nix
fi

if [ -f "$dir/flake.lock" ]; then
    jq -r '.nodes[] | .locked // empty
        | select(.type != "github" and .type != "path" and .type != "indirect")
        | .url // ("https://" + (.host // {gitlab: "gitlab.com", sourcehut: "git.sr.ht"}[.type] // empty))' \
        "$dir/flake.lock" | bash "$hosts" flake.lock
fi
