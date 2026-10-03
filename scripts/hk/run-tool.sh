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

if ! command -v "$tool" >/dev/null 2>&1; then
    echo "hk: $tool is not on PATH -- gate could not run, nothing was checked. Enter the dev shell (direnv reload, or nix develop)." >&2
    exit 1
fi

# exec so the tool owns the process: its exit code, output and signals.
exec "$tool" "$@"
