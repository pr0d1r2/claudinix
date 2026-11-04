#!/usr/bin/env bash
# The one shallow-clone refusal of the guards that read history
# (SPEC scripts:V29, B7). Source it; it defines functions only.
# tdd-order, context-limits and spec-ids call it.

set -euo pipefail

# require_full_history GUARD REASON: returns 0 in a full clone. In a shallow
# one it prints `GUARD: this clone is shallow -- REASON. run: git fetch
# --unshallow` to stderr and returns 1, so the caller exits rather than
# pass on history it cannot see.
require_full_history() {
    local guard="$1" reason="$2"
    if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
        echo "$guard: this clone is shallow -- $reason. run: git fetch --unshallow" >&2
        return 1
    fi
}
