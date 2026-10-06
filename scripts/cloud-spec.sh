#!/usr/bin/env bash
# Bring spec nodes back under their token ceilings in a fresh cloud
# session, from your terminal: `just spec-optimize` (SPEC scripts:T148,
# scripts:I.cmd, .:C20, .:C29).
#
# NODE is a dir of the root SPEC.md §F table, or the root itself (`.`,
# also spelled `root`); an unknown one is refused, listing the nodes
# (scripts:V26). With no NODE, the nodes are the ones over their
# `.context-limits` row: the owner of a file row `itok check` reports
# (the longest §F dir the file is under, else the root) or a chain row
# `sherd budget` reports (B41). No `.context-limits` is refused (B42).
# When none is over, there is nothing to do: exit 0, no session. A
# measuring tool that is missing or prints no report, or a chain node §F
# lacks, is a failure, never "none over" (.:V18). Measuring needs itok,
# sherd and jq: run it from the dev shell, or name the nodes.
#
# The launch rules are cloud-task.sh's: the remote must exist, the
# current branch must be pushed and equal to its upstream, and a y/N
# answer must confirm that a billed cloud session starts; --yes skips
# only that question. --dry-run runs the same checks, then prints the
# exact claude command instead of asking or launching. The model:
# --model, else the project's .claudinix.toml session.model, else sonnet.
#
# The prompt is cloud-spec-prompt.txt with @CI_WATCH@ (the shared
# cloud-ci-watch-prompt.txt), @NODES@, @SPECS@ and @BRANCH@ filled in.
# The session pushes claude/spec-optimize-<nodes joined by -> (the
# harness may add a suffix) and opens a pull request into main; it never
# merges. This does not wait for the session; follow it at claude.ai/code.
#
# Usage: cloud-spec.sh [node...] [--model M] [--yes] [--dry-run]
# Env:   CLOUD_TASK_REMOTE  remote that must hold the branch (default origin)
#        CLOUD_SPEC_ITOK    itok command (default itok)
#        CLOUD_SPEC_SHERD   sherd command (default sherd)
#        CLAUDINIX_SCRIPTS  dir holding cloud-spec-prompt.txt and config.sh
#                           (default: here)

set -euo pipefail

usage() {
    echo "usage: cloud-spec.sh [node...] [--model M] [--yes] [--dry-run]" >&2
    exit 2
}

wanted=()
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
    *) wanted+=("$1") ;;
    esac
    shift
done

lib="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"
# shellcheck source=/dev/null # lib/cloud-launch.sh, beside this script
source "$(dirname "${BASH_SOURCE[0]}")/lib/cloud-launch.sh"
remote="${CLOUD_TASK_REMOTE:-origin}"
itok="${CLOUD_SPEC_ITOK:-itok}"
sherd="${CLOUD_SPEC_SHERD:-sherd}"
run_tool="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hk/run-tool.sh"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "spec-optimize: not inside a git work tree -- run it from the project the session clones" >&2
    exit 1
fi
top="$(git rev-parse --show-toplevel)"
if [ ! -f "$top/SPEC.md" ]; then
    echo "spec-optimize: no SPEC.md at $top -- the nodes live in the project's spec" >&2
    exit 1
fi

all_nodes=()
while IFS= read -r n; do
    all_nodes+=("$n")
done < <(cloud_nodes "$top/SPEC.md")

# is_node NAME: NAME is one of the spec's nodes.
is_node() {
    local n
    for n in "${all_nodes[@]}"; do
        [ "$n" != "$1" ] || return 0
    done
    return 1
}

