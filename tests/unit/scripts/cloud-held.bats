#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/cloud-held.sh (SPEC cloud:T166, cloud:V52,
# cloud:V40, cloud:V41, cloud:I.cmd). cloud-all.sh and gh are stubs: no
# session starts and nothing reaches GitHub.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../scripts/cloud-held.sh"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    export STATE="$BATS_TEST_TMPDIR/state"
    export CLAUDINIX_SCRIPTS="$BATS_TEST_TMPDIR/lib"
    export CLAUDINIX_PROJECTS="$BATS_TEST_TMPDIR/projects"
    unset GH_FAIL
    mkdir -p "$STUBS" "$STATE" "$CLAUDINIX_SCRIPTS/review"
    : >"$CLAUDINIX_SCRIPTS/review/alpha.md"
    : >"$CLAUDINIX_SCRIPTS/review/beta.md"
    printf '%s\n' '#!/usr/bin/env bash' 'echo sonnet' >"$CLAUDINIX_SCRIPTS/config.sh"

    # cloud-all.sh: records its directory and args; exits the number in
    # $STATE/rc.<PR number>.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$(basename "$PWD") all $*" >>"$STATE/all.log"' \
        'rc_file="$STATE/rc.${1##*/}"' \
        'if [ -f "$rc_file" ]; then exit "$(cat "$rc_file")"; fi' >"$CLAUDINIX_SCRIPTS/cloud-all.sh"
    chmod +x "$CLAUDINIX_SCRIPTS"/*.sh

    # gh: `api user` answers the owner, `search prs` answers
    # $STATE/prs.json, `pr view URL` says whether $STATE/fork.<PR number>
    # exists, or any fails with $GH_FAIL.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$STATE/gh.log"' \
        '[ -z "${GH_FAIL:-}" ] || { echo "HTTP 502: bad gateway" >&2; exit 1; }' \
        'case "$*" in' \
        'api\ user*) echo owner ;;' \
        'search\ prs*) repos="$(grep -o -- "--repo [^ ]*" <<<"$*" | cut -d/ -f2)"' \
        '  jq -c --arg only "$repos" "map(select(\$only == \"\" or (.repository.name | IN(\$only | split(\"\\n\")[]))))" "$STATE/prs.json" ;;' \
        'pr\ view*) [ -f "$STATE/fork.${3##*/}" ] && echo true || echo false ;;' \
        '*) exit 9 ;;' \
        'esac' >"$STUBS/gh"
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"

    checkout alpha
    checkout beta
    prs "$(pr alpha 7 2026-10-02)" "$(pr beta 3 2026-10-01)"
}

# checkout REPO [ENV]: a checkout of REPO pinned to a cloud environment.
checkout() {
    mkdir -p "$CLAUDINIX_PROJECTS/$1/.claude"
    jq -n --arg id "${2-env_1}" '{remote: {defaultEnvironmentId: $id}}' >"$CLAUDINIX_PROJECTS/$1/.claude/settings.local.json"
}

# pr REPO N CREATED [AUTHOR]: one `gh search prs` row.
pr() {
    jq -n --arg r "$1" --argjson n "$2" --arg c "$3" --arg a "${4-owner}" \
        '{number: $n, createdAt: $c, url: "https://github.com/owner/\($r)/pull/\($n)", repository: {name: $r, nameWithOwner: "owner/\($r)"}, author: {login: $a}}'
}

# prs ROW...: the PRs the search finds.
prs() {
    jq -s . <<<"$*" >"$STATE/prs.json"
}

ran() {
    cat "$STATE/all.log" 2>/dev/null
}

# --- which PRs ---

@test "labelled PRs run oldest first, each through cloud-all.sh from its checkout" {
    run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    [ "$(ran)" = "beta all https://github.com/owner/beta/pull/3 --yes --model sonnet
alpha all https://github.com/owner/alpha/pull/7 --yes --model sonnet" ]
    [[ "$output" == *"held: done, 2 of 2"* ]]
}

@test "the label defaults to h10n-human, --label changes it; the search is the owner's and open" {
    run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    grep -qF -- '--label h10n-human' "$STATE/gh.log"
    grep -qF -- '--owner owner' "$STATE/gh.log"
    grep -qF -- '--state open' "$STATE/gh.log"
    run bash "$SCRIPT" --yes --label parked
    grep -qF -- '--label parked' "$STATE/gh.log"
}

@test "--repo keeps only the named repos" {
    run bash "$SCRIPT" --yes --repo alpha
    [ "$status" -eq 0 ]
    [ "$(ran)" = "alpha all https://github.com/owner/alpha/pull/7 --yes --model sonnet" ]
}

@test "--repo goes to the search as OWNER/REPO, so a match past the first page is found (cloud:B88)" {
    run bash "$SCRIPT" --yes --repo alpha --repo beta
    grep -qF -- '--repo owner/alpha' "$STATE/gh.log"
    grep -qF -- '--repo owner/beta' "$STATE/gh.log"
}

@test "a full page of 100 labelled PRs is said aloud, not dropped silently (cloud:B88)" {
    jq -n '[range(100) | {number: ., createdAt: "2026-10-01", url: "https://github.com/owner/alpha/pull/\(.)", repository: {name: "alpha", nameWithOwner: "owner/alpha"}, author: {login: "owner"}}]' >"$STATE/prs.json"
    run bash "$SCRIPT" --dry-run
    [[ "$output" == *"only the first 100"* ]]
}

@test "--max caps how many PRs run" {
    run bash "$SCRIPT" --yes --max 1
    [ "$status" -eq 0 ]
    [ "$(ran)" = "beta all https://github.com/owner/beta/pull/3 --yes --model sonnet" ]
}

@test "--model goes to every PR" {
    run bash "$SCRIPT" --yes --model opus
    [[ "$(ran)" == *"--model opus"* ]]
    [[ "$(ran)" != *"--model sonnet"* ]]
}

@test "no labelled PR: nothing to do, exit 0, no session" {
    prs
    run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing to do"* ]]
    [ -z "$(ran)" ]
}

# --- skips ---

@test "a repo without a checkout is skipped naming it; the rest run" {
    rm -r "${CLAUDINIX_PROJECTS:?}/beta"
    run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"skip owner/beta#3"*"checkout"* ]]
    [ "$(ran)" = "alpha all https://github.com/owner/alpha/pull/7 --yes --model sonnet" ]
}

