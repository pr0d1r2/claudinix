#!/usr/bin/env bash
# Run one spec task's whole cloud flow from your terminal, waiting for
# each step (SPEC scripts:T135, .:C29): build it (cloud-task.sh), wait
# for its pull request and green CI, review it by every role
# (cloud-review.sh all), wait for every role's comment, fix the findings
# up (cloud-fixup.sh), wait for its reply and green CI again, then open
# the pull request in Safari. It never merges; the owner does.
#
# TASK is `Tn` or `node:Tn`, as for cloud-task.sh. Before anything
# starts, cloud-task.sh --dry-run runs the build's checks (the task, the
# remote, the pushed branch, the model); a refusal exits with its status.
# One y/N answer, naming how many billed sessions start (1 build, 1 per
# role, 1 fixup) and the model, covers them all; --yes skips it, and each
# child then runs with --yes. --dry-run runs the checks and prints the
# plan instead.
#
# The sessions run in the cloud; this script only waits, polling GitHub
# with gh every CLOUD_ALL_POLL seconds (default 10) and printing one dot
# per poll. Each wait lasts a fixed number of minutes, counted in polls
# (minutes x 60 / CLOUD_ALL_POLL), never against a wall-clock deadline:
# - the pull request: a newly open one whose branch is
#   claude/<node>-<task>, maybe with the harness's suffix, compared with
#   the case folded (any node for a bare Tn); one open before the launch
#   or from a fork is not it;
# - CI: the head commit's checks, none pending and none failed (skipped
#   and neutral pass); no checks yet counts as pending;
# - the reviews: one comment headed "Review: <role>" for every role;
# - the fixup: a comment after its launch headed "Fixup:".
# A child that fails, red CI or a wait that runs out names the step,
# opens the pull request when there is one, and exits 1.
#
# PR# or a pull request URL (scripts:T139) skips the build: an existing
# pull request, made by hand or by an earlier run, gets the same CI,
# review, fixup and CI steps. cloud-fixup.sh --dry-run checks it, and the
# children get the argument as given.
#
# Usage: cloud-all.sh <node:Tn | Tn | PR# | URL> [--model M] [--yes] [--dry-run]
# Env:   CLOUD_ALL_POLL     seconds between polls (default 10)
#        CLAUDINIX_SCRIPTS  dir holding the child launchers, review/ and
#                           config.sh (default: here)

set -euo pipefail

# The longest each wait lasts, in minutes; the table in docs/CLI.md
# mirrors them.
minutes_pr=180
minutes_ci=60
minutes_reviews=90
minutes_fixup=180