# owner_of PATH: the node that owns PATH, a file relative to the top: the
# longest §F dir it is under, else the root (B41).
owner_of() {
    local n best=
    for n in "${all_nodes[@]}"; do
        if [ "$n" != . ] && [[ "$1" == "$n"/* ]] && [ "${#n}" -gt "${#best}" ]; then
            best="$n"
        fi
    done
    echo "${best:-.}"
}

# measure TOOL ARGS...: the tool's JSON report, run at the top through
# the gate's runner, which refuses a missing tool (.:V18). It exits 1
# when something is over, so its status counts only when no report came
# out.
measure() {
    local out rc=0
    out="$(cd "$top" && "$run_tool" "$@")" || rc=$?
    if ! jq -e 'type == "object"' <<<"$out" >/dev/null 2>&1; then
        echo "spec-optimize: $1 $2 gave no report (exit $rc) -- could not measure the ceilings" >&2
        return 1
    fi
    printf '%s\n' "$out"
}

# over_nodes: the nodes over a file row (itok) or a chain row (sherd).
over_nodes() {
    local files chains
    if ! command -v jq >/dev/null 2>&1; then
        echo "spec-optimize: jq is not on PATH -- cannot read the ceiling reports; enter the dev shell, or name the nodes" >&2
        return 1
    fi
    files="$(measure "$itok" check -C "$top" --format json)" || return 1
    chains="$(measure "$sherd" budget --format json)" || return 1
    while IFS= read -r path; do
        owner_of "$path"
    done < <(jq -r '.breaches[].path' <<<"$files")
    while IFS= read -r n; do
        if ! is_node "$n"; then
            echo "spec-optimize: sherd reports node $n over its ceiling, but SPEC.md §F has no such node (nodes: ${all_nodes[*]})" >&2
            return 1
        fi
        echo "$n"
    done < <(jq -r '.nodes[] | select(.over_by != null) | .node' <<<"$chains")
}

nodes=()
# add_node NAME: append NAME once.
add_node() {
    local n
    for n in ${nodes[@]+"${nodes[@]}"}; do
        [ "$n" != "$1" ] || return 0
    done
    nodes+=("$1")
}

if [ "${#wanted[@]}" -gt 0 ]; then
    for n in "${wanted[@]}"; do
        [ "$n" != root ] || n=.
        if ! is_node "$n"; then
            echo "spec-optimize: no node $n in SPEC.md §F (nodes: ${all_nodes[*]})" >&2
            exit 1
        fi
        add_node "$n"
    done
else
    if [ ! -f "$top/.context-limits" ]; then
        echo "spec-optimize: no .context-limits at $top -- nothing sets a ceiling; name the nodes" >&2
        exit 1
    fi
    over="$(over_nodes)" || exit 1
    # In §F order, each once.
    for n in "${all_nodes[@]}"; do
        if grep -qxF -- "$n" <<<"$over"; then
            add_node "$n"
        fi
    done
    if [ "${#nodes[@]}" -eq 0 ]; then
        echo "spec-optimize: every node is under its .context-limits ceiling -- nothing to do"
        exit 0
    fi
fi

cloud_require_remote spec-optimize "$remote" || exit 1
current= # set by cloud_require_pushed_branch
cloud_require_pushed_branch spec-optimize "$remote" || exit 1
cloud_resolve_model "$lib" || exit "$?"

branch_name="$(cloud_spec_branch_name "${nodes[@]}")"
specs=
for n in "${nodes[@]}"; do
    if [ "$n" = . ]; then spec=SPEC.md; else spec="$n/SPEC.md"; fi
    specs="$specs${specs:+, }\`$spec\`"
done

prompt="$(cat "$lib/cloud-spec-prompt.txt")"
cloud_fill @CI_WATCH@ "$(cat "$lib/cloud-ci-watch-prompt.txt")"
cloud_fill @NODES@ "${nodes[*]}"
cloud_fill @SPECS@ "$specs"
cloud_fill @BRANCH@ "$(printf '%q' "$branch_name")"

if [ "$dry" = 1 ]; then
    printf 'claude --cloud %q --model %q\n' "$prompt" "$model"
    exit 0
fi

if [ "$yes" = 0 ]; then
    cloud_flush_input
    cloud_confirm spec-optimize "$(printf 'spec-optimize: this starts a billed Claude Code cloud session (model %s) for %s from %s. Start it? [y/N] ' "$model" "${nodes[*]}" "$current")" || exit 1
fi

cloud_launch "$prompt" "$model"

echo "spec-optimize: started ${nodes[*]}; it pushes $branch_name (the harness may add a suffix) and opens a pull request -- follow it at claude.ai/code"
