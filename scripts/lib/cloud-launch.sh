#!/usr/bin/env bash
# The launch rules cloud-task.sh, cloud-rebase.sh, cloud-review.sh,
# cloud-fixup.sh and cloud-spec.sh share (SPEC cloud:I.cmd,
# cloud:B19). Source it; it defines functions only. Functions that
# print a message take the caller's LABEL first ("cloud", "rebase",
# "review", "spec-optimize"), which prefixes it.

set -euo pipefail

# shellcheck source=/dev/null # spec-nodes.sh, beside this file
source "$(dirname "${BASH_SOURCE[0]}")/spec-nodes.sh"
# shellcheck source=/dev/null # context-limits.sh, beside this file
source "$(dirname "${BASH_SOURCE[0]}")/context-limits.sh"

# The first words of the comments the review and fixup sessions post; the
# prompts name them and cloud-all.sh waits for them (cloud:B28).
# shellcheck disable=SC2034 # read by the scripts that source this file
CLOUD_REVIEW_HEADING='Review:'
# shellcheck disable=SC2034 # read by the scripts that source this file
CLOUD_FIXUP_HEADING='Fixup:'
# The label of the last line of a fixup reply, then the sha it pushed; the
# prompt names it and `all` and `merge` read it (cloud:V51, V52).
# shellcheck disable=SC2034 # read by the scripts that source this file
CLOUD_FIXUP_HEAD_LABEL='Head:'
# What counts as a heading line: any number of #s, then the heading.
CLOUD_FIXUP_HEADING_RE="^#* *$CLOUD_FIXUP_HEADING"
# jq definitions for reading pull request comments, the one place that
# decides who may speak and what a fixup reply says. Anyone may comment, so
# only the owner and members steer a flow (cloud:V51, V52, B64, B99).
# head_of: the sha on the last `Head:` line of a comment, else null.
# shellcheck disable=SC2034 # read by the scripts that source this file
CLOUD_COMMENT_JQ='def trusted: select(.authorAssociation == "OWNER" or .authorAssociation == "MEMBER");
def fixup_reply: select((.body | split("\n")[0]) | test("'"$CLOUD_FIXUP_HEADING_RE"'"));
def head_of: [(.body // "") | gsub("\r"; "") | split("\n")[] | capture("^'"$CLOUD_FIXUP_HEAD_LABEL"' (?<sha>[0-9a-f]+)$")? | .sha] | last;
'
# The first word of the last line of a review comment, then the count; the
# prompt names it and `just merge` reads it (cloud:V51).
# shellcheck disable=SC2034 # read by the scripts that source this file
CLOUD_FINDINGS_HEADING='Findings:'

# The paths `just merge` never merges a change to (cloud:V51): the files that
# decide what is allowed to merge. A name ending in `/` is a directory.
# shellcheck disable=SC2034 # read by cloud-merge.sh
CLOUD_MERGE_KEPT=(
    hk.pkl flake.nix flake.lock nix/cloud-permissions.json nix/dev-shell.nix
    nix/checks.nix nix/apps.nix .github/ .claude/ justfile
    scripts/guard/ scripts/hk/ scripts/dev/ scripts/review/ scripts/lib/
    scripts/cloud-all.sh scripts/cloud-drain.sh scripts/cloud-held.sh scripts/cloud-merge.sh scripts/cloud-review.sh
    scripts/cloud-review-prompt.txt tests/unit/scripts/guard/
)

# The nodes `just drain` never takes tasks from without being named: scratch
# and research work that is not built by a session (cloud:T161).
# shellcheck disable=SC2034 # read by cloud-drain.sh
CLOUD_DRAIN_SKIP=(experiments)

# The window, in days, over which `just drain` counts merged pull requests
# that had a fixup to set its default --max, and the most it asks gh for; a
# window with more merges than the limit is undercounted.
# shellcheck disable=SC2034 # read by cloud-drain.sh
CLOUD_DRAIN_PACE_DAYS=7
# shellcheck disable=SC2034 # read by cloud-drain.sh
CLOUD_DRAIN_PACE_LIMIT=200

# The check conclusions that count as green; `just all` waits for them and
# `just merge` judges by them (cloud:B68). Any other one is red or pending.
# shellcheck disable=SC2034 # read by the scripts that source this file
CLOUD_CI_OK='^(SUCCESS|SKIPPED|NEUTRAL)$'

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

# cloud_role_count LABEL DIR: the number of review roles in DIR/review, or,
# for none, the refusal LABEL prints and a return of 1. The one guard
# cloud-drain.sh and cloud-held.sh share.
cloud_role_count() {
    local count=0
    while IFS= read -r _; do
        count=$((count + 1))
    done < <(cloud_roles "$2/review")
    if [ "$count" -eq 0 ]; then
        echo "$1: no review roles in $2/review -- add one (ROLE.md) first" >&2
        return 1
    fi
    echo "$count"
}

# cloud_session_count ROLES [pr]: the billed sessions one `all` run starts
# for ROLES review roles: 1 build (none for a pull request, the word `pr`),
# 1 per role and 1 fixup. The one source cloud-all.sh and cloud-drain.sh
# quote in their plans.
cloud_session_count() {
    local build=1
    [ "${2:-}" != pr ] || build=0
    echo $(($1 + build + 1))
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
    spec_f_nodes "$1"
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

# cloud_remote_repo REMOTE: owner/repo of REMOTE's URL.
cloud_remote_repo() {
    git remote get-url "$1" | sed -E 's#^.*[:/]([^/]+/[^/]+)$#\1#; s#\.git$##'
}

# The checkout cloud_enter_url_repo changed into, else empty; read by
# cloud_require_checkout_ready (cloud:T175).
entered_checkout=

# cloud_enter_url_repo LABEL REMOTE: a pull request URL (set $url_repo by
# cloud_parse_pr) that names another repository than REMOTE points at is run
# from $CLAUDINIX_PROJECTS/<repo>, when that checkout's origin is that repo
# (case folded): this cds there and sets $entered_checkout. Returns 0 for a
# bare number, this repo's URL or an entered checkout; 2 when there is no
# usable checkout (no CLAUDINIX_PROJECTS, a repo that is not owner/repo, no
# directory), saying nothing; 1 for a checkout of another repo, saying so.
# Only a name compare and the origin come before any `gh` call (cloud:B63).
cloud_enter_url_repo() {
    local dir
    [ -n "$url_repo" ] || return 0
    # GitHub names ignore case; `tr`, as bash 3.2 has no ${var,,}.
    if [ "$(printf %s "$url_repo" | tr '[:upper:]' '[:lower:]')" = "$(cloud_remote_repo "$2" | tr '[:upper:]' '[:lower:]')" ]; then
        return 0
    fi
    [ -n "${CLAUDINIX_PROJECTS:-}" ] || return 2
    cloud_valid_repo "$url_repo" || return 2
    dir="$(cloud_repo_checkout "$url_repo")"
    [ -d "$dir" ] || return 2
    if ! cloud_origin_is "$url_repo" "$dir"; then
        echo "$1: $dir is not a checkout of $url_repo (its origin is another repository) -- fix $CLAUDINIX_PROJECTS" >&2
        return 1
    fi
    cd "$dir" || return 1
    entered_checkout="$dir"
}

# cloud_require_url_repo LABEL REMOTE ARG: a pull request URL must name the
# repository REMOTE points at, or one cloud_enter_url_repo enters (cloud:B21,
# cloud:B25, cloud:T175); a bare number passes.
cloud_require_url_repo() {
    local rc=0
    cloud_enter_url_repo "$1" "$2" || rc=$?
    case "$rc" in
    0) ;;
    2)
        echo "$1: $3 is a pull request of $url_repo, but remote $2 is $(cloud_remote_repo "$2") -- run it from a checkout of $url_repo" >&2
        return 1
        ;;
    *) return "$rc" ;;
    esac
}

