#!/usr/bin/env bash
# `checks.<system>.rtk-twins`: the pinned rtk's own hook decides which
# cloud permission rules it rewrites, and each rewritten rule has its
# `rtk ` twin in the same list (SPEC .:V44, B53). The fast
# `cloud-permissions` guard knows git and cargo only; this check catches
# a tool a newer rtk starts rewriting (nix:T151).
#
# Each `Bash(CMD)` rule that is not itself an rtk rule is turned into a
# sample command (every `*` becomes `x`) and fed to `rtk hook claude`
# with an empty HOME, so no settings file changes its answer. A hook that
# fails, or one that does not rewrite even `git status`, is a failure:
# nothing was checked. OUT is created only when every rewritten rule has
# its twin.
#
# Usage: rtk-twins-check.sh RTK PERMISSIONS OUT

set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "usage: rtk-twins-check.sh RTK PERMISSIONS OUT" >&2
    exit 2
fi

rtk="$1"
list="$2"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# rewritten CMD: what the hook rewrites CMD to, or nothing.
rewritten() {
    jq -nc --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}' |
        (cd "$scratch" && HOME="$scratch" "$rtk" hook claude 2>/dev/null) |
        jq -r '.hookSpecificOutput.updatedInput.command // empty'
}

if ! probe="$(rewritten 'git status')"; then
    echo "rtk-twins: $rtk hook claude failed -- nothing was checked" >&2
    exit 1
fi
if [ "$probe" != "rtk git status" ]; then
    echo "rtk-twins: $rtk hook claude did not rewrite git status (got '$probe') -- nothing was checked" >&2
    exit 1
fi

status=0
for key in allow deny; do
    while IFS= read -r rule; do
        cmd="${rule#Bash(}"
        cmd="${cmd%)}"
        if ! got="$(rewritten "${cmd//\*/x}")"; then
            echo "rtk-twins: $rtk hook claude failed on '$cmd' -- not checked" >&2
            status=1
            continue
        fi
        [[ "$got" == "rtk "* ]] || continue
        twin="Bash(rtk $cmd)"
        if ! jq -e --arg key "$key" --arg rule "$twin" '.[$key] | index($rule)' "$list" >/dev/null; then
            echo "rtk-twins: rtk rewrites $key rule \"$rule\", but $list has no \"$twin\"" >&2
            status=1
        fi
    done < <(jq -r --arg key "$key" '.[$key][] | select(startswith("Bash(") and (startswith("Bash(rtk ") | not))' "$list")
done

if [ "$status" -eq 0 ]; then
    touch "$3"
fi
exit "$status"
