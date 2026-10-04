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
# The prompt is cloud-task-prompt.txt with @TASK@, @NODE@, @BRANCH@ and
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

if [[ "$arg" =~ ^(([A-Za-z0-9._-]+):)?(T[0-9]+)$ ]]; then
    want_node="${BASH_REMATCH[2]}"
    id="${BASH_REMATCH[3]}"
else
    echo "cloud: bad task $arg -- want Tn or node:Tn (e.g. T100, scripts:T98)" >&2
    exit 2
fi
[ "$want_node" != root ] || want_node=.

lib="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"
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

if ! git remote get-url "$remote" >/dev/null 2>&1; then
    echo "cloud: no remote $remote -- push the project to GitHub first" >&2
    exit 1
fi

# The session clones GitHub: the branch must be there as it is here.
if ! current="$(git symbolic-ref --quiet --short HEAD)"; then
    echo "cloud: HEAD is detached -- check out the branch the session should clone" >&2
    exit 1
fi
if ! upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
    echo "cloud: branch $current is not pushed (no upstream) -- push it first: git push -u $remote $current" >&2
    exit 1
fi
if [ "$(git rev-parse HEAD)" != "$(git rev-parse '@{u}')" ]; then
    echo "cloud: branch $current is not up to date with $upstream -- push (or pull) first" >&2
    exit 1
fi

# The project's .claudinix.toml (scripts:V34): flag > file > sonnet,
# config.sh supplying sonnet when there is no file.
if [ -z "$model" ]; then
    model="$(bash "$lib/config.sh" get session.model)" || exit "$?"
fi

label="$node"
[ "$label" != . ] || label=root
branch="$(printf '%q' "claude/$label-$id")"

# fill KEY VALUE: replace every KEY in $prompt with VALUE, as written.
# Not ${prompt//KEY/VALUE}: bash 5.2 turns an `&` in VALUE into the match
# (patsub_replacement), and quoting VALUE there keeps the quotes in bash
# 3.2 (macOS /bin/bash). The row goes in last, so a placeholder spelled
# inside it is not filled.
fill() {
    local text="$prompt" out=
    while [[ "$text" == *"$1"* ]]; do
        out="$out${text%%"$1"*}$2"
        text="${text#*"$1"}"
    done
    prompt="$out$text"
}
prompt="$(cat "$lib/cloud-task-prompt.txt")"
fill @TASK@ "$id"
fill @NODE@ "$node"
fill @BRANCH@ "$branch"
fill @TASK_TEXT@ "$row"

if [ "$dry" = 1 ]; then
    printf 'claude --cloud %q --model %q\n' "$prompt" "$model"
    exit 0
fi

if [ "$yes" = 0 ]; then
    printf 'cloud: this starts a billed Claude Code cloud session (model %s) for %s from %s. Start it? [y/N] ' "$model" "$node:$id" "$current"
    answer=
    IFS= read -r answer || true
    case "$answer" in
    y | Y | yes) ;;
    *)
        echo "cloud: not started" >&2
        exit 1
        ;;
    esac
fi

# util-linux `script` takes the command as a string, BSD `script` as
# arguments; both get a TTY for claude. The string reads the prompt from
# the environment, so no quoting of it is needed.
if script --version >/dev/null 2>&1; then
    # shellcheck disable=SC2016 # script's shell expands these, not this one
    CLOUD_TASK_PROMPT="$prompt" CLOUD_TASK_MODEL="$model" script -q -e \
        -c 'claude --cloud "$CLOUD_TASK_PROMPT" --model "$CLOUD_TASK_MODEL"' /dev/null
else
    script -q /dev/null claude --cloud "$prompt" --model "$model"
fi

echo "cloud: started $node:$id; it pushes claude/$label-$id (the harness may add a suffix) and opens a pull request -- follow it at claude.ai/code"