# cloud_require_checkout_ready LABEL: an entered checkout must be clean, on
# the pull request's $base and at that branch's fetched tip, so the session
# clones the base's tooling and gate, never a stray local state (cloud:V53,
# cloud:T175). Nothing to check when no checkout was entered.
cloud_require_checkout_ready() {
    local current
    [ -n "$entered_checkout" ] || return 0
    if [ -n "$(git -C "$entered_checkout" status --porcelain)" ]; then
        echo "$1: $entered_checkout is not clean -- commit or stash its changes first" >&2
        return 1
    fi
    current="$(git -C "$entered_checkout" symbolic-ref --quiet --short HEAD || true)"
    if [ "$current" != "$base" ]; then
        echo "$1: $entered_checkout is not on $base (the pull request's base) -- check it out first" >&2
        return 1
    fi
    if ! git -C "$entered_checkout" fetch --quiet origin "$base"; then
        echo "$1: could not fetch $base in $entered_checkout" >&2
        return 1
    fi
    if [ "$(git -C "$entered_checkout" rev-parse HEAD)" != "$(git -C "$entered_checkout" rev-parse FETCH_HEAD)" ]; then
        echo "$1: $entered_checkout is not at the fetched origin/$base -- pull it first" >&2
        return 1
    fi
}

# cloud_read_pr LABEL REMOTE ARG [EXTRA]: the pull request $pr (from cloud_parse_pr)
# must be open, of the repository REMOTE points at, with a head and a base
# that are plain refs. The URL repo is checked before any `gh` call, so
# another repo's number is never read as this repo's (cloud:B63). Sets $head,
# $base, $url and $cross (true for a fork); with EXTRA (more --json fields),
# the same read answers the caller too and its raw JSON is left in $pr_json.
# The one source of these refusals, so a fix like cloud:B20 lands once;
# cloud_require_open_pr adds the push-only ones.
cloud_read_pr() {
    local info state ref
    cloud_require_url_repo "$1" "$2" "$3" || return 1
    # </dev/null: gh must not share the terminal the y/N answer comes from (cloud:B19).
    local tsv='[.number, .state, .headRefName, .baseRefName, .url, .isCrossRepository] | @tsv'
    local fields=number,state,headRefName,baseRefName,url,isCrossRepository
    if [ -n "${4:-}" ]; then
        pr_json="$(gh pr view "$pr" --json "$fields,$4" </dev/null)" &&
            info="$(jq -r "$tsv" <<<"$pr_json")"
    else
        info="$(gh pr view "$pr" --json "$fields" --jq "$tsv" </dev/null)"
    fi || {
        echo "$1: gh could not read pull request #$pr -- check the number and that gh is signed in" >&2
        return 1
    }
    # shellcheck disable=SC2034 # head, base, url and cross are read by the caller
    IFS="$(printf '\t')" read -r _ state head base url cross <<<"$info"
    if [ "$state" != OPEN ]; then
        echo "$1: #$pr is $state, not OPEN -- nothing to do" >&2
        return 1
    fi
    # No leading `-`: the prompts paste these bare into git commands (cloud:B20, cloud:B39).
    for ref in "$head" "$base"; do
        if [[ ! "$ref" =~ ^[A-Za-z0-9._][A-Za-z0-9._/-]*$ ]]; then
            echo "$1: #$pr's branch $ref is not a plain branch name (letters, digits, ._/-, not starting with -) -- it would reach the session's commands" >&2
            return 1
        fi
    done
    cloud_require_checkout_ready "$1"
}

