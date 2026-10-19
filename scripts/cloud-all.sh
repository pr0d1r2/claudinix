#!/usr/bin/env bash
# Run a pull request's whole cloud flow from your terminal, waiting for
# each step (SPEC cloud:T135, cloud:T139, .:C29): for a task, build it
# first (cloud-task.sh) and wait for its pull request; then wait for green
# CI, review it by every role (cloud-review.sh all), wait for every role's
# comment, fix the findings up (cloud-fixup.sh), wait for its reply and
# green CI again, then open the pull request in Safari. It merges only
# with --merge, which the owner passes (.:C29).
#
# The argument is a task (`Tn` or `node:Tn`, as for cloud-task.sh) or an
# existing pull request (PR# or its URL, made by hand or by an earlier
# run), which skips the build. Before anything starts, a dry run checks
# it and a refusal exits with its status: cloud-task.sh --dry-run for a
# task (the task, the remote, the pushed branch, the model),
# cloud-fixup.sh --dry-run for a pull request. The children get the
# argument as given.
# One y/N answer, naming how many billed sessions start (1 build for a
# task, 1 per role, 1 fixup) and the model, covers them all; --yes skips
# it, and each child then runs with --yes. --dry-run runs the checks and
# prints the plan instead. --merge ends a green flow with
# cloud-merge.sh --yes (the strict rule, cloud:V51) instead of opening the
# pull request; a stop for the owner exits 1 and opens it.
#
# The sessions run in the cloud; this script only waits, polling GitHub
# with gh every CLOUD_ALL_POLL seconds (default 10) and printing one dot
# per poll. Each wait lasts a fixed number of minutes, counted in polls
# (minutes x 60 / CLOUD_ALL_POLL), never against a wall-clock deadline:
# - the pull request: a newly open one whose branch is
#   claude/<node>-<task>, maybe with the harness's suffix, compared with
#   the case folded (any node for a bare Tn); one open before the launch
#   or from a fork is not it. With no such branch (the harness may name
#   it after the session title, cloud:B90), the one new same-repo pull
#   request whose body names the task id; 2 or more stop the flow,
#   naming them (cloud:T171);
# - CI: the head commit's checks, none pending and none failed (skipped
#   and neutral pass); no checks yet counts as pending, and so does a
#   cancelled one (an outage, or a run a newer push superseded; said once
#   per wait). After the build and after the fixup a red check counts as
#   pending too, for up to 120 minutes: that session fixes it. A pull
#   request given by number fails on its first red run;
# - the reviews: one comment headed "Review: <role>" for every role;
# - the fixup: a comment after its launch headed "Fixup:";
# - the head (cloud:T170, V52): once the fixup has replied, the pull
#   request's head is the sha of its last "Head:" line, else the one
#   reviewed; any other head was pushed by someone else, and the flow
#   stops naming it;
# - conflicts (cloud:T146): once the pull request is known and again
#   after the fixup, a pull request that conflicts with main (it gets no
#   CI) is rebased by cloud-rebase.sh; the flow goes on once a new head
#   is pushed, and stops naming the conflict when none comes.
# A child that fails, red CI (where no session fixes it) or a wait that
# runs out names the step, opens the pull request when there is one, and
# exits 1.
# A wait also ends the flow after 3 failed gh calls in a row (a success
# resets the count): it shows gh's last stderr instead of dots to the limit
# (SPEC cloud:T138).
#
# Usage: cloud-all.sh <node:Tn | Tn | PR# | URL> [--model M] [--yes] [--dry-run] [--merge]
# Env:   CLOUD_ALL_POLL     seconds between polls (default 10)
#        CLAUDINIX_SCRIPTS  dir holding the child launchers, review/ and
#                           config.sh (default: here)

set -euo pipefail

# The longest each wait lasts, in minutes; the table in docs/CLI.md
# mirrors them.
minutes_pr=180
minutes_ci=60
minutes_ci_fix=120 # after a session, which may fix a red run in up to 3 rounds
minutes_reviews=90
minutes_fixup=180
minutes_rebase=60

# The check conclusions: red fails a CI wait (or, after a session, is
# waited out), CLOUD_CI_OK passes it; every other one, a cancelled check
# among them, is pending.
ci_red='^(FAILURE|TIMED_OUT|ERROR|ACTION_REQUIRED|STARTUP_FAILURE)$'

