#!/usr/bin/env bash
# Probe a target project in a fresh cloud session, from your terminal
# (SPEC scripts:T28, I.cmd `probe`, .:T3, C8).
#
# Starts one session with `claude --cloud TASK --model M` (the task right
# after --cloud: --model first fails, probe 7). claude needs a TTY there,
# so it runs under `script`. The task is probe-prompt.txt followed by
# probe.sh; the session pushes its report on a `claude/nix-probe` branch,
# to which the harness adds a random suffix. This waits for that new
# branch, then prints the report on it. A session cannot delete branches,
# so --cleanup deletes every `claude/nix-probe*` branch on the remote.
# Follow-ups go through `claude -p MSG --cloud ID` (no TTY needed).
#
# Usage: probe-launch.sh [--model M] [--cleanup]   (default model: sonnet)
# Env:   PROBE_REMOTE        remote the session pushes to (default origin)
#        PROBE_POLL_SECONDS  wait between branch checks (default 20)
#        PROBE_POLL_TRIES    checks before giving up (default 90: 30 min)
#        PROBE_SCRIPT        probe.sh to send (default: beside scripts/)
#        NCCC_SCRIPTS        dir holding probe-prompt.txt (default: here)

set -euo pipefail

usage() {
    echo "usage: probe-launch.sh [--model M] [--cleanup]" >&2
    exit 2
}

model=sonnet
cleanup=0
while [ "$#" -gt 0 ]; do
    case "$1" in
    --model)
        [ "$#" -ge 2 ] || usage
        model="$2"
        shift
        ;;
    --cleanup) cleanup=1 ;;
    *) usage ;;
    esac
    shift
done

lib="${NCCC_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"
probe="${PROBE_SCRIPT:-$lib/../probe.sh}"
remote="${PROBE_REMOTE:-origin}"
poll="${PROBE_POLL_SECONDS:-20}"
tries="${PROBE_POLL_TRIES:-90}"
prefix=claude/nix-probe
report=nix-probe-report.txt

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "probe: not inside a git work tree -- run it from the project the session clones" >&2
    exit 1
fi

# The remote's probe branches, one per line.
branches() {
    git ls-remote --heads "$remote" "refs/heads/$prefix*" | while read -r _ ref; do
        echo "${ref#refs/heads/}"
    done
}

if [ "$cleanup" = 1 ]; then
    old=()
    while IFS= read -r name; do
        old+=("$name")
    done < <(branches)
    if [ "${#old[@]}" -eq 0 ]; then
        echo "probe: no $prefix* branch on $remote"
        exit 0
    fi
    git push "$remote" --delete "${old[@]}"
    echo "probe: deleted ${old[*]}"
    exit 0
fi

task="$(cat "$lib/probe-prompt.txt" "$probe")"
before="$(branches)"

# util-linux `script` takes the command as a string, BSD `script` as
# arguments; both get a TTY for claude. The string reads the task from the
# environment, so no quoting of it is needed.
if script --version >/dev/null 2>&1; then
    # shellcheck disable=SC2016 # script's shell expands these, not this one
    PROBE_TASK="$task" PROBE_MODEL="$model" script -q -e \
        -c 'claude --cloud "$PROBE_TASK" --model "$PROBE_MODEL"' /dev/null
else
    script -q /dev/null claude --cloud "$task" --model "$model"
fi

branch=
for _ in $(seq "$tries"); do
    while IFS= read -r name; do
        if ! grep -qxF -- "$name" <<<"$before"; then
            branch="$name"
        fi
    done < <(branches)
    [ -z "$branch" ] || break
    sleep "$poll"
done

if [ -z "$branch" ]; then
    echo "probe: no new $prefix* branch on $remote after $tries checks -- see the session at claude.ai/code" >&2
    exit 1
fi

echo "probe: branch $branch"
git fetch -q "$remote" "refs/heads/$branch"
if ! git show "FETCH_HEAD:$report"; then
    echo "probe: $branch has no $report -- see the session at claude.ai/code" >&2
    exit 1
fi
