#!/usr/bin/env bash
# Work through spec tasks one at a time, each built, reviewed, fixed up
# and merged under the strict rule, from your terminal (SPEC cloud:T161,
# cloud:V51, .:C29). Only the owner runs this.
#
# The tasks are the ones given (`node:Tn`, `root:Tn` for the root), else
# the open §T rows (status `.`) of every node but CLOUD_DRAIN_SKIP
# (`experiments`), without the open questions (a task starting with `?`),
# in node order. It runs from a clean `main` only, so every task starts from
# the merged state of the one before.
#
# --max caps how many tasks run. Its default is the owner's recent pace:
# the pull requests merged in the last CLOUD_DRAIN_PACE_DAYS (7) days that
# had a `Fixup:` reply by the owner or a member (cloud:B78), per day,
# rounded up, at least 1. gh lists only the pull requests with such a
# comment, at most CLOUD_DRAIN_PACE_LIMIT of them. When gh cannot count
# them, it exits 1 and asks for --max.
#
# One y/N answer names the tasks and the billed sessions (each task is
# one build, one review per role and one fixup); --yes skips only that
# question. --dry-run prints the plan instead. Then each task runs as
# `cloud-all.sh <task> --yes --merge`; the first that does not exit 0 (a
# failed step, red CI, or a stop for the owner) stops the drain, naming
# the task and how many finished.
#
# --prs drains open pull requests instead (cloud:T182): the ones given, in
# that order, else every open pull request of yours whose head is
# `claude/*`, oldest (lowest number) first. Each runs as
# `cloud-all.sh <PR> --yes --merge`, which picks its review tier (V66), so
# the plan counts the most sessions a council run bills: every review, up
# to 3 fixups and 2 rebases. gh lists at most CLOUD_DRAIN_PR_LIMIT; a list
# that long stops the drain. A pull request given twice is a usage error. It needs neither
# main nor a clean tree: no pull request builds on the local checkout, each
# is rebased onto main in the cloud when it conflicts (V52).
#
# Usage: cloud-drain.sh [node:Tn... | --prs [PR#|URL...]] [--max N] [--model M] [--yes] [--dry-run]
# Env:   CLAUDINIX_SCRIPTS  dir holding cloud-all.sh, review/ and config.sh

set -euo pipefail

usage() {
    echo "usage: cloud-drain.sh [node:Tn... | --prs [PR#|URL...]] [--max N] [--model M] [--yes] [--dry-run]" >&2
    exit 2
}

# shellcheck source=/dev/null # lib/cloud-launch.sh, beside this script
source "$(dirname "${BASH_SOURCE[0]}")/lib/cloud-launch.sh"

args=()
tasks=()
prs=0
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
    --prs) prs=1 ;;
    --yes) yes=1 ;;
    --dry-run) dry=1 ;;
    -*) usage ;;
    *) args+=("$1") ;;
    esac
    shift
done
# ${args[@]+...}: Bash 3.2 (macOS /bin/bash) calls an empty array unbound.
seen=" "
for a in ${args[@]+"${args[@]}"}; do
    if [ "$prs" = 1 ]; then
        cloud_parse_pr "$a" || usage
        # The same number twice would merge it, then fail on it.
        [[ "$seen" != *" $pr "* ]] || usage
        seen="$seen$pr "
    else
        cloud_parse_task "$a" || usage
    fi
    tasks+=("$a")
done

scripts_dir="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"

if [ "$prs" = 0 ]; then
    if [ "$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)" != main ]; then
        echo "drain: check out main first -- every task starts from the merged state of the one before" >&2
        exit 1
    fi
    if [ -n "$(git status --porcelain)" ]; then
        echo "drain: the work tree is not clean -- commit or stash first, so the merges can be pulled in" >&2
        exit 1
    fi
    top="$(git rev-parse --show-toplevel)"
fi

cloud_resolve_model "$scripts_dir" || exit "$?"
roles="$(cloud_role_count drain "$scripts_dir")" || exit 1
per_task="$(cloud_session_count "$roles")"
# A pull request: no build, but up to 2 rebases (before CI and after the
# fixup) and 2 more fixups while CodeRabbit threads wait (cloud:T182).
[ "$prs" = 0 ] || per_task="$(($(cloud_session_count "$roles" pr) + 4))"
what=tasks

