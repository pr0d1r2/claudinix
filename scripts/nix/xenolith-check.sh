#!/usr/bin/env bash
# `checks.<sys>.xenolith`: run `xnl check` over the flake's source and
# create the derivation's output only when it is clean (SPEC C15, T20).
#
# Usage: xenolith-check.sh SOURCE_DIR OUT

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: xenolith-check.sh SOURCE_DIR OUT" >&2
    exit 2
fi

cd "$1"
xnl check .
touch "$2"
