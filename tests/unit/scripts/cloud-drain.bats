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
    unset STUB_BRANCH STUB_DIRTY STUB_ORIGIN GH_REPO GH_FAIL CLOUD_DRAIN_PR_LIMIT
    mkdir -p "$STUBS" "$STATE" "$TOPLEVEL/scripts" "$TOPLEVEL/experiments" "$TOPLEVEL/docs" "$CLAUDINIX_SCRIPTS/review"
    : >"$CLAUDINIX_SCRIPTS/review/alpha.md"
    : >"$CLAUDINIX_SCRIPTS/review/beta.md"
    printf '%s\n' '#!/usr/bin/env bash' 'echo sonnet' >"$CLAUDINIX_SCRIPTS/config.sh"

    # cloud-all.sh: records its args, and GH_REPO in all.gh_repo; exits the
    # number in $STATE/rc.<task>.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "all $*" >>"$STATE/all.log"' \
        'echo "${GH_REPO:-}" >>"$STATE/all.gh_repo"' \
        'rc_file="$STATE/rc.${1//:/_}"' \
        'if [ -f "$rc_file" ]; then exit "$(cat "$rc_file")"; fi' >"$CLAUDINIX_SCRIPTS/cloud-all.sh"
    chmod +x "$CLAUDINIX_SCRIPTS"/*.sh

    # git: a work tree at $TOPLEVEL on $STUB_BRANCH (default main), clean
    # unless $STUB_DIRTY, its origin $STUB_ORIGIN (default o/p).
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$STATE/git.log"' \
        'case "$*" in' \
        'rev-parse\ --show-toplevel) echo "$TOPLEVEL" ;;' \
        'symbolic-ref*) echo "${STUB_BRANCH:-main}" ;;' \
        'remote\ get-url\ origin) echo "${STUB_ORIGIN:-https://github.com/o/p.git}" ;;' \
        'status\ --porcelain*) printf "%s" "${STUB_DIRTY:-}" ;;' \
        '*) exit 9 ;;' \
        'esac' >"$STUBS/git"
    # gh: `pr list --state open` answers $STATE/open.json, another `pr list`
    # $STATE/merged.json; every call fails with $GH_FAIL.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$STATE/gh.log"' \
        '[ -z "${GH_FAIL:-}" ] || { echo "HTTP 502: bad gateway" >&2; exit 1; }' \
        'case "$*" in' \
        'pr\ list\ --state\ open*) cat "$STATE/open.json" ;;' \
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
    grep -qF '"Fixup:" in:comments' "$STATE/gh.log"
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

@test "the pace window starts at a UTC time 7×24 h back, not at a date's midnight (cloud:T195)" {
    run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    grep -Eq 'merged:>=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z ' "$STATE/gh.log"
}

@test "gh listing as many merges as the limit: exit 1 naming --max, no session (cloud:T195)" {
    jq -n '[range(200) | {number: ., comments: [{authorAssociation: "OWNER", body: "Fixup:\n\nDone."}]}]' >"$STATE/merged.json"
    run bash "$SCRIPT" --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"200"* ]]
    [[ "$output" == *"--max"* ]]
    [ -z "$(ran)" ]
    jq -n '[range(199) | {number: ., comments: [{authorAssociation: "OWNER", body: "Fixup:\n\nDone."}]}]' >"$STATE/merged.json"
    run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
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

# --- --prs: open pull requests instead of tasks (cloud:T182) ---

# open_prs N:HEAD...: your open pull requests, as gh lists them.
open_prs() {
    printf '%s\n' "$@" | jq -R 'split(":") | {number: (.[0] | tonumber), headRefName: (.[1:] | join(":"))}' | jq -s . >"$STATE/open.json"
}

@test "--prs PR...: the pull requests given run one at a time through just all --merge, in order" {
    run bash "$SCRIPT" --prs 31 https://github.com/o/p/pull/7 --yes
    [ "$status" -eq 0 ]
    [ "$(ran)" = "all 31 --yes --merge --model sonnet
all https://github.com/o/p/pull/7 --yes --merge --model sonnet" ]
    [[ "$output" == *"drain: done, 2 of 2"* ]]
}

@test "--prs alone: your open claude/* pull requests, oldest first" {
    open_prs 31:claude/docs-t6-ab12 12:feature/x 7:claude/scripts-t4-cd34
    run bash "$SCRIPT" --prs --yes --max 9
    [ "$status" -eq 0 ]
    [ "$(ran)" = "all 7 --yes --merge --model sonnet
all 31 --yes --merge --model sonnet" ]
    grep -q -- '--author @me' "$STATE/gh.log"
    grep -q -- '--limit 1000' "$STATE/gh.log"
}

@test "--prs: no open claude/* pull request of yours: nothing to do, exit 0, no session" {
    open_prs 12:feature/x
    run bash "$SCRIPT" --prs --yes --max 9
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing to do"* ]]
    [ -z "$(ran)" ]
}

@test "--prs: gh cannot list the open pull requests: exit 1, no session" {
    GH_FAIL=1 run bash "$SCRIPT" --prs --yes --max 9
    [ "$status" -eq 1 ]
    [[ "$output" == *"open pull requests"* ]]
    [ -z "$(ran)" ]
}

@test "--prs needs neither main nor a clean tree: each pull request is rebased in the cloud" {
    STUB_BRANCH=feature/x STUB_DIRTY=' M x' run bash "$SCRIPT" --prs 31 --yes
    [ "$status" -eq 0 ]
    [ "$(ran)" = "all 31 --yes --merge --model sonnet" ]
}

@test "--prs: the first failure stops the drain, naming the pull request and how far it got" {
    open_prs 7:claude/a 31:claude/b 40:claude/c
    echo 1 >"$STATE/rc.31"
    run bash "$SCRIPT" --prs --yes --max 9
    [ "$status" -eq 1 ]
    [ "$(ran)" = "all 7 --yes --merge --model sonnet
all 31 --yes --merge --model sonnet" ]
    [[ "$output" == *"#31"* ]]
    [[ "$output" == *"1 of 3"* ]]
}

@test "--prs --dry-run: the plan names the pull requests and the most sessions they may bill; --max caps it" {
    open_prs 7:claude/a 31:claude/b
    run bash "$SCRIPT" --prs --dry-run --max 9
    [ "$status" -eq 0 ]
    [[ "$output" == *"#7 #31 (2 of 2 pull requests)"* ]]
    # each: 2 reviews, up to 3 fixups and 2 rebases
    [[ "$output" == *"at most 14 billed"* ]]
    [ -z "$(ran)" ]
    run bash "$SCRIPT" --prs --yes --max 1
    [ "$(ran)" = "all 7 --yes --merge --model sonnet" ]
}

@test "--prs with a task, a task run given a PR, or a bad PR: usage, exit 2" {
    for args in "--prs docs:T6" "31" "--prs x" "--prs 31/x"; do
        # shellcheck disable=SC2086 # split on purpose: each word one arg
        run bash "$SCRIPT" $args --yes
        [ "$status" -eq 2 ] || {
            echo "not usage: $args"
            return 1
        }
    done
    [ -z "$(ran)" ]
}

@test "--prs: a pull request given twice is a usage error, before anything runs" {
    for args in "--prs 31 31" "--prs 31 https://github.com/o/p/pull/31"; do
        # shellcheck disable=SC2086 # split on purpose: each word one arg
        run bash "$SCRIPT" $args --yes
        [ "$status" -eq 2 ] || {
            echo "not usage: $args"
            return 1
        }
    done
    [ -z "$(ran)" ]
    [ ! -f "$STATE/gh.log" ]
}

@test "--prs: as many open pull requests as the list limit: exit 1, no session, never a partial drain" {
    open_prs 7:claude/a 31:claude/b
    CLOUD_DRAIN_PR_LIMIT=2 run bash "$SCRIPT" --prs --yes --max 9
    [ "$status" -eq 1 ]
    [[ "$output" == *"2 or more"* ]]
    grep -q -- '--limit 2' "$STATE/gh.log"
    [ -z "$(ran)" ]
}

@test "--prs and a task drain run under macOS's Bash 3.2 too: no unbound empty array" {
    if ! { [ -x /bin/bash ] && /bin/bash --version | grep -q 'version 3\.'; }; then
        skip "no Bash 3.2 at /bin/bash"
    fi
    open_prs 7:claude/a
    run /bin/bash "$SCRIPT" --prs --dry-run --max 9
    [ "$status" -eq 0 ]
    [[ "$output" == *"#7"* ]]
    run /bin/bash "$SCRIPT" --dry-run --max 9
    [ "$status" -eq 0 ]
    [[ "$output" == *"root:T1"* ]]
}

@test "--prs: a number is read in base 10, so 031 is 31: given twice it is a usage error" {
    run bash "$SCRIPT" --prs 31 031 --yes
    [ "$status" -eq 2 ]
    [ -z "$(ran)" ]
    run bash "$SCRIPT" --prs 031 --yes
    [ "$status" -eq 0 ]
    [ "$(ran)" = "all 31 --yes --merge --model sonnet" ]
}

@test "--prs: a URL of another repo is a usage error, since drain drains this repo only" {
    run bash "$SCRIPT" --prs https://github.com/x/y/pull/31 --yes
    [ "$status" -eq 2 ]
    [[ "$output" == *"this repo"* ]]
    [ -z "$(ran)" ]
    STUB_ORIGIN=git@github.com:O/P.git run bash "$SCRIPT" --prs https://github.com/o/p/pull/7 --yes
    [ "$status" -eq 0 ]
    [ "$(ran)" = "all https://github.com/o/p/pull/7 --yes --merge --model sonnet" ]
}

@test "--prs: a number is read as text: zeros only, or more than 9 digits, is a usage error, never another PR" {
    for args in "18446744073709551617" "1234567890" "0" "000"; do
        run bash "$SCRIPT" --prs "$args" --yes
        [ "$status" -eq 2 ] || {
            echo "not usage: $args"
            return 1
        }
    done
    [ -z "$(ran)" ]
    run bash "$SCRIPT" --prs 000000031 --yes
    [ "$status" -eq 0 ]
    [ "$(ran)" = "all 31 --yes --merge --model sonnet" ]
}

@test "--prs is bound to origin's repo: gh and every child get it, whatever GH_REPO was" {
    open_prs 7:claude/a
    GH_REPO=other/repo run bash "$SCRIPT" --prs --yes --max 9
    [ "$status" -eq 0 ]
    grep -q -- 'pr list --state open .*--repo o/p' "$STATE/gh.log"
    [ "$(cat "$STATE/all.gh_repo")" = o/p ]
    run bash "$SCRIPT" --prs --yes
    grep -q -- 'pr list --state merged .*--repo o/p' "$STATE/gh.log"
}

@test "--prs needs a github.com origin, https or ssh; any other host is an error, no session" {
    STUB_ORIGIN=git@gitlab.com:o/p.git run bash "$SCRIPT" --prs 31 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"github.com"* ]]
    [ -z "$(ran)" ]
    STUB_ORIGIN=https://gitlab.com/o/p.git run bash "$SCRIPT" --prs 31 --yes
    [ "$status" -eq 1 ]
    [ -z "$(ran)" ]
    for origin in https://github.com/o/p ssh://git@github.com/o/p.git git@github.com:o/p.git; do
        : >"$STATE/all.log"
        STUB_ORIGIN="$origin" run bash "$SCRIPT" --prs https://github.com/o/p/pull/7 --yes
        [ "$status" -eq 0 ] || {
            echo "refused: $origin"
            return 1
        }
    done
}

@test "--prs never prints origin's URL, which may hold a token" {
    # A fake token, put together so no scanner takes it for a real one.
    local user=user token=ghp_SECRET
    STUB_ORIGIN="https://$user:$token@gitlab.com/o/p" run bash "$SCRIPT" --prs 31 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"not a github.com remote"* ]]
    [[ "$output" != *"$token"* ]]
    [[ "$output" != *"$user:"* ]]
    [ -z "$(ran)" ]
}

@test "--prs takes origin's GitHub forms with a port 22, a trailing / or no .git" {
    for origin in ssh://git@github.com:22/o/p ssh://git@github.com:22/o/p.git/ https://github.com/o/p/ \
        https://github.com/o/p.git/ git@github.com:o/p/ git@github.com:o/p.git; do
        STUB_ORIGIN="$origin" run bash "$SCRIPT" --prs https://github.com/o/p/pull/7 --yes
        [ "$status" -eq 0 ] || {
            echo "refused: $origin"
            return 1
        }
    done
    [ "$(sort -u "$STATE/all.gh_repo")" = o/p ]
    STUB_ORIGIN=ssh://git@gitlab.com:22/o/p run bash "$SCRIPT" --prs 31 --yes
    [ "$status" -eq 1 ]
}

@test "--prs matches origin's github.com host in any case, and keeps the owner/repo as written" {
    for origin in https://GitHub.com/o/p.git git@GITHUB.COM:o/p; do
        : >"$STATE/all.gh_repo"
        STUB_ORIGIN="$origin" run bash "$SCRIPT" --prs 31 --yes
        [ "$status" -eq 0 ] || {
            echo "refused: $origin"
            return 1
        }
        [ "$(cat "$STATE/all.gh_repo")" = o/p ]
    done
    STUB_ORIGIN=https://github.com/O/P run bash "$SCRIPT" --prs 31 --yes
    [ "$status" -eq 0 ]
    [ "$(tail -n 1 "$STATE/all.gh_repo")" = O/P ]
}

@test "--prs reads a PR URL's github.com host in any case, then still checks its repo" {
    STUB_ORIGIN=git@GITHUB.COM:o/p run bash "$SCRIPT" --prs https://GITHUB.COM/o/p/pull/31 --yes
    [ "$status" -eq 0 ]
    [ "$(ran)" = "all https://github.com/o/p/pull/31 --yes --merge --model sonnet" ]
    : >"$STATE/all.log"
    run bash "$SCRIPT" --prs https://GitHub.com/x/y/pull/31 --yes
    [ "$status" -eq 2 ]
    [[ "$output" == *"this repo"* ]]
    [ -z "$(ran)" ]
}
