#!/usr/bin/env bash
# Install hk git hooks on every dev-shell entry (SPEC V17, T1).
# Never breaks the shell: every path exits 0, problems are warnings.
# Adapted from the owner's private infra repo (same author).

set -uo pipefail

# A hook enters this shell itself (see the wrap below). Reinstalling from
# inside it would be wasted time and noise on every commit.
if [ "${CLAUDINIX_HOOK:-}" = 1 ]; then
    exit 0
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "shell-hook: not a git repository -- hooks not installed" >&2
    exit 0
fi

if ! command -v hk >/dev/null 2>&1; then
    echo "shell-hook: hk not on PATH -- hooks not installed" >&2
    exit 0
fi

# Success is silence (V31): hk install reports every hook it writes, and
# that would print on every shell entry, gate run and agent command. Its
# output is shown only when it failed.
if ! install_log="$(hk install 2>&1)"; then
    [ -z "$install_log" ] || printf '%s\n' "$install_log" >&2
    echo "shell-hook: hk install failed -- hooks may be stale, run 'hk install' by hand" >&2
fi

# hk install writes `... || hk run <event> --from-hook`, which runs whatever
# hk and tools the calling shell happens to have. Wrap each hook so it
# enters this dev shell itself (V17). Already-wrapped commands are left
# alone; a wrap under an older env prefix (the project was renamed, T71)
# or the other shell entry is replaced whole, never nested. Two shells
# racing here meet git's config.lock: the loser warns.
#
# Where nix-dev is installed (every cloud session, by setup.sh) the hook
# enters the shell through it: plain `nix develop` 403s on an uncached
# github: input there (C6), and that would refuse every commit.
if command -v nix-dev >/dev/null 2>&1; then
    wrap="CLAUDINIX_HOOK=1 nix-dev -c hk run"
else
    wrap="CLAUDINIX_HOOK=1 nix develop -c hk run"
fi
old_wrap='[A-Za-z_][A-Za-z0-9_]*=1 nix(-dev| develop) -c hk run '
while read -r key value; do
    case "$value" in
    *"$wrap"*) continue ;;
    *"hk run "*) ;;
    *) continue ;;
    esac
    if [[ "$value" =~ $old_wrap ]]; then
        new="${value/"${BASH_REMATCH[0]}"/"$wrap "}"
    else
        new="${value/hk run /$wrap }"
    fi
    if ! git config --local "$key" "$new"; then
        echo "shell-hook: could not wrap $key -- enter the dev shell again" >&2
    fi
done < <(git config --local --get-regexp '^hook\.hk-.*\.command$' 2>/dev/null)

# Only git 2.54 or newer runs the config hooks above. A cloud session
# commits with the image's git, which may be older and then runs only
# `<hooks dir>/<event>` (V32, B9). Copy legacy-hook.sh there for each
# event; it runs the config hook's command under an older git and does
# nothing under a newer one. `--git-path hooks` honours core.hooksPath.
# A hook someone else put there is never overwritten: it is left alone
# with a warning. Ours (the marker line) and hk's own script shim, which
# runs hk outside the dev shell, are replaced when they differ.
template="${CLAUDINIX_LEGACY_HOOK:-$(git rev-parse --show-toplevel)/scripts/dev/legacy-hook.sh}"
if [ ! -f "$template" ]; then
    echo "shell-hook: $template not found -- a git older than 2.54 will run no gate hook here" >&2
    exit 0
fi
hooks_dir="$(git rev-parse --git-path hooks)"
for event in pre-commit commit-msg pre-push; do
    target="$hooks_dir/$event"
    if [ -e "$target" ]; then
        cmp -s "$template" "$target" && continue
        current="$(cat "$target")"
        # shellcheck disable=SC2016 # hk's shim text, matched literally
        hk_shim='#!/bin/sh
test "${HK:-1}" = "0" || exec hk run '"$event"' --from-hook "$@"'
        case "$current" in
        *claudinix-legacy-hook* | "$hk_shim") ;;
        *)
            echo "shell-hook: $target is not claudinix's, left alone -- a git older than 2.54 will not run the gate's $event hook" >&2
            continue
            ;;
        esac
    fi
    if ! { cat "$template" >"$target.claudinix-new" &&
        chmod +x "$target.claudinix-new" &&
        mv "$target.claudinix-new" "$target"; } 2>/dev/null; then
        rm -f "$target.claudinix-new"
        echo "shell-hook: could not write $target -- a git older than 2.54 will not run the gate's $event hook" >&2
    fi
done

exit 0