usage() {
    echo "usage: cloud-all.sh <node:Tn | Tn | PR# | URL> [--model M] [--yes] [--dry-run] [--merge]" >&2
    exit 2
}

arg=
model=
yes=0
dry=0
merge=0
while [ "$#" -gt 0 ]; do
    case "$1" in
    --model)
        [ "$#" -ge 2 ] || usage
        model="$2"
        shift
        ;;
    --yes) yes=1 ;;
    --dry-run) dry=1 ;;
    --merge) merge=1 ;;
    -*) usage ;;
    *)
        [ -z "$arg" ] || usage
        arg="$1"
        ;;
    esac
    shift
done
[ -n "$arg" ] || usage

# Absolute: the run may cd into another repo's checkout (cloud:T175).
scripts_dir="${CLAUDINIX_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# shellcheck source=/dev/null # lib/cloud-launch.sh, beside this script
source "$(dirname "${BASH_SOURCE[0]}")/lib/cloud-launch.sh"
want_node= # set by cloud_parse_task
id=
pr=
cloud_parse_pr "$arg" || cloud_parse_task "$arg" || usage
# The mode: $pr is also what find_pr fills after a build, so only this flag
# says a PR was given.
given_pr=
[ -z "$pr" ] || given_pr=1
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
polls_ci_fix="$(polls "$minutes_ci_fix")"
polls_reviews="$(polls "$minutes_reviews")"
polls_fixup="$(polls "$minutes_fixup")"
polls_rebase="$(polls "$minutes_rebase")"

# Another repository's URL is run from its checkout (cloud:T175): every gh
# call below and every child then reads that repository. Without a usable
# checkout nothing changes here, and the fixup dry run below refuses it.
cloud_enter_url_repo all origin || exit 1
if [ -n "$entered_checkout" ]; then
    cloud_read_pr all origin "$arg" || exit 1
    # shellcheck disable=SC2154 # base: set by cloud_read_pr
    cloud_require_checkout_ready all "$entered_checkout" "$base" || exit 1
fi

