#!/usr/bin/env bash
# The launch rules cloud-task.sh, cloud-rebase.sh, cloud-review.sh,
# cloud-fixup.sh and cloud-spec.sh share (SPEC scripts:I.cmd,
# scripts:B19). Source it; it defines functions only. Functions that
# print a message take the caller's LABEL first ("cloud", "rebase",
# "review", "spec-optimize"), which prefixes it.

set -euo pipefail

# The first words of the comments the review and fixup sessions post; the
# prompts name them and cloud-all.sh waits for them (scripts:B28).
# shellcheck disable=SC2034 # read by the scripts that source this file
CLOUD_REVIEW_HEADING='Review:'
# shellcheck disable=SC2034 # read by the scripts that source this file
CLOUD_FIXUP_HEADING='Fixup:'

# cloud_fill KEY VALUE: replace every KEY in $prompt with VALUE, as written.
# Not ${prompt//KEY/VALUE}: bash 5.2 turns an `&` in VALUE into the match
# (patsub_replacement), and quoting VALUE there keeps the quotes in bash
# 3.2 (macOS /bin/bash). Fill the text that may spell a placeholder last,
# so that placeholder is not filled.
cloud_fill() {
    local text="$prompt" out=
    while [[ "$text" == *"$1"* ]]; do
        out="$out${text%%"$1"*}$2"
        text="${text#*"$1"}"
    done
    prompt="$out$text"
}

# cloud_roles DIR: the review roles, one per line: the name of every
# ROLE.md file in DIR. The one source of the role list, which sets how
# many sessions `review all` starts and which reviews `all` waits for.
cloud_roles() {
    local f
    for f in "$1"/*.md; do
        if [ -f "$f" ]; then
            f="${f##*/}"
            echo "${f%.md}"
        fi
    done
}

# cloud_parse_task ARG: split a task argument, Tn or node:Tn, into $want_node
# (empty for a bare Tn) and $id. Returns 1 for anything else.
cloud_parse_task() {
    [[ "$1" =~ ^(([A-Za-z0-9._-]+):)?(T[0-9]+)$ ]] || return 1
    # shellcheck disable=SC2034 # read by the caller
    want_node="${BASH_REMATCH[2]}"
    # shellcheck disable=SC2034 # read by the caller
    id="${BASH_REMATCH[3]}"
}

