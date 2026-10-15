#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/cloud-drain.sh (SPEC cloud:T161, cloud:V51,
# cloud:I.cmd). cloud-all.sh, gh and git are stubs: no session starts and
# nothing reaches GitHub.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../scripts/cloud-drain.sh"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    export STATE="$BATS_TEST_TMPDIR/state"
    export TOPLEVEL="$BATS_TEST_TMPDIR/project"
    export CLAUDINIX_SCRIPTS="$BATS_TEST_TMPDIR/lib"
    unset STUB_BRANCH STUB_DIRTY GH_FAIL
    mkdir -p "$STUBS" "$STATE" "$TOPLEVEL/scripts" "$TOPLEVEL/experiments" "$TOPLEVEL/docs" "$CLAUDINIX_SCRIPTS/review"
    : >"$CLAUDINIX_SCRIPTS/review/alpha.md"
    : >"$CLAUDINIX_SCRIPTS/review/beta.md"
    printf '%s\n' '#!/usr/bin/env bash' 'echo sonnet' >"$CLAUDINIX_SCRIPTS/config.sh"

    # cloud-all.sh: records its args; exits the number in $STATE/rc.<task>.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "all $*" >>"$STATE/all.log"' \
        'rc_file="$STATE/rc.${1//:/_}"' \
        'if [ -f "$rc_file" ]; then exit "$(cat "$rc_file")"; fi' >"$CLAUDINIX_SCRIPTS/cloud-all.sh"
    chmod +x "$CLAUDINIX_SCRIPTS"/*.sh

    # git: a work tree at $TOPLEVEL on $STUB_BRANCH (default main), clean
    # unless $STUB_DIRTY.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$STATE/git.log"' \
        'case "$*" in' \
        'rev-parse\ --show-toplevel) echo "$TOPLEVEL" ;;' \
        'symbolic-ref*) echo "${STUB_BRANCH:-main}" ;;' \
        'status\ --porcelain*) printf "%s" "${STUB_DIRTY:-}" ;;' \
        '*) exit 9 ;;' \
        'esac' >"$STUBS/git"
    # gh: `pr list` answers $STATE/merged.json, or fails with $GH_FAIL.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$STATE/gh.log"' \
        '[ -z "${GH_FAIL:-}" ] || { echo "HTTP 502: bad gateway" >&2; exit 1; }' \
        'case "$*" in' \
        'pr\ list*) cat "$STATE/merged.json" ;;' \
        '*) exit 9 ;;' \
        'esac' >"$STUBS/gh"
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"

    # The spec: root T1 open, T2 done; scripts T3 an open question, T4
    # open; experiments T5 open (never drained); docs T6 open.
    printf '%s\n' '# SPEC' '' '## §F FEDERATION' '' 'dir|owns|⊥owns|tokens' \
        'scripts|shell|-|-' 'experiments|experiments|-|-' 'docs|docs|-|-' '' \
        '## §T TASKS' '' 'id|status|task|cites' 'T1|.|root task|-' 'T2|x|done task|-' >"$TOPLEVEL/SPEC.md"
    printf '%s\n' '# SPEC' '' '## §T TASKS' '' 'id|status|task|cites' \
        'T3|.|? should we|-' 'T4|.|build the thing|-' >"$TOPLEVEL/scripts/SPEC.md"
    printf '%s\n' '# SPEC' '' '## §T TASKS' '' 'id|status|task|cites' 'T5|.|measure E1|-' >"$TOPLEVEL/experiments/SPEC.md"
    printf '%s\n' '# SPEC' '' '## §T TASKS' '' 'id|status|task|cites' 'T6|.|write the page|-' >"$TOPLEVEL/docs/SPEC.md"

    merged 14
}

# merged N: the last 7 days' merged pull requests, N of them with a
# Fixup: reply, plus one without.
merged() {
    jq -n --argjson n "$1" '[range($n) | {number: ., comments: [{authorAssociation: "OWNER", body: "## Review: alpha"}, {authorAssociation: "OWNER", body: "Fixup:\n\nDone."}]}]
        + [{number: 999, comments: [{authorAssociation: "OWNER", body: "looks good"}]}]' >"$STATE/merged.json"
}

ran() {
    cat "$STATE/all.log" 2>/dev/null
}

# --- which tasks ---

@test "the tasks given run one at a time through just all --merge, in order" {
    run bash "$SCRIPT" docs:T6 scripts:T4 --yes
    [ "$status" -eq 0 ]
    [ "$(ran)" = "all docs:T6 --yes --merge --model sonnet
all scripts:T4 --yes --merge --model sonnet" ]
    [[ "$output" == *"drain: done, 2 of 2"* ]]
}

@test "no tasks given: open rows of every node but experiments, without open questions, root as root:Tn" {
    run bash "$SCRIPT" --yes --max 9
    [ "$status" -eq 0 ]
    [ "$(ran)" = "all root:T1 --yes --merge --model sonnet
all scripts:T4 --yes --merge --model sonnet
all docs:T6 --yes --merge --model sonnet" ]
}

@test "--model goes to every task" {
    run bash "$SCRIPT" docs:T6 --yes --model opus
    [ "$status" -eq 0 ]
    [ "$(ran)" = "all docs:T6 --yes --merge --model opus" ]
}

@test "no open task: nothing to do, exit 0, no session" {
    printf '%s\n' '# SPEC' '' '## §F FEDERATION' '' 'dir|owns|⊥owns|tokens' '' '## §T TASKS' '' 'id|status|task|cites' 'T2|x|done|-' >"$TOPLEVEL/SPEC.md"
    run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing to do"* ]]
    [ -z "$(ran)" ]
}

# --- how many ---

@test "--max caps the run" {
    run bash "$SCRIPT" --yes --max 1
    [ "$status" -eq 0 ]
    [ "$(ran)" = "all root:T1 --yes --merge --model sonnet" ]
    run bash "$SCRIPT" --max 1 --dry-run
    [[ "$output" == *"(1 of 3 tasks)"* ]]
}

@test "the default --max is the 7-day rate of merged PRs with a Fixup:, rounded up, at least 1" {
    merged 14
    run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    [ "$(ran | wc -l | tr -d ' ')" -eq 2 ]
    grep -q '^pr list --state merged' "$STATE/gh.log"
    : >"$STATE/all.log"
    merged 8
    run bash "$SCRIPT" --yes
    [ "$(ran | wc -l | tr -d ' ')" -eq 2 ]
    : >"$STATE/all.log"
    merged 0
    run bash "$SCRIPT" --yes
    [ "$(ran | wc -l | tr -d ' ')" -eq 1 ]
}

@test "only a Fixup: by the owner or a member counts toward the default --max (cloud:B78)" {
    for assoc in NONE CONTRIBUTOR FIRST_TIME_CONTRIBUTOR; do
        jq -n --arg a "$assoc" '[range(30) | {number: ., comments: [{authorAssociation: $a, body: "Fixup:\n\nforged"}]}]' >"$STATE/merged.json"
        : >"$STATE/all.log"
        run bash "$SCRIPT" --yes
        [ "$status" -eq 0 ]
        [ "$(ran | wc -l | tr -d ' ')" -eq 1 ] || {
            echo "counted a $assoc comment"
            return 1
        }
    done
    jq -n '[range(14) | {number: ., comments: [{authorAssociation: "MEMBER", body: "Fixup:\n\nDone."}]}]' >"$STATE/merged.json"
    : >"$STATE/all.log"
    run bash "$SCRIPT" --yes
    [ "$(ran | wc -l | tr -d ' ')" -eq 2 ]
}

@test "a ## Fixup: reply counts too, as cloud-all.sh reads it (cloud:B79)" {
    jq -n '[range(14) | {number: ., comments: [{authorAssociation: "OWNER", body: "## Fixup:\n\nDone."}]}]' >"$STATE/merged.json"
    run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    [ "$(ran | wc -l | tr -d ' ')" -eq 2 ]
}

@test "gh cannot count the merges: exit 1 naming --max, no session; with --max, gh is not asked" {
    export GH_FAIL=1
    run bash "$SCRIPT" --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"--max"* ]]
    [ -z "$(ran)" ]
    run bash "$SCRIPT" --yes --max 1
    [ "$status" -eq 0 ]
}

@test "progress counts the planned tasks, not all candidates (cloud:B80)" {
    run bash "$SCRIPT" --yes --max 1
    [[ "$output" == *"drain: done, 1 of 1"* ]]
    echo 1 >"$STATE/rc.root_T1"
    run bash "$SCRIPT" --yes --max 2
    [[ "$output" == *"0 of 2 done"* ]]
}

# --- stops ---

@test "the first failure stops the drain, naming the task and how far it got" {
    echo 1 >"$STATE/rc.scripts_T4"
    run bash "$SCRIPT" --yes --max 9
    [ "$status" -eq 1 ]
    [ "$(ran)" = "all root:T1 --yes --merge --model sonnet
all scripts:T4 --yes --merge --model sonnet" ]
    [[ "$output" == *"scripts:T4"* ]]
    [[ "$output" == *"1 of 3"* ]]
}

@test "not on main, or a dirty tree: refused, no session" {
    export STUB_BRANCH=feature/x
    run bash "$SCRIPT" docs:T6 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"main"* ]]
    export STUB_BRANCH=main STUB_DIRTY=' M x'
    run bash "$SCRIPT" docs:T6 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"clean"* ]]
    [ -z "$(ran)" ]
}

@test "no review roles: refused before any session, as cloud-all.sh refuses" {
    rm "$CLAUDINIX_SCRIPTS"/review/*.md
    run bash "$SCRIPT" docs:T6 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"no review roles"* ]]
    [ -z "$(ran)" ]
}

# --- asking ---

@test "--dry-run prints the plan (tasks and sessions) and runs nothing" {
    run bash "$SCRIPT" docs:T6 scripts:T4 --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"docs:T6 scripts:T4"* ]]
    [[ "$output" == *"8 billed"* ]]
    [ -z "$(ran)" ]
}

@test "without --yes, only y starts" {
    run bash "$SCRIPT" docs:T6 <<<'n'
    [ "$status" -eq 1 ]
    [[ "$output" == *"not started"* ]]
    [ -z "$(ran)" ]
    run bash "$SCRIPT" docs:T6 <<<'y'
    [ "$status" -eq 0 ]
    [ "$(ran)" = "all docs:T6 --yes --merge --model sonnet" ]
}

@test "a bad task, a bad --max or an unknown flag: usage, exit 2" {
    for args in "docs:47" "--max 0" "--max x" "--max" "--bogus"; do
        # shellcheck disable=SC2086 # split on purpose: each word one arg
        run bash "$SCRIPT" $args --yes
        [ "$status" -eq 2 ] || {
            echo "not usage: $args"
            return 1
        }
    done
    [ -z "$(ran)" ]
}