cloud_resolve_model "$scripts_dir" || exit "$?"
child_args=(--yes --model "$model") # every child runs unasked, on the one model
if [ -n "$given_pr" ]; then
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
if [ -n "$given_pr" ]; then
    sessions="$(cloud_session_count "${#roles[@]}" pr)"
    steps=
    name="#$pr"
else
    sessions="$(cloud_session_count "${#roles[@]}")"
    steps="1 build, "
    name="$arg"
    want_head="$(cloud_branch_regex "$want_node" "$id")"
fi

plan="all: $name runs $sessions billed Claude Code cloud sessions (model $model), one after another: $steps${#roles[@]} reviews (${roles[*]}), 1 fixup; it waits for each and for green CI, up to hours"
[ "$merge" = 0 ] || plan="$plan; then just merge rebase-merges it if the strict rule holds"
if [ "$dry" = 1 ]; then
    echo "$plan"
    exit 0
fi
if [ "$yes" = 0 ]; then
    cloud_flush_input
    cloud_confirm all "$plan. Start? [y/N] " || exit 1
fi

url=
found_by_body=0 # 1 when find_pr took the PR by its body, which --merge never merges (cloud:V55)

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

# gh_err: where a wait check's failed gh call leaves its stderr, for wait_for.
# Only the checks use it; comment_count and the snapshot let gh's stderr
# reach the terminal.
gh_err="$(mktemp)"
burn_posted=0
# On every exit: the burn comment once the PR is known (cloud:V64), then the
# temp file. The exit code is the flow's, whatever post_burn does.
at_exit() {
    local rc=$?
    [ -z "$pr" ] || post_burn || true
    rm -f "$gh_err"
    exit "$rc"
}
trap at_exit EXIT

# The failed gh calls in a row that stop a wait (cloud:B32). The header above and
# docs/CLI.md say 3 too.
max_gh_failures=3

# What a wait's check returns for a failed gh call, and wait_for for the stop.
readonly gh_failed=3

# What find_pr returns for 2 or more pull requests naming the task, after
# it said which: it passes through wait_for like any code but 2 and 3.
readonly ambiguous=4

# wait_failed RC MESSAGE: stop the flow after a failed wait_for. RC 3 (the gh
# stop) and RC 4 (several pull requests name the task) already said why; any
# other RC gets MESSAGE.
wait_failed() {
    if [ "$1" = "$gh_failed" ] || [ "$1" = "$ambiguous" ]; then
        open_pr
        exit 1
    fi
    fail "$2"
}

# wait_for WHAT MAX CHECK...: run CHECK every $poll s until it returns 0
# (done) or 1 (failed); any other code but 2 and 3 (4, say) stops the wait
# and is returned as is; 2 is not yet, printed as a dot; 3 is a failed gh
# call, which counts as not yet until $max_gh_failures come in a row (a
# success resets the count), then stops the wait with gh's last stderr.
# Returns 1 when MAX polls run out.
wait_for() {
    local what="$1" max="$2" i=0 rc gh_failures=0
    shift 2
    while :; do
        rc=0
        : >"$gh_err"
        "$@" || rc=$?
        if [ "$rc" = "$gh_failed" ]; then
            gh_failures=$((gh_failures + 1))
            if [ "$gh_failures" -ge "$max_gh_failures" ]; then
                [ "$i" = 0 ] || echo
                echo "all: gave up waiting for $what: $gh_failures gh calls failed in a row; the last said:" >&2
                cat "$gh_err" >&2
                return "$gh_failed"
            fi
            rc=2
        else
            gh_failures=0
        fi
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
# whether it comes from a fork. No body: the poll runs every few seconds
# for hours (cloud:V56).
open_prs() {
    gh pr list --state open --limit 200 --json number,headRefName,url,isCrossRepository \
        --jq '.[] | [.number, .headRefName, .url, .isCrossRepository] | @tsv' </dev/null
}

# pr_body N: the body of pull request N on one line.
pr_body() {
    gh pr view "$1" --json body --jq '.body // "" | gsub("[\\t\\r\\n]+"; " ")' </dev/null 2>"$gh_err"
}

# The PRs open before the launch; an unreadable list stops the flow, as an
# empty one would make any old PR of the task look new. A given PR needs
# only its URL.
before=" "
if [ -n "$given_pr" ]; then
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

# lower TEXT: TEXT with the case folded; bash 3.2 has no case-folding expansion (cloud:V54).
lower() {
    printf %s "$1" | tr '[:upper:]' '[:lower:]'
}

# find_pr: sets $pr and $url to the build's pull request, never a fork's:
# the new one on the task's branch, else the one new one whose body names
# the task id (cloud:T171), which only an unlisted body can tell; its
# bodies are read after the branch scan found nothing (cloud:V56).
find_pr() {
    local n head link fork lines id_word body candidates=() named=()
    id_word="(^|[^a-z0-9])$(lower "$id")([^a-z0-9]|\$)"
    lines="$(open_prs 2>"$gh_err")" || return "$gh_failed"
    while IFS="$(printf '\t')" read -r n head link fork; do
        [ -n "$n" ] || continue
        [ "$fork" != true ] || continue
        [[ "$before" != *" $n "* ]] || continue
        if [[ "$(lower "$head")" =~ $want_head ]]; then
            pr="$n"
            url="$link"
            return 0
        fi
        candidates+=("$n $link")
    done <<<"$lines"
    for n in "${candidates[@]+"${candidates[@]}"}"; do
        body="$(pr_body "${n%% *}")" || return "$gh_failed"
        if [[ "$(lower "$body")" =~ $id_word ]]; then
            named+=("$n")
        fi
    done
    case "${#named[@]}" in
    0) return 2 ;;
    1)
        read -r pr url <<<"${named[0]}"
        found_by_body=1
        return 0
        ;;
    *)
        printf 'all: %d new pull requests name %s, so none is taken as its build: %s\n' \
            "${#named[@]}" "$id" "$(printf '#%s ' "${named[@]%% *}")" >&2
        return "$ambiguous"
        ;;
    esac
}

# ci_state: the head commit's checks: 0 green, 1 red, 2 pending. A cancelled
# check is pending, not red: a runner outage cancels jobs that never ran
# a step (cloud:B38) and a newer push cancels the run it supersedes, so the
# notice names both causes and none as the one (cloud:B37), once per wait.
cancel_said=
red_said=
ci_fixing=0
ci_state() {
    local states
    states="$(gh pr view "$pr" --json statusCheckRollup --jq '.statusCheckRollup[] |
        if .__typename == "CheckRun" then (if .status == "COMPLETED" then .conclusion else "PENDING" end)
        else .state end' </dev/null 2>"$gh_err")" || return "$gh_failed"
    [ -n "$states" ] || return 2
    if grep -qE "$ci_red" <<<"$states"; then
        [ "$ci_fixing" = 1 ] || {
            echo "all: CI failed on #$pr" >&2
            return 1
        }
        if [ -z "$red_said" ]; then
            printf '\nall: a check on #%s is red; the session is fixing it -- still waiting\n' "$pr" >&2
            red_said=1
        fi
        return 2
    fi
    if [ -z "$cancel_said" ] && grep -qx CANCELLED <<<"$states"; then
        printf '\nall: a check on #%s was cancelled (a runner outage, see https://www.githubstatus.com, or a run a newer push superseded); re-run it (gh run rerun) -- still waiting\n' "$pr" >&2
        cancel_said=1
    fi
    if grep -qvE "$CLOUD_CI_OK" <<<"$states"; then
        return 2
    fi
}

