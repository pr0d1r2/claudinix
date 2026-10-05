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
#   is not it;
# - CI: the head commit's checks, none pending and none failed (skipped
#   and neutral pass); no checks yet counts as pending;
# - the reviews: one comment headed "Review: <role>" for every role;
# - the fixup: the first comment after its launch not headed "Review:".
# A child that fails, red CI or a wait that runs out names the step,
# opens the pull request when there is one, and exits 1.
#
# Usage: cloud-all.sh <node:Tn | Tn> [--model M] [--yes] [--dry-run]
# Env:   CLOUD_ALL_POLL     seconds between polls (default 10)
#        CLAUDINIX_SCRIPTS  dir holding the child launchers, review/ and
#                           config.sh (default: here)

set -euo pipefail

usage() {
    echo "usage: cloud-all.sh <node:Tn | Tn> [--model M] [--yes] [--dry-run]" >&2
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
[[ "$arg" =~ ^(([A-Za-z0-9._-]+):)?(T[0-9]+)$ ]] || usage
want_node="${BASH_REMATCH[2]}"
id="${BASH_REMATCH[3]}"

lib="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"
# shellcheck source=/dev/null # lib/cloud-launch.sh, beside this script
source "$(dirname "${BASH_SOURCE[0]}")/lib/cloud-launch.sh"
poll="${CLOUD_ALL_POLL:-10}"

# polls MINUTES: how many polls a wait of MINUTES takes, at least 1.
polls() {
    local n=$(($1 * 60 / poll))
    [ "$n" -ge 1 ] || n=1
    echo "$n"
}

# The longest each wait lasts.
polls_pr="$(polls 180)"
polls_ci="$(polls 60)"
polls_reviews="$(polls 90)"
polls_fixup="$(polls 180)"

cloud_resolve_model "$lib" || exit "$?"
"$lib/cloud-task.sh" "$arg" --dry-run --model "$model" >/dev/null || exit "$?"

roles=()
for f in "$lib"/review/*.md; do
    [ -e "$f" ] || continue
    r="${f##*/}"
    roles+=("${r%.md}")
done
if [ "${#roles[@]}" -eq 0 ]; then
    echo "all: no review roles in $lib/review -- add one (ROLE.md) first" >&2
    exit 1
fi
sessions=$((${#roles[@]} + 2))

# The branch the build pushes, lower case, as a regex: the harness may
# add a suffix and lower the case. A bare Tn may be in any node.
label="$(printf %s "${want_node:-[^/]+}" | tr '[:upper:]' '[:lower:]')"
[ "$label" != . ] || label=root
want_head="^claude/$label-$(printf %s "$id" | tr '[:upper:]' '[:lower:]')(-[a-z0-9]+)?\$"

plan="all: $arg runs $sessions billed Claude Code cloud sessions (model $model), one after another: 1 build, ${#roles[@]} reviews (${roles[*]}), 1 fixup; it waits for each and for green CI, up to hours"
if [ "$dry" = 1 ]; then
    echo "$plan"
    exit 0
fi
if [ "$yes" = 0 ]; then
    cloud_flush_input
    cloud_confirm all "$plan. Start? [y/N] " || exit 1
fi

pr=
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

# open_prs: the open pull requests, as number TAB branch TAB URL.
open_prs() {
    gh pr list --state open --limit 200 --json number,headRefName,url \
        --jq '.[] | [.number, .headRefName, .url] | @tsv' </dev/null
}

# The PRs open before the launch; an unreadable list stops the flow, as an
# empty one would make any old PR of the task look new.
snapshot="$(open_prs)" || {
    echo "all: cannot list the open pull requests -- check gh auth status" >&2
    exit 1
}
before=" "
while IFS="$(printf '\t')" read -r n _ _; do
    [ -z "$n" ] || before="$before$n "
done <<<"$snapshot"

# find_pr: sets $pr and $url to the build's pull request.
find_pr() {
    local n head link lines
    lines="$(open_prs)" || return 2
    while IFS="$(printf '\t')" read -r n head link; do
        [ -n "$n" ] || continue
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

# comments: the first line of every comment on the pull request.
comments() {
    gh pr view "$pr" --json comments --jq '.comments[] | (.body | split("\n") | .[0]) // ""' </dev/null
}

# comment_count: how many comments the pull request has now.
comment_count() {
    local lines
    lines="$(comments)" || lines=
    if [ -z "$lines" ]; then echo 0; else wc -l <<<"$lines" | tr -d ' '; fi
}

review_head='^#* *Review: '

# reviews_in SKIP: 0 when every role has a comment after the first SKIP.
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

# fixup_replied SKIP: 0 when a comment after the first SKIP is not a review.
fixup_replied() {
    local lines
    lines="$(comments)" || return 2
    tail -n +$(($1 + 1)) <<<"$lines" | grep -v '^$' | grep -qvE "$review_head" || return 2
}

"$lib/cloud-task.sh" "$arg" --yes --model "$model" || fail "the build of $arg did not start"
echo "all: waiting for the pull request of $arg"
wait_for "the pull request of $arg" "$polls_pr" find_pr || fail "no pull request of $arg appeared"
echo "all: #$pr is open ($url); waiting for CI"
wait_for "CI on #$pr" "$polls_ci" ci_state || fail "CI is not green on #$pr after the build"

echo "all: CI is green on #$pr; starting the reviews"
skip="$(comment_count)"
"$lib/cloud-review.sh" all "$pr" --yes --model "$model" || fail "the reviews of #$pr did not all start"
missing=()
if ! wait_for "the reviews of #$pr" "$polls_reviews" reviews_in "$skip"; then
    fail "no review of #$pr by ${missing[*]}"
fi

echo "all: every role reviewed #$pr; starting the fixup"
skip="$(comment_count)"
"$lib/cloud-fixup.sh" "$pr" --yes --model "$model" || fail "the fixup of #$pr did not start"
wait_for "the fixup of #$pr" "$polls_fixup" fixup_replied "$skip" || fail "the fixup of #$pr never replied"
echo "all: the fixup replied on #$pr; waiting for CI"
wait_for "CI on #$pr" "$polls_ci" ci_state || fail "CI is not green on #$pr after the fixup"

echo "all: CI is green on #$pr after the build, the reviews and the fixup; opening $url"
open_pr