@test "a checkout without a claude.ai environment in settings.local.json is skipped naming it" {
    checkout beta ""
    run bash "$SCRIPT" --yes
    [[ "$output" == *"skip owner/beta#3"*"environment"* ]]
    rm "$CLAUDINIX_PROJECTS/beta/.claude/settings.local.json"
    run bash "$SCRIPT" --yes
    [[ "$output" == *"skip owner/beta#3"*"environment"* ]]
    [ -z "$(ran)" ] || [[ "$(ran)" != *beta* ]]
}

@test "a PR by someone else than the owner is skipped naming it (cloud:V52)" {
    prs "$(pr beta 3 2026-10-01 stranger)" "$(pr alpha 7 2026-10-02)"
    run bash "$SCRIPT" --yes
    [[ "$output" == *"skip owner/beta#3"*"stranger"* ]]
    [ "$(ran)" = "alpha all https://github.com/owner/alpha/pull/7 --yes --model sonnet" ]
}

@test "a fork PR is skipped naming it and spends no --max slot (cloud:B86)" {
    touch "$STATE/fork.3"
    run bash "$SCRIPT" --yes --max 1
    [ "$status" -eq 0 ]
    [[ "$output" == *"skip owner/beta#3"*"fork"* ]]
    [ "$(ran)" = "alpha all https://github.com/owner/alpha/pull/7 --yes --model sonnet" ]
}

@test "a checkout path with a space still runs each PR from its checkout (cloud:B87)" {
    mv "$CLAUDINIX_PROJECTS" "$BATS_TEST_TMPDIR/my projects"
    run env CLAUDINIX_PROJECTS="$BATS_TEST_TMPDIR/my projects" bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    [ "$(ran)" = "beta all https://github.com/owner/beta/pull/3 --yes --model sonnet
alpha all https://github.com/owner/alpha/pull/7 --yes --model sonnet" ]
}

@test "--max with no PR that can run: nothing to do, exit 0 (the empty slice needs a bash 3.2 guard)" {
    rm -r "${CLAUDINIX_PROJECTS:?}/alpha" "${CLAUDINIX_PROJECTS:?}/beta"
    run bash "$SCRIPT" --yes --max 1
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing to do"* ]]
}

@test "CLAUDINIX_PROJECTS unset: exit 1 saying to set it, no session" {
    unset CLAUDINIX_PROJECTS
    run bash "$SCRIPT" --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"CLAUDINIX_PROJECTS"* ]]
    [ -z "$(ran)" ]
}

# --- the plan ---

@test "--dry-run prints the PRs and the billed sessions, starts nothing" {
    run bash "$SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"owner/beta#3"* ]]
    [[ "$output" == *"owner/alpha#7"* ]]
    [[ "$output" == *"6 billed"* ]]
    [[ "$output" == *"sonnet"* ]]
    [ -z "$(ran)" ]
}

@test "without --yes the answer decides: n starts nothing, y runs" {
    run bash "$SCRIPT" <<<"n"
    [ "$status" -eq 1 ]
    [[ "$output" == *"owner/alpha#7"* ]]
    [[ "$output" == *"not started"* ]]
    [ -z "$(ran)" ]
    run bash "$SCRIPT" <<<"y"
    [ "$status" -eq 0 ]
    [ "$(ran | wc -l | tr -d ' ')" -eq 2 ]
}

# --- stops ---

@test "a PR that fails is named and the next one still runs; exit 1 at the end" {
    echo 1 >"$STATE/rc.3"
    run bash "$SCRIPT" --yes
    [ "$status" -eq 1 ]
    [ "$(ran | wc -l | tr -d ' ')" -eq 2 ]
    [[ "$output" == *"owner/beta#3"*"failed"* ]]
    [[ "$output" == *"1 of 2"* ]]
}

@test "gh cannot search: exit 1 with gh's stderr only, no session (cloud:V41)" {
    export GH_FAIL=1
    run bash "$SCRIPT" --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"HTTP 502"* ]]
    [[ "$output" != *"nothing to do"* ]]
    [ -z "$(ran)" ]
}

@test "the hold is the owner's: no merge, label edit or close (cloud:V52)" {
    run bash "$SCRIPT" --yes
    run ! grep -E 'merge|edit|close' "$STATE/gh.log"
    [[ "$(ran)" != *"--merge"* ]]
}

@test "no review roles: refused before any session" {
    rm "$CLAUDINIX_SCRIPTS"/review/*.md
    run bash "$SCRIPT" --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"review"* ]]
    [ -z "$(ran)" ]
}

@test "unknown option or a bad --max: usage, exit 2" {
    run bash "$SCRIPT" --bogus
    [ "$status" -eq 2 ]
    run bash "$SCRIPT" --max 0
    [ "$status" -eq 2 ]
}