# cloud_parse_pr ARG: split a pull request argument, PR# or its URL, into $pr
# and $url_repo (owner/repo, empty for a bare number). Returns 1 for
# anything else.
cloud_parse_pr() {
    # shellcheck disable=SC2034 # read by the caller
    url_repo=
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        # shellcheck disable=SC2034 # read by the caller
        pr="$1"
    elif [[ "$1" =~ ^https://github\.com/([^/]+/[^/]+)/pull/([0-9]+)/?$ ]]; then
        # shellcheck disable=SC2034 # read by the caller
        url_repo="${BASH_REMATCH[1]}"
        # shellcheck disable=SC2034 # read by the caller
        pr="${BASH_REMATCH[2]}"
    else
        return 1
    fi
}

# cloud_node_label NODE: NODE as a branch name spells it: the root node,
# `.`, as root.
cloud_node_label() {
    if [ "$1" = . ]; then echo root; else echo "$1"; fi
}

# cloud_branch_name NODE ID: the branch the build's session pushes.
cloud_branch_name() {
    echo "claude/$(cloud_node_label "$1")-$2"
}

# cloud_spec_branch_name NODE...: the branch a spec-optimize session
# pushes: claude/spec-optimize, then each node's label after a `-`.
cloud_spec_branch_name() {
    local name=claude/spec-optimize node
    for node in "$@"; do
        name="$name-$(cloud_node_label "$node")"
    done
    echo "$name"
}

# cloud_nodes SPEC: the spec nodes, one per line: the root (`.`), then
# every dir of the §F table of SPEC, the root SPEC.md.
cloud_nodes() {
    echo .
    awk '/^## / { f = ($2 == "§F") } f && /\|/ && !/^dir\|/ { split($0, a, "|"); print a[1] }' "$1"
}

# cloud_spec_of NODE: the node's SPEC.md, relative to the top.
cloud_spec_of() {
    if [ "$1" = . ]; then echo SPEC.md; else echo "$1/SPEC.md"; fi
}

# cloud_in_list NEEDLE ITEM...: NEEDLE is one of the ITEMs. Pass an array
# as ${a[@]+"${a[@]}"}: bash 3.2 calls an empty "${a[@]}" unbound.
cloud_in_list() {
    local needle="$1" item
    shift
    for item in "$@"; do
        [ "$item" != "$needle" ] || return 0
    done
    return 1
}

# cloud_require_node LABEL NODE NODES...: NODE must be one of NODES (from
# cloud_nodes); else refuse naming it and listing them (scripts:V26).
cloud_require_node() {
    local label="$1" node="$2"
    shift 2
    cloud_in_list "$node" "$@" && return 0
    echo "$label: no node $node in SPEC.md §F (nodes: $*)" >&2
    return 1
}

# cloud_branch_regex NODE ID: an ERE for cloud_branch_name, as seen once
# the harness lowered the case and added its suffix; an empty NODE takes
# any node.
cloud_branch_regex() {
    local label="[^/]+"
    if [ -n "$1" ]; then
        label="$(cloud_node_label "$1")"
        label="${label//./\\.}"
    fi
    printf '^claude/%s-%s(-[a-z0-9]+)?$\n' \
        "$(printf %s "$label" | tr '[:upper:]' '[:lower:]')" \
        "$(printf %s "$2" | tr '[:upper:]' '[:lower:]')"
}

# cloud_require_remote LABEL REMOTE: the project must be on GitHub.
cloud_require_remote() {
    if ! git remote get-url "$2" >/dev/null 2>&1; then
        echo "$1: no remote $2 -- push the project to GitHub first" >&2
        return 1
    fi
}

# cloud_require_url_repo LABEL REMOTE ARG: a pull request URL (set $url_repo
# by cloud_parse_pr) must name the repository REMOTE points at, case folded
# (B21, B25); a bare number passes.
cloud_require_url_repo() {
    local remote_repo
    [ -n "$url_repo" ] || return 0
    remote_repo="$(git remote get-url "$2" | sed -E 's#^.*[:/]([^/]+/[^/]+)$#\1#; s#\.git$##')"
    # GitHub names ignore case; `tr`, as bash 3.2 has no ${var,,}.
    if [ "$(printf %s "$url_repo" | tr '[:upper:]' '[:lower:]')" != "$(printf %s "$remote_repo" | tr '[:upper:]' '[:lower:]')" ]; then
        echo "$1: $3 is a pull request of $url_repo, but remote $2 is $remote_repo -- run it from a checkout of $url_repo" >&2
        return 1
    fi
}

# cloud_require_open_pr LABEL REMOTE ARG: the pull request $pr (from
# cloud_parse_pr) must be one a session may push to: open, of this
# repository (not a fork), based on main, with a head that is not main and
# a plain ref. Sets $head, $base and $url. The one source of these
# refusals, so a fix like B20 lands once.
cloud_require_open_pr() {
    local info state cross
    cloud_require_url_repo "$1" "$2" "$3" || return 1
    # </dev/null: gh must not share the terminal the y/N answer comes from (B19).
    if ! info="$(gh pr view "$pr" --json number,state,headRefName,baseRefName,url,isCrossRepository \
        --jq '[.number, .state, .headRefName, .baseRefName, .url, .isCrossRepository] | @tsv' </dev/null)"; then
        echo "$1: gh could not read pull request #$pr -- check the number and that gh is signed in" >&2
        return 1
    fi
    # shellcheck disable=SC2034 # head, base and url are read by the caller
    IFS="$(printf '\t')" read -r _ state head base url cross <<<"$info"
    if [ "$state" != OPEN ]; then
        echo "$1: #$pr is $state, not OPEN -- nothing to do" >&2
        return 1
    fi
    if [ "$cross" = true ]; then
        echo "$1: #$pr is from a fork; its branch $head is not a branch of $2 -- handle it by hand" >&2
        return 1
    fi
    if [ "$base" != main ]; then
        echo "$1: #$pr targets $base, not main -- handle it by hand" >&2
        return 1
    fi
    if [ "$head" = main ]; then
        echo "$1: #$pr's branch is main; a cloud session never pushes main" >&2
        return 1
    fi
    # No leading `-`: the prompts paste the head bare into git commands (B39).
    if [[ ! "$head" =~ ^[A-Za-z0-9._][A-Za-z0-9._/-]*$ ]]; then
        echo "$1: #$pr's branch $head is not a plain branch name (letters, digits, ._/-, not starting with -) -- it would reach the session's commands" >&2
        return 1
    fi
}

# cloud_require_pushed_branch LABEL REMOTE: the session clones GitHub, so
# the branch must be there as it is here. Sets $current to its name.
cloud_require_pushed_branch() {
    local upstream
    if ! current="$(git symbolic-ref --quiet --short HEAD)"; then
        echo "$1: HEAD is detached -- check out the branch the session should clone" >&2
        return 1
    fi
    if ! upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
        echo "$1: branch $current is not pushed (no upstream) -- push it first: git push -u $2 $current" >&2
        return 1
    fi
    if [ "$(git rev-parse HEAD)" != "$(git rev-parse '@{u}')" ]; then
        echo "$1: branch $current is not up to date with $upstream -- push (or pull) first" >&2
        return 1
    fi
}

# cloud_resolve_model SCRIPTS_DIR: keep $model when --model gave one, else
# the project's .claudinix.toml session.model, else sonnet (scripts:V34).
cloud_resolve_model() {
    if [ -z "$model" ]; then
        model="$(bash "$1/config.sh" get session.model)" || return "$?"
    fi
}

# cloud_flush_input: drop what the terminal left in the input buffer, such
# as a reply to a query gh sent it, so only the typed answer is read (B19).
# Whole seconds: macOS /bin/bash 3.2 has no fractional -t.
cloud_flush_input() {
    if [ -t 0 ]; then
        while IFS= read -r -t 1 _; do :; done
    fi
}

# cloud_confirm LABEL QUESTION: ask the billed-session question; only y,
# Y or yes starts it. Returns 1 otherwise.
cloud_confirm() {
    local answer=
    printf '%s' "$2"
    IFS= read -r answer || true
    case "$answer" in
    y | Y | yes) ;;
    *)
        echo "$1: not started" >&2
        return 1
        ;;
    esac
}

# cloud_launch PROMPT MODEL: start the cloud session; returns claude's
# status. util-linux `script` takes the command as a string, BSD `script`
# as arguments; both give claude a TTY. The string reads the prompt from
# the environment, so no quoting of it is needed.
cloud_launch() {
    if script --version >/dev/null 2>&1; then
        # shellcheck disable=SC2016 # script's shell expands these, not this one
        CLOUD_TASK_PROMPT="$1" CLOUD_TASK_MODEL="$2" script -q -e \
            -c 'claude --cloud "$CLOUD_TASK_PROMPT" --model "$CLOUD_TASK_MODEL"' /dev/null
    else
        script -q /dev/null claude --cloud "$1" --model "$2"
    fi
}