# post_burn: write the pull request's `## Burn` comment (cloud:T177), once:
# before the merge on a green flow, else when the flow stops (cloud:V64).
# Only a note when it fails: the flow's outcome is the CI and the merge, not
# the cost report.
post_burn() {
    [ "$burn_posted" = 0 ] || return 0
    burn_posted=1
    "$scripts_dir/burn.sh" --pr "$pr" --post || echo "all: could not post the burn comment on #$pr" >&2
}

# wait_ci [FIXING]: wait for green CI on #$pr. After a session (FIXING=1) a
# red check waits like a pending one, up to the longer limit: the session
# owns the fix (cloud:T140, T143), and the notices below say once per wait.
wait_ci() {
    local max="$polls_ci"
    ci_fixing="${1:-0}"
    cancel_said=
    red_said=
    [ "$ci_fixing" = 0 ] || max="$polls_ci_fix"
    wait_for "CI on #$pr" "$max" ci_state
}

# comments: the first line of every comment by the owner or a member, without
# the CR a comment written in the web UI ends its lines with (cloud:B99).
comments() {
    gh pr view "$pr" --json comments --jq "$CLOUD_COMMENT_JQ"'.comments[] | trusted | (.body | split("\n") | .[0]) // ""' </dev/null |
        tr -d '\r'
}

# comment_count: how many comments the pull request has now; an unreadable
# list stops the flow, as 0 would make an old comment look new (cloud:B33).
comment_count() {
    local lines
    lines="$(comments)" || fail "cannot read the comments of #$pr -- check gh auth status"
    if [ -z "$lines" ]; then echo 0; else wc -l <<<"$lines" | tr -d ' '; fi
}

review_head="^#* *$CLOUD_REVIEW_HEADING "
fixup_head="$CLOUD_FIXUP_HEADING_RE"

# reviews_in SKIP: 0 when every role has a comment after the first SKIP;
# else 2, with the roles still missing in $missing for the caller's message
# (wait_for runs it in this shell).
reviews_in() {
    local lines r
    lines="$(comments 2>"$gh_err")" || return "$gh_failed"
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
    lines="$(comments 2>"$gh_err")" || return "$gh_failed"
    tail -n +$(($1 + 1)) <<<"$lines" | grep -qE "$fixup_head" || return 2
}

# merge_state: 0 when the pull request merges cleanly into its base, 4 when
# it conflicts, 2 while GitHub has not worked it out. Sets $head_sha, which
# head_moved and resolve_conflicts read right after it (a success or a
# failed gh call leaves the last one read).
head_sha=
merge_state() {
    local out m
    out="$(gh pr view "$pr" --json mergeable,headRefOid --jq '[.mergeable, .headRefOid] | @tsv' </dev/null 2>"$gh_err")" || return "$gh_failed"
    IFS="$(printf '\t')" read -r m head_sha <<<"$out"
    case "$m" in
    MERGEABLE) return 0 ;;
    CONFLICTING) return 4 ;;
    *) return 2 ;;
    esac
}

# read_head: sets $head_sha to the pull request's head; a failed gh call
# stops the flow (the head is the one thing V52 compares).
read_head() {
    local rc=0
    merge_state || rc=$?
    [ "$rc" != "$gh_failed" ] || fail "cannot read the head of #$pr -- check gh auth status"
}

# fixup_pushed_head SKIP: the sha on the last "Head:" line of the last
# "Fixup:" reply after the first SKIP, as cloud-fixup-prompt.txt tells the
# session; empty when the reply has none (nothing was pushed).
fixup_pushed_head() {
    gh pr view "$pr" --json comments --jq "$CLOUD_COMMENT_JQ"'[.comments[] | trusted]['"$1"':] | map(select(fixup_reply)) | last | head_of // empty' </dev/null
}

