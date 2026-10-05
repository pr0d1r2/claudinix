#!/usr/bin/env bash
# Build one spec task in a fresh cloud session, from your terminal
# (SPEC .:T100, .:C29: 1 task = 1 cloud session, launched from a laptop).
#
# TASK is `Tn` or `node:Tn`. A bare `Tn` is looked up in the spec of
# every node the root SPEC.md §F lists, plus the root itself (`.`, also
# spelled `root`); `node:Tn` looks only in that node's SPEC.md. Exactly
# one row `Tn|.|...` must match: a missing row, a done (`x`) or in
# progress (`~`) one, or an id found in more than one node is refused,
# naming TASK as given (scripts:V26).
#
# Before a session starts, as probe-launch.sh (scripts:T81): the remote
# must exist, the current branch must be pushed and equal to its upstream
# (the session clones GitHub, not this disk), and a y/N answer must
# confirm that a billed cloud session starts; --yes skips only that
# question. --dry-run runs the same checks, then prints the exact claude
# command (shell-quoted, pasteable) instead of asking or launching.
#
# The model: --model, else the project's .claudinix.toml session.model
# (scripts/config.sh, scripts:V34), else sonnet. A bad file exits 2
# before anything starts.
#
# The prompt is cloud-task-prompt.txt with @CI_WATCH@ (the shared
# cloud-ci-watch-prompt.txt, scripts:T142), @TASK@, @NODE@, @BRANCH@ and
# @TASK_TEXT@ (the spec row as written) filled in. The session pushes
# `claude/<node>-<task>` (`root` for the root node), to which the harness
# may add a suffix, and opens a pull request into main (scripts:T124);
# it never merges. claude runs as `claude --cloud PROMPT --model M`: the
# prompt right after --cloud, since --model first fails with "--cloud
# requires a description" (probe 7). It needs a TTY there, so it runs
# under `script`. This does not wait for the session (a build outlasts a
# probe); follow it at claude.ai/code.
#
# Usage: cloud-task.sh <node:Tn | Tn> [--model M] [--yes] [--dry-run]
# Env:   CLOUD_TASK_REMOTE  remote that must hold the branch (default origin)
#        CLAUDINIX_SCRIPTS  dir holding cloud-task-prompt.txt and config.sh
#                           (default: here)

set -euo pipefail

usage() {
    echo "usage: cloud-task.sh <node:Tn | Tn> [--model M] [--yes] [--dry-run]" >&2
    exit 2
}

arg=
model=
yes=0
dry=0
while [ "$#" -gt 0 ]; do
    case "$1" in
    --model)
        [ "$#" -ge 2 ] || usage
        model="$2"
        shift
        ;;
    --yes) yes=1 ;;
    --dry-run) dry=1 ;;
    -*) usage ;;
    *)
        [ -z "$arg" ] || usage
        arg="$1"
        ;;
    esac
    shift
done
[ -n "$arg" ] || usage

lib="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"
# shellcheck source=/dev/null # lib/cloud-launch.sh, beside this script
source "$(dirname "${BASH_SOURCE[0]}")/lib/cloud-launch.sh"
want_node= # set by cloud_parse_task
id=
if ! cloud_parse_task "$arg"; then
    echo "cloud: bad task $arg -- want Tn or node:Tn (e.g. T100, scripts:T98)" >&2
    exit 2
fi
[ "$want_node" != root ] || want_node=.
remote="${CLOUD_TASK_REMOTE:-origin}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "cloud: not inside a git work tree -- run it from the project the session clones" >&2
    exit 1
fi
top="$(git rev-parse --show-toplevel)"
if [ ! -f "$top/SPEC.md" ]; then
    echo "cloud: no SPEC.md at $top -- the tasks live in the project's spec" >&2
    exit 1
fi

# The nodes: the root, then every dir of the root's §F table.
nodes=(.)
while IFS= read -r dir; do
    nodes+=("$dir")
done < <(awk '/^## / { f = ($2 == "§F") } f && /\|/ && !/^dir\|/ { split($0, a, "|"); print a[1] }' "$top/SPEC.md")

# spec_of NODE: the node's SPEC.md, relative to the top.
spec_of() {
    if [ "$1" = . ]; then echo SPEC.md; else echo "$1/SPEC.md"; fi
}

search=("${nodes[@]}")
if [ -n "$want_node" ]; then
    known=0
    for n in "${nodes[@]}"; do
        [ "$n" != "$want_node" ] || known=1
    done
    if [ "$known" = 0 ]; then
        echo "cloud: no node $want_node in SPEC.md §F (nodes: ${nodes[*]})" >&2
        exit 1
    fi
    search=("$want_node")
fi

hit_nodes=()
hit_rows=()
for n in "${search[@]}"; do
    file="$top/$(spec_of "$n")"
    [ -f "$file" ] || continue
    while IFS= read -r row; do
        hit_nodes+=("$n")
        hit_rows+=("$row")
    done < <(grep -E "^$id\|" "$file" || true)
done

if [ "${#hit_rows[@]}" -eq 0 ]; then
    if [ -n "$want_node" ]; then
        echo "cloud: no task $arg in $(spec_of "$want_node")" >&2
    else
        echo "cloud: no task $arg in any node's SPEC.md (${nodes[*]})" >&2
    fi
    exit 1
fi
if [ "${#hit_rows[@]}" -gt 1 ]; then
    echo "cloud: $arg is in more than one node (${hit_nodes[*]}) -- name one, e.g. ${hit_nodes[0]}:$id" >&2
    exit 1
fi
node="${hit_nodes[0]}"
row="${hit_rows[0]}"
spec="$(spec_of "$node")"
rest="${row#*|}"
state="${rest%%|*}"
case "$state" in
.) ;;
x)
    echo "cloud: $arg is done (x) in $spec -- nothing to build" >&2
    exit 1
    ;;
'~')
    echo "cloud: $arg is in progress (~) in $spec -- finish or reset it first" >&2
    exit 1
    ;;
*)
    echo "cloud: $arg has status $state in $spec, not . (open) -- nothing to build" >&2
    exit 1
    ;;
esac

cloud_require_remote cloud "$remote" || exit 1
current= # set by cloud_require_pushed_branch
cloud_require_pushed_branch cloud "$remote" || exit 1
# The project's .claudinix.toml (scripts:V34): flag > file > sonnet,
# config.sh supplying sonnet when there is no file.
cloud_resolve_model "$lib" || exit "$?"

branch_name="$(cloud_branch_name "$node" "$id")"
branch="$(printf '%q' "$branch_name")"

# The row goes in last, so a placeholder spelled inside it is not filled.
prompt="$(cat "$lib/cloud-task-prompt.txt")"
cloud_fill @CI_WATCH@ "$(cat "$lib/cloud-ci-watch-prompt.txt")"
cloud_fill @TASK@ "$id"
cloud_fill @NODE@ "$node"
cloud_fill @BRANCH@ "$branch"
cloud_fill @TASK_TEXT@ "$row"

if [ "$dry" = 1 ]; then
    printf 'claude --cloud %q --model %q\n' "$prompt" "$model"
    exit 0
fi

if [ "$yes" = 0 ]; then
    cloud_confirm cloud "$(printf 'cloud: this starts a billed Claude Code cloud session (model %s) for %s from %s. Start it? [y/N] ' "$model" "$node:$id" "$current")" || exit 1
fi

cloud_launch "$prompt" "$model"

echo "cloud: started $node:$id; it pushes $branch_name (the harness may add a suffix) and opens a pull request -- follow it at claude.ai/code"
