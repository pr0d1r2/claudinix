#!/usr/bin/env bash
# Work through spec tasks one at a time, each built, reviewed, fixed up
# and merged under the strict rule, from your terminal (SPEC cloud:T161,
# cloud:V51, .:C29). Only the owner runs this.
#
# The tasks are the ones given (`node:Tn`, `root:Tn` for the root), else
# the open §T rows (status `.`) of every node but `experiments`, without
# the open questions (a task starting with `?`), in node order. It runs
# from a clean `main` only, so every task starts from the merged state of
# the one before.
#
# --max caps how many tasks run. Its default is the owner's recent pace:
# the pull requests merged in the last 7 days that had a `Fixup:` reply by
# the owner or a member (cloud:B78),
# per day, rounded up, at least 1. When gh cannot count them, it exits 1
# and asks for --max.
#
# One y/N answer names the tasks and the billed sessions (each task is
# one build, one review per role and one fixup); --yes skips only that
# question. --dry-run prints the plan instead. Then each task runs as
# `cloud-all.sh <task> --yes --merge`; the first that does not exit 0 (a
# failed step, red CI, or a stop for the owner) stops the drain, naming
# the task and how many finished.
#
# Usage: cloud-drain.sh [node:Tn...] [--max N] [--model M] [--yes] [--dry-run]
# Env:   CLAUDINIX_SCRIPTS  dir holding cloud-all.sh, review/ and config.sh

set -euo pipefail

usage() {
    echo "usage: cloud-drain.sh [node:Tn...] [--max N] [--model M] [--yes] [--dry-run]" >&2
    exit 2
}

# shellcheck source=/dev/null # lib/cloud-launch.sh, beside this script
source "$(dirname "${BASH_SOURCE[0]}")/lib/cloud-launch.sh"

tasks=()
max=
model=
yes=0
dry=0
while [ "$#" -gt 0 ]; do
    case "$1" in
    --max)
        [ "$#" -ge 2 ] || usage
        [[ "$2" =~ ^[1-9][0-9]*$ ]] || usage
        max="$2"
        shift
        ;;
    --model)
        [ "$#" -ge 2 ] || usage
        model="$2"
        shift
        ;;
    --yes) yes=1 ;;
    --dry-run) dry=1 ;;
    -*) usage ;;
    *)
        cloud_parse_task "$1" || usage
        tasks+=("$1")
        ;;
    esac
    shift
done

scripts_dir="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"
top="$(git rev-parse --show-toplevel)"

if [ "$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)" != main ]; then
    echo "drain: check out main first -- every task starts from the merged state of the one before" >&2
    exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
    echo "drain: the work tree is not clean -- commit or stash first, so the merges can be pulled in" >&2
    exit 1
fi

cloud_resolve_model "$scripts_dir" || exit "$?"
roles=0
while IFS= read -r _; do
    roles=$((roles + 1))
done < <(cloud_roles "$scripts_dir/review")
if [ "$roles" -eq 0 ]; then
    echo "drain: no review roles in $scripts_dir/review -- add one (ROLE.md) first" >&2
    exit 1
fi
per_task="$(cloud_session_count "$roles")"

# open_tasks NODE: the open, non-question task ids of NODE's spec.
open_tasks() {
    awk -F'|' '
        /^## / { in_t = ($2 == "§T" || $0 ~ /^## §T /); next }
        in_t && $1 ~ /^T[0-9]+$/ && $2 == "." && $3 !~ /^\?/ { print $1 }
    ' "$top/$(cloud_spec_of "$1")"
}

if [ "${#tasks[@]}" -eq 0 ]; then
    while IFS= read -r node; do
        [ "$node" != experiments ] || continue
        label="$node"
        [ "$node" != . ] || label=root
        while IFS= read -r t; do
            tasks+=("$label:$t")
        done < <(open_tasks "$node")
    done < <(cloud_nodes "$top/SPEC.md")
fi
total="${#tasks[@]}"
if [ "$total" -eq 0 ]; then
    echo "drain: nothing to do -- no open task outside experiments that is not an open question"
    exit 0
fi

if [ -z "$max" ]; then
    since="$(date -u -d '7 days ago' +%F 2>/dev/null || date -u -v-7d +%F)"
    # </dev/null: gh must not share the terminal the y/N answer comes from (cloud:B19).
    if ! merged="$(gh pr list --state merged --search "merged:>=$since" --limit 200 --json number,comments </dev/null)"; then
        echo "drain: gh could not count the pull requests merged since $since -- pass --max N" >&2
        exit 1
    fi
    fixed="$(jq --arg h "^#* *$CLOUD_FIXUP_HEADING" '[.[] | select(any(.comments[]?; (.authorAssociation == "OWNER" or .authorAssociation == "MEMBER") and (.body | test($h))))] | length' <<<"$merged")"
    max=$(((fixed + 6) / 7))
    [ "$max" -ge 1 ] || max=1
fi

run=("${tasks[@]:0:max}")
plan="drain: ${run[*]} (${#run[@]} of $total tasks): ${#run[@]} × just all --merge, $((${#run[@]} * per_task)) billed Claude Code cloud sessions (model $model), one after another; it stops at the first failure"
if [ "$dry" = 1 ]; then
    echo "$plan"
    exit 0
fi
if [ "$yes" = 0 ]; then
    cloud_flush_input
    cloud_confirm drain "$plan. Start? [y/N] " || exit 1
fi

done_count=0
for task in "${run[@]}"; do
    if ! "$scripts_dir/cloud-all.sh" "$task" --yes --merge --model "$model"; then
        echo "drain: stopped at $task; $done_count of ${#run[@]} done" >&2
        exit 1
    fi
    done_count=$((done_count + 1))
done
echo "drain: done, $done_count of ${#run[@]}"