# cloud_require_open_pr LABEL REMOTE ARG [EXTRA]: cloud_read_pr, and the pull
# request must be one a session may push to: not a fork, based on main,
# with a head that is not main.
cloud_require_open_pr() {
    cloud_read_pr "$@" || return 1
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
# as a reply to a query gh sent it, so only the typed answer is read (cloud:B19).
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

# cloud_diff_reasons: read a patch (`gh pr diff`) on stdin and print, one per
# line, each reason `just merge` must stop for the owner: a change to a path
# of CLOUD_MERGE_KEPT, to a §C or §V row of a SPEC.md, or a .context-limits
# ceiling raised or added, read by context_limits_raises (cloud:V51). Prints
# nothing for a quiet diff.
cloud_diff_reasons() {
    local patch
    patch="$(cat)"
    context_limits_raises <<<"$patch"
    awk -v kept_paths="${CLOUD_MERGE_KEPT[*]}" '
        function kept(path,    i) {
            for (i = 1; i <= n_kept; i++) {
                if (path == kept_list[i] || (kept_list[i] ~ /\/$/ && index(path, kept_list[i]) == 1)) return 1
            }
            return 0
        }
        BEGIN { n_kept = split(kept_paths, kept_list, " ") }
        function flag(path) {
            if (kept(path) && !(path in flagged)) { flagged[path] = 1; print "diff: changes " path }
        }
        # The header names every changed file, a pure rename or mode change
        # included, which has no content line (cloud:B66).
        /^diff --git / { file = $0; sub(/^diff --git .* b\//, "", file); flag(file); next }
        /^rename from / { from = $0; sub(/^rename from /, "", from); flag(from); next }
        /^(\+\+\+|---) / { next }
        /^[-+]/ {
            if (file ~ /(^|\/)SPEC\.md$/ && $0 ~ /^[-+](- C[0-9]+:|V[0-9]+:)/) {
                if (!(file in rule)) { rule[file] = 1; print "diff: changes a §C or §V row of " file }
            }
        }
    ' <<<"$patch"
}

# cloud_report CMD SUBJECT STATUS...: one report row, `<cmd>: report: <subject>
# <status>`, the shape `just held` and `just enroll` print and read back.
cloud_report() {
    local cmd="$1" subject="$2"
    shift 2
    echo "$cmd: report: $subject $*"
}

# cloud_repo_checkout REPO: the owner's checkout of REPO (owner/repo or just
# repo), $CLAUDINIX_PROJECTS/<repo>: one directory per repo name (cloud:V59).
cloud_repo_checkout() {
    echo "$CLAUDINIX_PROJECTS/${1##*/}"
}

# The per-checkout file that pins the claude.ai cloud environment, relative
# to the checkout; `enroll` writes it, `held` reads it (cloud:T174).
# shellcheck disable=SC2034 # read by the scripts that source this file
CLOUD_PIN_FILE=.claude/settings.local.json

# cloud_pin_env FILE: the environment id pinned in settings FILE, empty when
# FILE is missing, unreadable or has none. `/remote-env` writes the same key.
cloud_pin_env() {
    jq -r '.remote.defaultEnvironmentId // empty' "$1" 2>/dev/null || true
}

# cloud_pin_set ID: settings JSON on stdin, printed with the environment
# pinned to ID and every other key kept. The twin of guide.sh's pin_env.
cloud_pin_set() {
    jq --arg id "$1" '.remote = ((.remote // {}) | .defaultEnvironmentId = $id)'
}

# cloud_origin_is REPO DIR: DIR's origin is github.com/REPO, case folded
# (cloud:V59).
cloud_origin_is() {
    local url want
    url="$(git -C "$2" remote get-url origin 2>/dev/null)" || return 1
    url="$(tr '[:upper:]' '[:lower:]' <<<"${url%.git}")"
    want="$(tr '[:upper:]' '[:lower:]' <<<"$1")"
    [ "$url" = "https://github.com/$want" ] || [ "$url" = "git@github.com:$want" ]
}

# cloud_valid_repo REPO: owner/repo, nothing else, no leading - (cloud:V59,
# cloud:B106).
cloud_valid_repo() {
    [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9._][A-Za-z0-9._-]*$ ]] && [[ "$1" != */. && "$1" != */.. ]]
}

# cloud_repos_with_label CMD LABEL: owner/repo, one per line, of the repos where
# the authenticated user has an open pull request under LABEL that they wrote
# in the same repo (cloud:V52, cloud:V59). A pull request by someone else, from
# a fork, or of a repo that is not owner/repo is skipped, naming it on stderr
# with CMD; so is one whose fork check fails: only a plain `false` passes.
cloud_repos_with_label() {
    local cmd="$1" label="$2" owner found rows name author url repo is_fork
    local search_limit=100
    # </dev/null: gh must not share the terminal the y/N answer comes from (cloud:B19).
    owner="$(gh api user --jq .login </dev/null)" || return 1
    found="$(gh search prs --owner "$owner" --label "$label" --state open --limit "$search_limit" \
        --json number,url,repository,author </dev/null)" || return 1
    if [ "$(jq length <<<"$found")" -ge "$search_limit" ]; then
        echo "$cmd: only the first $search_limit labelled pull requests were found; the rest are not considered" >&2
    fi
    rows="$(jq -r 'sort_by(.url) | .[] | ["\(.repository.nameWithOwner)#\(.number)", (.author.login // "ghost"), .repository.nameWithOwner, .url] | @tsv' <<<"$found")"
    while IFS=$'\t' read -r name author repo url; do
        [ -n "$name" ] || continue
        if [ "$author" != "$owner" ]; then
            echo "$cmd: skip $name: its author is $author, not $owner" >&2
        elif ! is_fork="$(gh pr view "$url" --json isCrossRepository --jq .isCrossRepository </dev/null)"; then
            echo "$cmd: skip $name: cannot tell whether it comes from a fork" >&2
        elif [ "$is_fork" != false ]; then
            echo "$cmd: skip $name: it comes from a fork" >&2
        elif ! cloud_valid_repo "$repo"; then
            echo "$cmd: skip $name: '$repo' is not owner/repo" >&2
        else
            echo "$repo"
        fi
    done <<<"$rows" | awk '!seen[$0]++'
}
