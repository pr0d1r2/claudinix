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
# is replaced whole, never nested. Two shells racing here meet git's
# config.lock: the loser warns.
wrap="CLAUDINIX_HOOK=1 nix develop -c hk run"
old_wrap='[A-Za-z_][A-Za-z0-9_]*=1 nix develop -c hk run '
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

exit 0