# require_fixup_head SKIP REVIEWED: stop the flow unless the pull request's
# head is the sha the fixup pushed, else the one reviewed (cloud:V52): a
# head that moved otherwise was pushed by someone else.
require_fixup_head() {
    local pushed expected source
    pushed="$(fixup_pushed_head "$1")" || fail "cannot read the fixup reply of #$pr -- check gh auth status"
    expected="${pushed:-$2}"
    if [ -n "$pushed" ]; then source="the sha the fixup pushed"; else source="the reviewed sha; the fixup pushed none"; fi
    read_head
    [ "$head_sha" = "$expected" ] ||
        fail "the head of #$pr is $head_sha, not $expected ($source): someone else pushed, so it is not taken"
}

# head_moved OLD: 0 once the pull request's head is no longer OLD.
head_moved() {
    local rc=0
    merge_state || rc=$?
    [ "$rc" != "$gh_failed" ] || return "$gh_failed"
    if [ -n "$head_sha" ] && [ "$head_sha" != "$1" ]; then return 0; fi
    return 2
}

# resolve_conflicts: a pull request that conflicts with main gets no CI, so
# send the rebase agent (cloud-rebase.sh, cloud:T145) and wait for the
# head it pushes; no new head means a conflict the owner must settle.
resolve_conflicts() {
    local rc=0 old
    wait_for "GitHub to say whether #$pr merges" "$polls_ci" merge_state || rc=$?
    case "$rc" in
    0) return 0 ;;
    4) ;;
    *) wait_failed "$rc" "GitHub never said whether #$pr merges" ;;
    esac
    old="$head_sha"
    echo "all: #$pr conflicts with main; starting a rebase"
    "$scripts_dir/cloud-rebase.sh" "$target" "${child_args[@]}" || fail "the rebase of #$pr did not start"
    wait_for "the rebase of #$pr" "$polls_rebase" head_moved "$old" ||
        wait_failed $? "the rebase of #$pr pushed no new head: a conflict needs the owner"
}

if [ -n "$given_pr" ]; then
    target="$arg" # the children check a URL's repo themselves
    built=
    resolve_conflicts
    echo "all: waiting for CI on #$pr ($url)"
    wait_ci || wait_failed $? "CI is not green on #$pr"
else
    "$scripts_dir/cloud-task.sh" "$arg" "${child_args[@]}" || fail "the build of $arg did not start"
    echo "all: waiting for the pull request of $arg"
    wait_for "the pull request of $arg" "$polls_pr" find_pr || wait_failed $? "no pull request of $arg appeared"
    target="$pr"
    built="the build, "
    resolve_conflicts
    echo "all: #$pr is open ($url); waiting for CI"
    wait_ci 1 || wait_failed $? "CI is not green on #$pr after the build"
fi

echo "all: CI is green on #$pr; starting the reviews"
skip="$(comment_count)"
"$scripts_dir/cloud-review.sh" all "$target" "${child_args[@]}" || fail "the reviews of #$pr did not all start"
missing=()
wait_for "the reviews of #$pr" "$polls_reviews" reviews_in "$skip" || wait_failed $? "no review of #$pr by ${missing[*]}"

echo "all: every role reviewed #$pr; starting the fixup"
skip="$(comment_count)"
read_head
reviewed_head="$head_sha"
"$scripts_dir/cloud-fixup.sh" "$target" "${child_args[@]}" || fail "the fixup of #$pr did not start"
wait_for "the fixup of #$pr" "$polls_fixup" fixup_replied "$skip" || wait_failed $? "the fixup of #$pr never replied"
require_fixup_head "$skip" "$reviewed_head"
resolve_conflicts
echo "all: the fixup replied on #$pr; waiting for CI"
wait_ci 1 || wait_failed $? "CI is not green on #$pr after the fixup"

post_burn
if [ "$merge" = 1 ] && [ "$found_by_body" = 1 ]; then
    fail "#$pr was found by its body naming $id, not by its branch, so it is not merged: the owner merges it"
fi
if [ "$merge" = 1 ]; then
    echo "all: CI is green on #$pr after ${built}the reviews and the fixup; merging"
    "$scripts_dir/cloud-merge.sh" "$pr" --yes || fail "#$pr stops for the owner (see above)"
    exit 0
fi
echo "all: CI is green on #$pr after ${built}the reviews and the fixup; opening $url"
open_pr
