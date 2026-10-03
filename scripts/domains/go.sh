#!/usr/bin/env bash
# `domains` detector for Go (SPEC scripts:T27, I.cmd `domains`): a go.sum
# means modules come from the Go module proxy and are checked against
# the checksum database.
#
# Usage: go.sh PROJECT_DIR   -> `host<TAB>file` lines

set -euo pipefail

dir="${1:?usage: go.sh PROJECT_DIR}"

if [ -f "$dir/go.sum" ]; then
    printf '%s\t%s\n' proxy.golang.org go.sum sum.golang.org go.sum
fi