if [ "$prs" = 1 ]; then
    what="pull requests"
    if [ "${#tasks[@]}" -eq 0 ]; then
        # </dev/null: gh must not share the terminal the y/N answer comes from (cloud:B19).
        if ! open="$(gh pr list --state open --author @me --limit "$CLOUD_DRAIN_PR_LIMIT" --json number,headRefName </dev/null)"; then
            echo "drain: gh could not list your open pull requests -- check gh auth status, or name them: --prs PR..." >&2
            exit 1
        fi
        # A full page may hide more: never drain part of them unasked.
        if [ "$(jq length <<<"$open")" -ge "$CLOUD_DRAIN_PR_LIMIT" ]; then
            echo "drain: gh listed $CLOUD_DRAIN_PR_LIMIT or more open pull requests of yours, the most it asks for -- name them: --prs PR..." >&2
            exit 1
        fi
        while IFS= read -r n; do
            tasks+=("$n")
        done < <(jq -r '[.[] | select(.headRefName | startswith("claude/")) | .number] | sort[]' <<<"$open")
    fi
elif [ "${#tasks[@]}" -eq 0 ]; then
    while IFS= read -r node; do
        [[ " ${CLOUD_DRAIN_SKIP[*]} " != *" $node "* ]] || continue
        label="$node"
        [ "$node" != . ] || label=root
        while IFS= read -r t; do
            tasks+=("$label:$t")
        done < <(spec_open_tasks "$top/$(cloud_spec_of "$node")")
    done < <(cloud_nodes "$top/SPEC.md")
fi
total="${#tasks[@]}"
if [ "$total" -eq 0 ] && [ "$prs" = 1 ]; then
    echo "drain: nothing to do -- no open claude/* pull request of yours"
    exit 0
fi
if [ "$total" -eq 0 ]; then
    echo "drain: nothing to do -- no open task outside ${CLOUD_DRAIN_SKIP[*]} that is not an open question"
    exit 0
fi

if [ -z "$max" ]; then
    since="$(date -u -d "$CLOUD_DRAIN_PACE_DAYS days ago" +%F 2>/dev/null || date -u -v-"$CLOUD_DRAIN_PACE_DAYS"d +%F)"
    # </dev/null: gh must not share the terminal the y/N answer comes from (cloud:B19).
    if ! merged="$(gh pr list --state merged --search "merged:>=$since \"$CLOUD_FIXUP_HEADING\" in:comments" --limit "$CLOUD_DRAIN_PACE_LIMIT" --json number,comments </dev/null)"; then
        echo "drain: gh could not count the pull requests merged since $since -- pass --max N" >&2
        exit 1
    fi
    fixed="$(jq --arg h "$CLOUD_FIXUP_HEADING_RE" '[.[] | select(any(.comments[]?; (.authorAssociation == "OWNER" or .authorAssociation == "MEMBER") and (.body | test($h))))] | length' <<<"$merged")"
    max=$(((fixed + CLOUD_DRAIN_PACE_DAYS - 1) / CLOUD_DRAIN_PACE_DAYS))
    [ "$max" -ge 1 ] || max=1
fi

run=("${tasks[@]:0:max}")
names=("${run[@]}")
sessions="$((${#run[@]} * per_task)) billed"
if [ "$prs" = 1 ]; then
    pr= # set by cloud_parse_pr
    names=()
    for a in "${run[@]}"; do
        cloud_parse_pr "$a"
        names+=("#$pr")
    done
    sessions="at most $sessions"
fi
plan="drain: ${names[*]} (${#run[@]} of $total $what): ${#run[@]} × just all --merge, $sessions Claude Code cloud sessions (model $model), one after another; it stops at the first failure"
if [ "$dry" = 1 ]; then
    echo "$plan"
    exit 0
fi
if [ "$yes" = 0 ]; then
    cloud_flush_input
    cloud_confirm drain "$plan. Start? [y/N] " || exit 1
fi

done_count=0
for i in "${!run[@]}"; do
    if ! "$scripts_dir/cloud-all.sh" "${run[i]}" --yes --merge --model "$model"; then
        echo "drain: stopped at ${names[i]}; $done_count of ${#run[@]} done" >&2
        exit 1
    fi
    done_count=$((done_count + 1))
done
echo "drain: done, $done_count of ${#run[@]}"