usage() {
    echo "usage: cloud-all.sh <node:Tn | Tn | PR# | URL> [--model M] [--yes] [--dry-run]" >&2
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

scripts_dir="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"
# shellcheck source=/dev/null # lib/cloud-launch.sh, beside this script
source "$(dirname "${BASH_SOURCE[0]}")/lib/cloud-launch.sh"
want_node= # set by cloud_parse_task
id=
pr=
cloud_parse_pr "$arg" || cloud_parse_task "$arg" || usage
poll="${CLOUD_ALL_POLL-10}"
if [[ ! "$poll" =~ ^[1-9][0-9]*$ ]]; then
    echo "all: CLOUD_ALL_POLL must be a positive integer of seconds, got '$poll'" >&2
    exit 2
fi

# polls MINUTES: how many polls a wait of MINUTES takes, at least 1.
polls() {
    local n=$(($1 * 60 / poll))
    [ "$n" -ge 1 ] || n=1
    echo "$n"
}

polls_pr="$(polls "$minutes_pr")"
polls_ci="$(polls "$minutes_ci")"
polls_reviews="$(polls "$minutes_reviews")"
polls_fixup="$(polls "$minutes_fixup")"

cloud_resolve_model "$scripts_dir" || exit "$?"
child_args=(--yes --model "$model") # every child runs unasked, on the one model
if [ -n "$pr" ]; then
    "$scripts_dir/cloud-fixup.sh" "$arg" --dry-run --model "$model" >/dev/null || exit "$?"
else
    "$scripts_dir/cloud-task.sh" "$arg" --dry-run --model "$model" >/dev/null || exit "$?"
fi

roles=()
while IFS= read -r r; do
    roles+=("$r")
done < <(cloud_roles "$scripts_dir/review")
if [ "${#roles[@]}" -eq 0 ]; then
    echo "all: no review roles in $scripts_dir/review -- add one (ROLE.md) first" >&2
    exit 1
fi
if [ -n "$pr" ]; then
    sessions=$((${#roles[@]} + 1))
    steps=
    name="#$pr"
else
    sessions=$((${#roles[@]} + 2))
    steps="1 build, "
    name="$arg"
    want_head="$(cloud_branch_regex "$want_node" "$id")"
fi

plan="all: $name runs $sessions billed Claude Code cloud sessions (model $model), one after another: $steps${#roles[@]} reviews (${roles[*]}), 1 fixup; it waits for each and for green CI, up to hours"
if [ "$dry" = 1 ]; then
    echo "$plan"
    exit 0
fi
if [ "$yes" = 0 ]; then
    cloud_flush_input
    cloud_confirm all "$plan. Start? [y/N] " || exit 1
fi

url=

# open_pr: show the pull request, when there is one, in Safari (macOS)
# or the default browser.
open_pr() {
    [ -n "$url" ] || return 0
    if [ "$(uname)" = Darwin ] && command -v open >/dev/null; then
        open -a Safari "$url" || echo "all: could not open $url" >&2
    elif command -v xdg-open >/dev/null; then
        xdg-open "$url" || echo "all: could not open $url" >&2
    fi
}

# fail MESSAGE: stop the flow.
fail() {
    echo "all: $1" >&2
    open_pr
    exit 1
}

# wait_for WHAT MAX CHECK...: run CHECK every $poll s until it returns 0
# (done) or 1 (failed); 2 is not yet, printed as a dot. Returns 1 when MAX
# polls run out.
wait_for() {
    local what="$1" max="$2" i=0 rc
    shift 2
    while :; do
        rc=0
        "$@" || rc=$?
        if [ "$rc" != 2 ]; then
            [ "$i" = 0 ] || echo
            return "$rc"
        fi
        printf .
        i=$((i + 1))
        if [ "$i" -ge "$max" ]; then
            echo
            echo "all: gave up waiting for $what after $max polls of ${poll}s" >&2
            return 1
        fi
        sleep "$poll"
    done
}

# open_prs: the open pull requests, as number TAB branch TAB URL TAB
# whether it comes from a fork.
open_prs() {
    gh pr list --state open --limit 200 --json number,headRefName,url,isCrossRepository \
        --jq '.[] | [.number, .headRefName, .url, .isCrossRepository] | @tsv' </dev/null
}

# The PRs open before the launch; an unreadable list stops the flow, as an
# empty one would make any old PR of the task look new. A given PR needs
# only its URL.
before=" "
if [ -n "$pr" ]; then
    url="$(gh pr view "$pr" --json url --jq .url </dev/null)" || {
        echo "all: gh could not read pull request #$pr -- check gh auth status" >&2
        exit 1
    }
else
    snapshot="$(open_prs)" || {
        echo "all: cannot list the open pull requests -- check gh auth status" >&2
        exit 1
    }
    while IFS="$(printf '\t')" read -r n _ _ _; do
        [ -z "$n" ] || before="$before$n "
    done <<<"$snapshot"
fi

# find_pr: sets $pr and $url to the build's pull request, never a fork's.
find_pr() {
    local n head link fork lines
    lines="$(open_prs)" || return 2
    while IFS="$(printf '\t')" read -r n head link fork; do
        [ -n "$n" ] || continue
        [ "$fork" != true ] || continue
        [[ "$before" != *" $n "* ]] || continue
        if [[ "$(printf %s "$head" | tr '[:upper:]' '[:lower:]')" =~ $want_head ]]; then
            pr="$n"
            url="$link"
            return 0
        fi
    done <<<"$lines"
    return 2
}

# ci_state: the head commit's checks: 0 green, 1 red, 2 pending.
ci_state() {
    local states
    states="$(gh pr view "$pr" --json statusCheckRollup --jq '.statusCheckRollup[] |
        if .__typename == "CheckRun" then (if .status == "COMPLETED" then .conclusion else "PENDING" end)
        else .state end' </dev/null)" || return 2
    [ -n "$states" ] || return 2
    if grep -qE '^(FAILURE|CANCELLED|TIMED_OUT|ERROR|ACTION_REQUIRED|STARTUP_FAILURE)$' <<<"$states"; then
        echo "all: CI failed on #$pr" >&2
        return 1
    fi
    if grep -qvE '^(SUCCESS|SKIPPED|NEUTRAL)$' <<<"$states"; then
        return 2
    fi
}

# comments: the first line of every comment on the pull request, without
# the CR a comment written in the web UI ends its lines with.
comments() {
    gh pr view "$pr" --json comments --jq '.comments[] | (.body | split("\n") | .[0]) // ""' </dev/null |
        tr -d '\r'
}

# comment_count: how many comments the pull request has now; an unreadable
# list stops the flow, as 0 would make an old comment look new (B33).
comment_count() {
    local lines
    lines="$(comments)" || fail "cannot read the comments of #$pr -- check gh auth status"
    if [ -z "$lines" ]; then echo 0; else wc -l <<<"$lines" | tr -d ' '; fi
}

review_head="^#* *$CLOUD_REVIEW_HEADING "
fixup_head="^#* *$CLOUD_FIXUP_HEADING"

# reviews_in SKIP: 0 when every role has a comment after the first SKIP;
# else 2, with the roles still missing in $missing for the caller's message
# (wait_for runs it in this shell).
reviews_in() {
    local lines r
    lines="$(comments)" || return 2
    lines="$(tail -n +$(($1 + 1)) <<<"$lines")"
    missing=()
    for r in "${roles[@]}"; do
        grep -qE "${review_head}$r( |\$)" <<<"$lines" || missing+=("$r")
    done
    [ "${#missing[@]}" -eq 0 ] || return 2
}

# fixup_replied SKIP: 0 when a comment after the first SKIP is headed
# "Fixup:", as cloud-fixup-prompt.txt tells the session.
fixup_replied() {
    local lines
    lines="$(comments)" || return 2
    tail -n +$(($1 + 1)) <<<"$lines" | grep -qE "$fixup_head" || return 2
}

if [ -n "$pr" ]; then
    target="$arg" # the children check a URL's repo themselves
    built=
    echo "all: waiting for CI on #$pr ($url)"
    wait_for "CI on #$pr" "$polls_ci" ci_state || fail "CI is not green on #$pr"
else
    "$scripts_dir/cloud-task.sh" "$arg" "${child_args[@]}" || fail "the build of $arg did not start"
    echo "all: waiting for the pull request of $arg"
    wait_for "the pull request of $arg" "$polls_pr" find_pr || fail "no pull request of $arg appeared"
    target="$pr"
    built="the build, "
    echo "all: #$pr is open ($url); waiting for CI"
    wait_for "CI on #$pr" "$polls_ci" ci_state || fail "CI is not green on #$pr after the build"
fi

echo "all: CI is green on #$pr; starting the reviews"
skip="$(comment_count)"
"$scripts_dir/cloud-review.sh" all "$target" "${child_args[@]}" || fail "the reviews of #$pr did not all start"
missing=()
if ! wait_for "the reviews of #$pr" "$polls_reviews" reviews_in "$skip"; then
    fail "no review of #$pr by ${missing[*]}"
fi

echo "all: every role reviewed #$pr; starting the fixup"
skip="$(comment_count)"
"$scripts_dir/cloud-fixup.sh" "$target" "${child_args[@]}" || fail "the fixup of #$pr did not start"
wait_for "the fixup of #$pr" "$polls_fixup" fixup_replied "$skip" || fail "the fixup of #$pr never replied"
echo "all: the fixup replied on #$pr; waiting for CI"
wait_for "CI on #$pr" "$polls_ci" ci_state || fail "CI is not green on #$pr after the fixup"

echo "all: CI is green on #$pr after ${built}the reviews and the fixup; opening $url"
open_pr
