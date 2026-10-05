#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/cloud-all.sh (SPEC scripts:T135, .:C29). The
# child launchers (cloud-task.sh, cloud-review.sh, cloud-fixup.sh), gh,
# sleep and open are stubs: no session starts, nothing reaches GitHub and
# nothing waits.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../scripts/cloud-all.sh"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    export CLAUDINIX_SCRIPTS="$BATS_TEST_TMPDIR/lib"
    export STATE="$BATS_TEST_TMPDIR/state"
    # Long polls keep the timed-out waits to a few polls each.
    export CLOUD_ALL_POLL=600
    unset TASK_REFUSE REBASE_SILENT FIXUP_REFUSE TASK_FAIL REVIEW_FAIL REVIEW_ONLY FIXUP_SILENT FIXUP_BOT REVIEW_CRLF PR_AFTER LIST_FAIL_FIRST COMMENTS_FAIL_FIRST URL_FAIL CI_GH_FAILS COMMENTS_GH_FAILS LIST_GH_FAILS
    mkdir -p "$STUBS" "$STATE" "$CLAUDINIX_SCRIPTS/review"
    : >"$CLAUDINIX_SCRIPTS/review/alpha.md"
    : >"$CLAUDINIX_SCRIPTS/review/beta.md"
    # What the build's pull request looks like once it is open.
    printf '%b\n' '14\tclaude/docs-t47-dk9i03\thttps://github.com/o/p/pull/14' >"$STATE/new_pr"

    # cloud-task.sh: --dry-run checks only; a launch opens the PR.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "task $*" >>"$STATE/children.log"' \
        'if [[ " $* " == *" --dry-run "* ]]; then' \
        '  [ -z "${TASK_REFUSE:-}" ] || { echo "cloud: no task $1 in docs/SPEC.md" >&2; exit 1; }' \
        '  echo "claude --cloud ..."; exit 0' \
        'fi' \
        '[ -z "${TASK_FAIL:-}" ] || exit 1' \
        'cat "$STATE/new_pr" >>"$STATE/prs"' >"$CLAUDINIX_SCRIPTS/cloud-task.sh"
    # cloud-review.sh: each role posts its comment.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "review $*" >>"$STATE/children.log"' \
        '[ -z "${REVIEW_FAIL:-}" ] || exit 1' \
        'for r in ${REVIEW_ONLY:-alpha beta}; do printf "## Review: %s%b\n" "$r" "${REVIEW_CRLF:+\\r}" >>"$STATE/comments"; done' >"$CLAUDINIX_SCRIPTS/cloud-review.sh"
    # cloud-fixup.sh: --dry-run checks only; a launch posts its one reply.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "fixup $*" >>"$STATE/children.log"' \
        'if [[ " $* " == *" --dry-run "* ]]; then' \
        '  [ -z "${FIXUP_REFUSE:-}" ] || { echo "fixup: #$1 is MERGED, not OPEN -- nothing to fix up" >&2; exit 1; }' \
        '  exit 0' \
        'fi' \
        '[ -z "${FIXUP_BOT:-}" ] || echo "Coverage 92%" >>"$STATE/comments"' \
        '[ -n "${FIXUP_SILENT:-}" ] || [ -n "${FIXUP_BOT:-}" ] || echo "## Fixup: pushed" >>"$STATE/comments"' >"$CLAUDINIX_SCRIPTS/cloud-fixup.sh"
    # cloud-rebase.sh: pushes a new head that merges cleanly.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "rebase $*" >>"$STATE/children.log"' \
        '[ -n "${REBASE_SILENT:-}" ] || echo "MERGEABLE bbb" >"$STATE/merge"' >"$CLAUDINIX_SCRIPTS/cloud-rebase.sh"
    printf '%s\n' '#!/usr/bin/env bash' 'echo sonnet' >"$CLAUDINIX_SCRIPTS/config.sh"
    chmod +x "$CLAUDINIX_SCRIPTS"/*.sh

    # gh answers what the real one prints after --jq. `pr list`: the
    # open PRs, shown only after PR_AFTER calls. statusCheckRollup: the
    # next line of $STATE/ci, one check state per word (the last line
    # stays). comments: the first line of each comment.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$STATE/gh.log"' \
        'gh_fails() { [ "${1:$(($2 - 1)):1}" != f ] || { echo "HTTP 502: bad gateway" >&2; exit 1; }; }' \
        'case "$*" in' \
        '"pr list"*)' \
        '  n=$(( $(cat "$STATE/list.n" 2>/dev/null || echo 0) + 1 )); echo "$n" >"$STATE/list.n"' \
        '  [ -z "${LIST_FAIL_FIRST:-}" ] || [ "$n" -ne 1 ] || exit 1' \
        '  gh_fails "${LIST_GH_FAILS:-}" "$n"' \
        '  [ "$n" -le "${PR_AFTER:-0}" ] || cat "$STATE/prs" 2>/dev/null; exit 0 ;;' \
        '*mergeable*) tr " " "\t" <"$STATE/merge"; exit 0 ;;' \
        '*statusCheckRollup*)' \
        '  n=$(( $(cat "$STATE/ci.n" 2>/dev/null || echo 0) + 1 )); echo "$n" >"$STATE/ci.n"' \
        '  gh_fails "${CI_GH_FAILS:-}" "$n"' \
        '  [ -f "$STATE/ci" ] || exit 0' \
        '  head -n 1 "$STATE/ci" | tr " " "\n" | grep -v "^$"' \
        '  [ "$(wc -l <"$STATE/ci")" -le 1 ] || { tail -n +2 "$STATE/ci" >"$STATE/ci.t"; mv "$STATE/ci.t" "$STATE/ci"; }' \
        '  exit 0 ;;' \
        '*"--json url"*) [ -z "${URL_FAIL:-}" ] || exit 1; echo "https://github.com/o/p/pull/$3"; exit 0 ;;' \
        '*comments*)' \
        '  n=$(( $(cat "$STATE/comments.n" 2>/dev/null || echo 0) + 1 )); echo "$n" >"$STATE/comments.n"' \
        '  [ -z "${COMMENTS_FAIL_FIRST:-}" ] || [ "$n" -ne 1 ] || exit 1' \
        '  gh_fails "${COMMENTS_GH_FAILS:-}" "$n"' \
        '  cat "$STATE/comments" 2>/dev/null; exit 0 ;;' \
        'esac' \
        'exit 9' >"$STUBS/gh"
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' 'echo "$*" >>"$STATE/sleep.log"' >"$STUBS/sleep"
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' 'echo "$*" >>"$STATE/open.log"' >"$STUBS/open"
    printf '%s\n' '#!/usr/bin/env bash' 'echo Darwin' >"$STUBS/uname"
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"
    echo SUCCESS >"$STATE/ci"
    echo "MERGEABLE aaa" >"$STATE/merge"
}

# ci LINE...: what the CI checks show, one poll per LINE.
ci() {
    printf '%s\n' "$@" >"$STATE/ci"
}

# --- the whole flow ---

@test "builds, waits for CI, reviews by every role, fixes up, waits for CI, opens Safari" {
    run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE/children.log")" = "task docs:T47 --dry-run --model sonnet
task docs:T47 --yes --model sonnet
review all 14 --yes --model sonnet
fixup 14 --yes --model sonnet" ]
    [ "$(cat "$STATE/open.log")" = "-a Safari https://github.com/o/p/pull/14" ]
    [[ "$output" == *"#14"* ]]
    [[ "$output" == *"green"* ]]
}

@test "--model is passed to every child" {
    run bash "$SCRIPT" docs:T47 --yes --model opus
    [ "$status" -eq 0 ]
    [ "$(grep -c -- '--model opus$' "$STATE/children.log")" -eq 4 ]
}

# --- finding the pull request ---

@test "waits for the PR, polling every CLOUD_ALL_POLL seconds" {
    PR_AFTER=3 CLOUD_ALL_POLL=7 run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 0 ]
    [ "$(grep -c '^7$' "$STATE/sleep.log")" -ge 2 ]
    grep -q 'review all 14' "$STATE/children.log"
}

@test "by default polls every 10 s, one dot per poll" {
    unset CLOUD_ALL_POLL
    PR_AFTER=3 run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 0 ]
    [ "$(grep -c "^10$" "$STATE/sleep.log")" -ge 2 ]
    [[ "$output" == *".."* ]]
}

@test "a PR open before the launch, or of another task, is not the build's" {
    printf '9\tclaude/docs-T47\thttps://github.com/o/p/pull/9\n12\tclaude/docs-t470-x\thttps://github.com/o/p/pull/12\n' >"$STATE/prs"
    run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 0 ]
    grep -q 'review all 14 ' "$STATE/children.log"
    run ! grep -q 'review all 9 \|review all 12 ' "$STATE/children.log"
}

@test "an unreadable PR list before the launch: refused, no session, an old PR is not adopted" {
    printf '9\tclaude/docs-t47-old\thttps://github.com/o/p/pull/9\n' >"$STATE/prs"
    LIST_FAIL_FIRST=1 run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"cannot list"* ]]
    run ! grep -q -- '--yes' "$STATE/children.log"
}

@test "a bare Tn takes the build's PR from any node; case is folded" {
    printf '%b\n' '15\tclaude/Scripts-T47\thttps://github.com/o/p/pull/15' >"$STATE/new_pr"
    run bash "$SCRIPT" T47 --yes
    [ "$status" -eq 0 ]
    grep -q 'review all 15 ' "$STATE/children.log"
}

@test "a PR from a fork is not the build's, even with the right branch name" {
    printf '%b\n' '15\tclaude/docs-t47-x\thttps://github.com/o/p/pull/15\ttrue' >"$STATE/new_pr"
    run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"no pull request of docs:T47"* ]]
    run ! grep -q '^review' "$STATE/children.log"
}

@test "node:Tn takes only that node's branch" {
    printf '%b\n' '15\tclaude/scripts-t47\thttps://github.com/o/p/pull/15' >"$STATE/new_pr"
    run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"pull request"* ]]
    [[ "$output" == *"after 18 polls of 600s"* ]]
    run ! grep -q '^review' "$STATE/children.log"
}

# --- CI ---

@test "CI with no checks yet or pending is waited for; skipped counts as passed" {
    ci "" "PENDING SUCCESS" "SUCCESS SKIPPED"
    run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 0 ]
    [ "$(wc -l <"$STATE/sleep.log")" -ge 2 ]
    grep -q 'review all 14' "$STATE/children.log"
}

@test "CI red after the build: no review, exit 1, opens the PR" {
    ci "SUCCESS FAILURE"
    run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"CI"* ]]
    [[ "$output" == *"#14"* ]]
    run ! grep -q '^review' "$STATE/children.log"
    [ "$(cat "$STATE/open.log")" = "-a Safari https://github.com/o/p/pull/14" ]
}

@test "CI red after the fixup: exit 1, opens the PR" {
    ci SUCCESS FAILURE
    run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    grep -q '^fixup 14' "$STATE/children.log"
    [[ "$output" == *"CI"* ]]
    [ -s "$STATE/open.log" ]
}

@test "red after the build waits: the session fixes it, and the flow goes on once CI is green (scripts:T143)" {
    ci FAILURE FAILURE SUCCESS
    run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 0 ]
    [[ "$output" != *"CI failed"* ]]
    [[ "$output" == *"fixing"* ]]
    grep -q '^review all 14' "$STATE/children.log"
}

@test "red after the fixup waits as well, and the flow ends green (scripts:T143)" {
    ci SUCCESS FAILURE SUCCESS
    run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 0 ]
    [[ "$output" != *"CI failed"* ]]
    [[ "$output" == *"fixing"* ]]
    [ -s "$STATE/open.log" ]
}

@test "red that never clears runs the wait out: exit 1 \"gave up\", not an instant failure (scripts:T143)" {
    ci FAILURE
    run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"gave up waiting for CI on #14"* ]]
    [[ "$output" != *"CI failed"* ]]
    run ! grep -q '^review' "$STATE/children.log"
}

@test "a cancelled check (runner outage) is not red: it waits, says so once, and goes on when CI passes (scripts:T141)" {
    ci CANCELLED CANCELLED SUCCESS
    run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"cancelled"* ]]
    [[ "$output" == *"githubstatus.com"* ]]
    [[ "$output" != *"CI failed"* ]]
    [ "$(grep -c "githubstatus.com" <<<"$output")" -eq 1 ]
    grep -q "^review all 14" "$STATE/children.log"
}

@test "a cancelled check is not blamed on a runner outage alone: a superseded run ends cancelled too (scripts:B37)" {
    ci CANCELLED SUCCESS
    run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"superseded"* ]]
    [[ "$output" != *"likely a runner outage"* ]]
}

@test "the cancelled notice is said once per CI wait: a second outage after the fixup is said again (scripts:B37)" {
    ci CANCELLED SUCCESS CANCELLED SUCCESS
    run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 0 ]
    [ "$(grep -c "githubstatus.com" <<<"$output")" -eq 2 ]
}

@test "a check that stays cancelled times out naming githubstatus.com, not a CI failure (scripts:T141)" {
    ci CANCELLED
    run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"githubstatus.com"* ]]
    [[ "$output" == *"gave up waiting for CI on #14"* ]]
    [[ "$output" == *"CI is not green on #14 after the build"* ]]
    run ! grep -q "^review" "$STATE/children.log"
}

# --- reviews and the fixup ---

@test "waits for a review by every role; a missing one times out naming it, no fixup" {
    REVIEW_ONLY=alpha run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"beta"* ]]
    run ! grep -q '^fixup' "$STATE/children.log"
    [ -s "$STATE/open.log" ]
}

@test "a review comment is not the fixup's reply; no reply times out" {
    FIXUP_SILENT=1 run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"fixup"* ]]
    [ -s "$STATE/open.log" ]
}

@test "another comment during the fixup is not its reply: it times out" {
    FIXUP_BOT=1 run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"the fixup of #14 never replied"* ]]
    [ -s "$STATE/open.log" ]
}

@test "a CRLF comment (written in the web UI) still matches its heading" {
    REVIEW_CRLF=1 run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 0 ]
    grep -q '^fixup 14' "$STATE/children.log"
}

@test "a child that fails stops the flow naming its stage" {
    TASK_FAIL=1 run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"build"* ]]
    run ! grep -q '^review' "$STATE/children.log"
    [ ! -e "$STATE/open.log" ]
    rm -f "$STATE/children.log"
    REVIEW_FAIL=1 run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"review"* ]]
    run ! grep -q '^fixup' "$STATE/children.log"
    [ -s "$STATE/open.log" ]
}

# --- before anything starts ---

@test "the build's checks refuse: its exit, no session, no question" {
    TASK_REFUSE=1 run bash "$SCRIPT" docs:T47
    [ "$status" -eq 1 ]
    [[ "$output" == *"no task docs:T47"* ]]
    [ "$(cat "$STATE/children.log")" = "task docs:T47 --dry-run --model sonnet" ]
    [[ "$output" != *"[y/N]"* ]]
}

@test "one y/N names the session count and the model; only y starts" {
    run bash "$SCRIPT" docs:T47 <<<"n"
    [ "$status" -eq 1 ]
    [[ "$output" == *"4 billed"* ]]
    [[ "$output" == *"sonnet"* ]]
    [[ "$output" == *"not started"* ]]
    [ "$(wc -l <"$STATE/children.log")" -eq 1 ]
    run bash "$SCRIPT" docs:T47 <<<"y"
    [ "$status" -eq 0 ]
    grep -q '^fixup 14' "$STATE/children.log"
}

@test "--dry-run runs the checks and prints the plan, no session" {
    run bash "$SCRIPT" docs:T47 --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"4 "* ]]
    [[ "$output" == *"alpha"* ]]
    [ "$(cat "$STATE/children.log")" = "task docs:T47 --dry-run --model sonnet" ]
    [[ "$output" != *"[y/N]"* ]]
}

@test "no review roles: refused before any session" {
    rm "$CLAUDINIX_SCRIPTS"/review/*.md
    run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"review"* ]]
    run ! grep -q -- '--yes' "$STATE/children.log"
}

@test "a CLOUD_ALL_POLL that is not a positive integer: exit 2 naming it, no session" {
    for bad in 0 abc -5 1.5 ""; do
        CLOUD_ALL_POLL="$bad" run bash "$SCRIPT" docs:T47 --yes
        [ "$status" -eq 2 ]
        [[ "$output" == *"CLOUD_ALL_POLL"* ]]
        [[ "$output" == *"'$bad'"* ]]
    done
    [ ! -e "$STATE/children.log" ]
}

@test "no task, a bad task, two tasks or an unknown flag: usage, no session" {
    for args in "" "docs:47" "T1 T2" "T1 --bogus" "T1 --model"; do
        # shellcheck disable=SC2086 # split on purpose: each word one arg
        run bash "$SCRIPT" $args
        [ "$status" -eq 2 ]
        [[ "$output" == *"usage: cloud-all.sh"* ]]
    done
    [ ! -e "$STATE/children.log" ]
}

# --- an existing pull request (scripts:T139) ---

@test "a PR number: no build; checks as fixup, then CI, reviews, fixup, CI, opens it" {
    run bash "$SCRIPT" 16 --yes
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE/children.log")" = "fixup 16 --dry-run --model sonnet
review all 16 --yes --model sonnet
fixup 16 --yes --model sonnet" ]
    [ "$(cat "$STATE/open.log")" = "-a Safari https://github.com/o/p/pull/16" ]
    run ! grep -q '^pr list' "$STATE/gh.log"
}

@test "a PR URL is passed to the children as given" {
    run bash "$SCRIPT" https://github.com/o/p/pull/16 --yes
    [ "$status" -eq 0 ]
    grep -q '^review all https://github.com/o/p/pull/16 --yes' "$STATE/children.log"
    grep -q '^fixup https://github.com/o/p/pull/16 --yes' "$STATE/children.log"
}

@test "a PR the fixup checks refuse: its exit, no session, no question" {
    FIXUP_REFUSE=1 run bash "$SCRIPT" 16
    [ "$status" -eq 1 ]
    [[ "$output" == *"#16 is MERGED"* ]]
    [[ "$output" != *"[y/N]"* ]]
    [ "$(cat "$STATE/children.log")" = "fixup 16 --dry-run --model sonnet" ]
}

@test "a PR: the y/N and the plan count the reviews and the fixup only" {
    run bash "$SCRIPT" 16 --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"3 billed"* ]]
    [[ "$output" != *"build"* ]]
    run bash "$SCRIPT" 16 <<<"n"
    [ "$status" -eq 1 ]
    [[ "$output" == *"3 billed"* ]]
    [ "$(wc -l <"$STATE/children.log")" -eq 2 ]
}

@test "a PR whose CI is red: no review, exit 1, opens it" {
    ci FAILURE
    run bash "$SCRIPT" 16 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"#16"* ]]
    [ -s "$STATE/open.log" ]
    run ! grep -q '^review' "$STATE/children.log"
}

@test "an unreadable PR URL: exit 1 naming the PR, no review or fixup starts" {
    URL_FAIL=1 run bash "$SCRIPT" 14 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"could not read pull request #14"* ]]
    run ! grep -q -- '--yes' "$STATE/children.log"
}

@test "an unreadable comment count on a PR with old reviews: exit 1, no review starts (B33)" {
    printf '## Review: alpha\n## Review: beta\n## Fixup: old\n' >"$STATE/comments"
    COMMENTS_FAIL_FIRST=1 run bash "$SCRIPT" 14 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"#14"* ]]
    run ! grep -q 'review all' "$STATE/children.log"
}

# --- three failed gh calls in a row (T138, B32) ---
# CI_GH_FAILS / COMMENTS_GH_FAILS / LIST_GH_FAILS: one letter per gh call
# of that kind, f = fails with stderr, anything else answers. The script
# reads the comments once before each child launch (the count the wait
# skips), so those calls take a leading s.

@test "3 failed gh calls in a row in the CI wait: shows gh's stderr, names the step, opens the PR, exit 1" {
    CI_GH_FAILS=fff run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"HTTP 502: bad gateway"* ]]
    [[ "$output" == *"CI on #14"* ]]
    [[ "$output" == *"3 gh calls failed in a row"* ]]
    [[ "$output" != *"not green"* ]]
    [ "$(cat "$STATE/open.log")" = "-a Safari https://github.com/o/p/pull/14" ]
    run ! grep -q 'review all' "$STATE/children.log"
}

@test "a success resets the count: 2 failures, a success, 2 failures go on" {
    ci PENDING SUCCESS
    CI_GH_FAILS=ffsff run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 0 ]
    grep -q 'fixup 14 ' "$STATE/children.log"
}

@test "3 failed gh calls in a row in the review wait: stops, shows stderr, names the step" {
    # s: the count before the reviews; fff: the wait's first 3 polls
    COMMENTS_GH_FAILS=sfff run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"HTTP 502: bad gateway"* ]]
    [[ "$output" == *"the reviews of #14"* ]]
    [[ "$output" != *"no review of"* ]]
    [ "$(cat "$STATE/open.log")" = "-a Safari https://github.com/o/p/pull/14" ]
    run ! grep -q 'fixup 14 ' "$STATE/children.log"
}

@test "3 failed gh calls in a row in the PR wait: stops, shows stderr, names the step, starts no review" {
    # s: the snapshot before the launch; fff: the wait's first 3 polls
    LIST_GH_FAILS=sfff run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"HTTP 502: bad gateway"* ]]
    [[ "$output" == *"the pull request of docs:T47"* ]]
    [[ "$output" == *"3 gh calls failed in a row"* ]]
    [[ "$output" != *"appeared"* ]]
    run ! grep -q 'review all' "$STATE/children.log"
}

@test "3 failed gh calls in a row in the fixup wait: stops, shows stderr, names the step" {
    # sss: the counts before the reviews and the fixup, the review poll; fff: the fixup polls
    COMMENTS_GH_FAILS=sssfff run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"HTTP 502: bad gateway"* ]]
    [[ "$output" == *"the fixup of #14"* ]]
    [[ "$output" == *"3 gh calls failed in a row"* ]]
    [[ "$output" != *"never replied"* ]]
    [ "$(cat "$STATE/open.log")" = "-a Safari https://github.com/o/p/pull/14" ]
}

# --- conflicts (scripts:T146) ---

@test "a PR that conflicts with main is rebased by a cloud agent, then the flow goes on" {
    echo "CONFLICTING aaa" >"$STATE/merge"
    run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE/children.log")" = "task docs:T47 --dry-run --model sonnet
task docs:T47 --yes --model sonnet
rebase 14 --yes --model sonnet
review all 14 --yes --model sonnet
fixup 14 --yes --model sonnet" ]
    [[ "$output" == *"conflict"* ]]
}

@test "a rebase that pushes no new head stops the flow naming the conflict, no review" {
    echo "CONFLICTING aaa" >"$STATE/merge"
    REBASE_SILENT=1 run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"conflict"* ]]
    [[ "$output" == *"#14"* ]]
    [ -s "$STATE/open.log" ]
    run ! grep -q '^review' "$STATE/children.log"
}
