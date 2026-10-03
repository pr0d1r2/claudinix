#!/usr/bin/env bash
# Prepare a cloud session working ON claudinix for its first commit
# (SPEC C27, T76). Run by the SessionStart hook in .claude/settings.json.
#
#   1. The cloud clone is shallow (C8): tdd-order refuses to judge it
#      (V29), so fetch the full history now, not at the first push.
#   2. `nix-dev -c true` (else `nix develop -c true`) enters the dev
#      shell once, which installs and wraps the hk git hooks (V17,
#      V32) before the first commit.
#
# Success is silence (V31). A problem is a warning on stdout, which the
# hook hands to the agent as context, and the session always starts:
# every path exits 0. Outside a cloud session (CLAUDE_CODE_REMOTE unset)
# it does nothing; direnv covers local work.
#
# Usage: session-start.sh

set -uo pipefail

warn() {
    echo "session-start: $1"
}

if [ "${CLAUDE_CODE_REMOTE:-}" != true ]; then
    exit 0
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    warn "not a git repository -- history and hooks not prepared"
    exit 0
fi

if [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = true ]; then
    if ! fetch_log="$(git fetch --quiet --unshallow 2>&1)"; then
        warn "the clone is still shallow, so tdd-order will refuse the push -- run: git fetch --unshallow"
        [ -z "$fetch_log" ] || printf '%s\n' "$fetch_log"
    fi
fi

if ! command -v nix >/dev/null 2>&1; then
    warn "nix not on PATH -- the dev shell was not entered, so the git hooks are not installed; run the claudinix setup, then: nix develop -c true"
    exit 0
fi

# nix-dev (installed by setup.sh) reaches the shell even when a github:
# input is not cached, where plain `nix develop` gets a 403 (C6).
if command -v nix-dev >/dev/null 2>&1; then
    enter=(nix-dev)
else
    enter=(nix develop)
fi
if ! develop_log="$("${enter[@]}" -c true 2>&1)"; then
    warn "${enter[*]} failed -- the git hooks may be missing; fix the shell, then run: ${enter[*]} -c true"
    printf '%s\n' "$develop_log"
fi

exit 0
