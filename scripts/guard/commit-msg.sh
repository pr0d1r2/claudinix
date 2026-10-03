#!/usr/bin/env bash
# Commit message gate: Conventional Commits subject, a `Why:` line and a
# `Refs:` line naming the spec ids (SPEC C17, C21, AGENTS.md). The log is
# the reasoning audit trail. Every problem is reported in one block, with
# the allowed types and an example that passes, so one retry is enough.
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

types='feat fix docs test refactor chore ci build perf style revert'
problems=()

if ! printf '%s\n' "$subject" | grep -Eq "^(${types// /|})(\([a-z0-9._/-]+\))?!?: .+"; then
    problems+=("subject must follow Conventional Commits: <type>(<scope>): <summary>
    got: $subject
    types: $types")
fi

if ! printf '%s\n' "$body" | grep -q '^Why: '; then
    problems+=("body needs a 'Why: ...' line -- the reasoning is the audit trail (C21)")
fi

if ! printf '%s\n' "$body" | grep -q '^Refs: .'; then
    problems+=("body needs a 'Refs: ...' line naming the spec ids it touches, e.g. Refs: §T.19, §V.17")
fi

if [ "${#problems[@]}" -eq 0 ]; then
    exit 0
fi

{
    echo "commit-msg: the message was refused:"
    for problem in "${problems[@]}"; do
        echo "  - $problem"
    done
    echo "commit-msg: example:"
    echo "  | fix(setup): refuse a bad installer hash"
    echo "  |"
    echo "  | Why: a mismatched hash would run an unverified installer."
    echo "  | Refs: §T.2, §V.3"
} >&2
exit 1
