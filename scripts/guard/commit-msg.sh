#!/usr/bin/env bash
# Commit message gate: Conventional Commits subject + a `Why:` line
# (SPEC C17, C21). The log is the reasoning audit trail.
# Vendored from the owner's private infra repo (same author)
# (SPEC C17: no flake export exists); keep in step by hand.
# Usage: commit-msg.sh [message_file]   (default: .git/COMMIT_EDITMSG)

set -euo pipefail

msg_file="${1:-}"
if [ -z "$msg_file" ]; then
    msg_file="$(git rev-parse --git-path COMMIT_EDITMSG)"
fi

if [ ! -f "$msg_file" ]; then
    echo "commit-msg: message file not found: $msg_file" >&2
    exit 2
fi

body="$(grep -v '^#' "$msg_file" || true)"
subject="$(printf '%s\n' "$body" | sed -n '1p')"

case "$subject" in
"Merge "* | "Revert "* | "fixup! "* | "squash! "* | "amend! "*)
    exit 0
    ;;
esac

types='feat|fix|docs|test|refactor|chore|ci|build|perf|style|revert'
if ! printf '%s\n' "$subject" | grep -Eq "^($types)(\([a-z0-9._/-]+\))?!?: .+"; then
    echo "commit-msg: subject must follow Conventional Commits: <type>(<scope>): <summary>" >&2
    echo "commit-msg: got: $subject" >&2
    exit 1
fi

if ! printf '%s\n' "$body" | grep -q '^Why: '; then
    echo "commit-msg: body needs a 'Why: ...' line -- the reasoning is the audit trail (C21)" >&2
    exit 1
fi
