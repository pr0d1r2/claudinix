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
    unset CLOUD_ALL_POLL TASK_REFUSE TASK_FAIL REVIEW_FAIL REVIEW_ONLY FIXUP_SILENT PR_AFTER
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
        'for r in ${REVIEW_ONLY:-alpha beta}; do echo "## Review: $r" >>"$STATE/comments"; done' >"$CLAUDINIX_SCRIPTS/cloud-review.sh"
    # cloud-fixup.sh: posts its one reply.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "fixup $*" >>"$STATE/children.log"' \
        '[ -n "${FIXUP_SILENT:-}" ] || echo "## Fixes pushed" >>"$STATE/comments"' >"$CLAUDINIX_SCRIPTS/cloud-fixup.sh"
    printf '%s\n' '#!/usr/bin/env bash' 'echo sonnet' >"$CLAUDINIX_SCRIPTS/config.sh"
    chmod +x "$CLAUDINIX_SCRIPTS"/*.sh

    # gh answers what the real one prints after --jq. `pr list`: the
    # open PRs, shown only after PR_AFTER calls. statusCheckRollup: the
    # next line of $STATE/ci, one check state per word (the last line
    # stays). comments: the first line of each comment.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$STATE/gh.log"' \
        'case "$*" in' \
        '"pr list"*)' \
        '  n=$(( $(cat "$STATE/list.n" 2>/dev/null || echo 0) + 1 )); echo "$n" >"$STATE/list.n"' \
        '  [ "$n" -le "${PR_AFTER:-0}" ] || cat "$STATE/prs" 2>/dev/null; exit 0 ;;' \
        '*statusCheckRollup*)' \
        '  [ -f "$STATE/ci" ] || exit 0' \
        '  head -n 1 "$STATE/ci" | tr " " "\n" | grep -v "^$"' \
        '  [ "$(wc -l <"$STATE/ci")" -le 1 ] || { tail -n +2 "$STATE/ci" >"$STATE/ci.t"; mv "$STATE/ci.t" "$STATE/ci"; }' \
        '  exit 0 ;;' \
        '*comments*) cat "$STATE/comments" 2>/dev/null; exit 0 ;;' \
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

@test "a PR open before the launch, or of another task, is not the build's" {
    printf '9\tclaude/docs-T47\thttps://github.com/o/p/pull/9\n12\tclaude/docs-t470-x\thttps://github.com/o/p/pull/12\n' >"$STATE/prs"
    run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 0 ]
    grep -q 'review all 14 ' "$STATE/children.log"
    run ! grep -q 'review all 9 \|review all 12 ' "$STATE/children.log"
}

@test "a bare Tn takes the build's PR from any node; case is folded" {
    printf '%b\n' '15\tclaude/Scripts-T47\thttps://github.com/o/p/pull/15' >"$STATE/new_pr"
    run bash "$SCRIPT" T47 --yes
    [ "$status" -eq 0 ]
    grep -q 'review all 15 ' "$STATE/children.log"
}

@test "node:Tn takes only that node's branch" {
    printf '%b\n' '15\tclaude/scripts-t47\thttps://github.com/o/p/pull/15' >"$STATE/new_pr"
    run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"pull request"* ]]
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
    ci SUCCESS CANCELLED
    run bash "$SCRIPT" docs:T47 --yes
    [ "$status" -eq 1 ]
    grep -q '^fixup 14' "$STATE/children.log"
    [[ "$output" == *"CI"* ]]
    [ -s "$STATE/open.log" ]
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

@test "no task, a bad task, two tasks or an unknown flag: usage, no session" {
    for args in "" "docs:47" "T1 T2" "T1 --bogus" "T1 --model"; do
        # shellcheck disable=SC2086 # split on purpose: each word one arg
        run bash "$SCRIPT" $args
        [ "$status" -eq 2 ]
        [[ "$output" == *"usage: cloud-all.sh"* ]]
    done
    [ ! -e "$STATE/children.log" ]
}
