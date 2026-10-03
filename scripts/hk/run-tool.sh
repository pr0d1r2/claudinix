#!/usr/bin/env bash
# Run one gate tool, refusing loudly when it is not installed (SPEC V18).
#
# A tool that is MISSING checked nothing, while a tool that RAN and failed
# found something. Collapse the two and a machine with half the toolchain
# reports a clean repo. Adapted from pr0d1r2/xenolith scripts/hk/run-tool.sh.
#
# Usage: run-tool.sh TOOL [ARG...]

set -euo pipefail

if [ "$#" -eq 0 ]; then
    echo "usage: run-tool.sh TOOL [ARG...]" >&2
    exit 2
fi

tool="$1"
shift

# Inside the dev shell (nix sets IN_NIX_SHELL) "enter the dev shell" is
# advice the caller already followed: the shell itself lacks the tool.
if ! command -v "$tool" >/dev/null 2>&1; then
    if [ -n "${IN_NIX_SHELL:-}" ]; then
        echo "hk: $tool is missing from the dev shell -- add it to nix/dev-shell.nix; gate could not run, nothing was checked." >&2
    else
        echo "hk: $tool is not on PATH -- gate could not run, nothing was checked. Enter the dev shell (direnv reload, or nix develop)." >&2
    fi
    exit 1
fi

# exec so the tool owns the process: its exit code, output and signals.
exec "$tool" "$@"
