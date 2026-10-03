#!/usr/bin/env bash
# claudinix-legacy-hook: the gate's git hook for git older than 2.54
# (SPEC V32, B9, T86). This marker line tells shell-hook.sh the copy is
# its own to refresh.
#
# hk installs config-based hooks (`hook.hk-<event>.command`), and only
# git 2.54 or newer runs those. A cloud session commits with the image's
# own git, outside the dev shell, and an older git runs nothing but
# `<hooks dir>/<event>`. scripts/dev/shell-hook.sh copies this file there
# under each event's name, and it runs the very command the config hook
# holds, read at run time, so every git runs the same gate.
#
# git 2.54 or newer runs this file too, after the config hook: then it
# does nothing, so the gate never runs twice. Under an older git a
# missing config hook or an unreadable version refuses: a gate that could
# not run is a failure, not a pass.
#
# Usage: <hooks dir>/<event> [ARGS...]   (run by git; stdin passed on)

set -euo pipefail

event="${0##*/}"

# git puts its own exec dir first on a hook's PATH, so this is the git
# that is committing, not whichever one a shell would find first.
version="$(git --version)"
version="${version#git version }"
major="${version%%.*}"
minor="${version#"$major".}"
minor="${minor%%[!0-9]*}"
case "$major" in
"" | *[!0-9]*) minor="" ;;
esac
if [ -z "$minor" ]; then
    echo "claudinix hook: cannot read the git version from '$(git --version)', so the $event gate did not run" >&2
    exit 1
fi
if [ "$major" -gt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -ge 54 ]; }; then
    exit 0
fi

if ! command="$(git config --get "hook.hk-$event.command")"; then
    echo "claudinix hook: git config has no hook.hk-$event.command, so the $event gate cannot run -- enter the dev shell once (nix develop -c true), then try again" >&2
    exit 1
fi

# The way git runs a config hook: the command through sh, git's
# arguments after it.
exec sh -c "$command"' "$@"' "$command" "$@"
