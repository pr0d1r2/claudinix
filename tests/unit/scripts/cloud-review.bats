#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/cloud-review.sh and its roles in scripts/review/
# (SPEC scripts:T129, .:C29, scripts:V34, scripts:B19). claude, script,
# git and gh are stubs: no session is started and nothing reaches GitHub.

setup() {
    REPO="$BATS_TEST_DIRNAME/../../.."
    SCRIPT="$REPO/scripts/cloud-review.sh"
    ROLES="$REPO/scripts/review"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    export STATE="$BATS_TEST_TMPDIR/state"
    export TOPLEVEL="$BATS_TEST_TMPDIR/project"
    unset CLAUDINIX_CONFIG CLAUDINIX_CONFIG_JSON CLAUDINIX_SCRIPTS CLOUD_TASK_REMOTE
    unset STUB_PR GH_FAIL GH_READS_STDIN NO_UPSTREAM
    mkdir -p "$STUBS" "$STATE" "$TOPLEVEL"

    # claude: records its args, one file each.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'printf "%s\n" "$1" >"$STATE/claude.1"' \
        'printf "%s" "$2" >"$STATE/claude.task"' \
        'shift 2; echo "$*" >"$STATE/claude.rest"' >"$STUBS/claude"
    # script: BSD form, as on macOS.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        '[ "$1" != --version ] || exit 1' \
        'while [ "$1" != /dev/null ]; do shift; done; shift; exec "$@"' >"$STUBS/script"
    # git: a work tree at $TOPLEVEL on branch main, pushed to origin/main.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'case "$*" in' \
        'remote\ get-url\ *) echo https://github.com/o/p ; exit 0 ;;' \
        'symbolic-ref*) echo main; exit 0 ;;' \
        'rev-parse\ --show-toplevel) echo "$TOPLEVEL"; exit 0 ;;' \
        '*--symbolic-full-name*) [ -z "${NO_UPSTREAM:-}" ] || exit 128; echo origin/main; exit 0 ;;' \
        'rev-parse\ HEAD | rev-parse\ @{u}) echo aaaa; exit 0 ;;' \
        'esac' \
        '[ "$1" = rev-parse ] && { echo true; exit 0; }' \
        'exit 9' >"$STUBS/git"
    # gh: `pr view` answers number, state, head, base and URL as TSV.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$STATE/gh.log"' \
        '[ -z "${GH_READS_STDIN:-}" ] || cat >/dev/null' \
        '[ -z "${GH_FAIL:-}" ] || { echo "GraphQL: Could not resolve to a PullRequest" >&2; exit 1; }' \
        'printf "%b\n" "${STUB_PR:-12\tOPEN\tfeature/x\tmain\thttps://github.com/o/p/pull/12}"' >"$STUBS/gh"
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"
}

# --- the roles ---

@test "the owner's six roles each have a file" {
    for role in correctness maintainability extensibility performance security architecture; do
        [ -s "$ROLES/$role.md" ] || {
            echo "missing role: $role"
            return 1
        }
    done
}

@test "every role file has a '# ' title and no @, so the prompt fill cannot misfire" {
    local f n=0
    for f in "$ROLES"/*.md; do
        n=$((n + 1))
        head -n 1 "$f" | grep -q '^# ' || {
            echo "no title: $f"
            return 1
        }
        run ! grep -qF '@' "$f"
    done
    [ "$n" -ge 6 ]
}

@test "every role in the directory launches, its text in the prompt" {
    local f role
    for f in "$ROLES"/*.md; do
        role="$(basename "$f" .md)"
        rm -f "$STATE/claude.task"
        run bash "$SCRIPT" "$role" 12 --yes
        [ "$status" -eq 0 ]
        grep -qF "$(sed -n 2p "$f")" "$STATE/claude.task"
        grep -qF "Review: $role" "$STATE/claude.task"
    done
}

@test "a new role is a new file: no code change needed" {
    local lib="$BATS_TEST_TMPDIR/lib"
    mkdir -p "$lib/review"
    cp "$REPO/scripts/cloud-review-prompt.txt" "$REPO/scripts/config.sh" "$REPO/scripts/config.jq" "$lib/"
    printf '%s\n' '# Usability' 'Look only at how a person uses this.' >"$lib/review/usability.md"
    CLAUDINIX_SCRIPTS="$lib" run bash "$SCRIPT" usability 12 --yes
    [ "$status" -eq 0 ]
    grep -qF 'Look only at how a person uses this.' "$STATE/claude.task"
}

@test "an unknown role: exit 2 listing the roles, no session" {
    run bash "$SCRIPT" vibes 12 --yes
    [ "$status" -eq 2 ]
    [[ "$output" == *"no role vibes"* ]]
    [[ "$output" == *"correctness"* ]]
    [[ "$output" == *"security"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "a role name with a path in it is refused" {
    run bash "$SCRIPT" ../review/security 12 --yes
    [ "$status" -eq 2 ]
    [ ! -e "$STATE/claude.1" ]
}

# --- the pull request ---

@test "a PR number or URL: gh is asked about that number; any head branch" {
    run bash "$SCRIPT" security 12 --yes
    [ "$status" -eq 0 ]
    run bash "$SCRIPT" security https://github.com/o/p/pull/12 --yes
    [ "$status" -eq 0 ]
    [ "$(grep -c '^pr view 12 ' "$STATE/gh.log")" -eq 2 ]
    grep -qF 'feature/x' "$STATE/claude.task"
    grep -qF 'https://github.com/o/p/pull/12' "$STATE/claude.task"
    [[ "$output" == *"cloud: started the security review of #12"* ]]
}

@test "usage: missing role or PR, a bad PR, extra args, unknown flag" {
    for args in "" "security" "security abc" "security 12 13" "security 12 --bogus" "security 12 --model"; do
        # shellcheck disable=SC2086 # split on purpose: each word one arg
        run bash "$SCRIPT" $args
        [ "$status" -eq 2 ]
        [[ "$output" == *"usage: cloud-review.sh"* ]]
    done
    [ ! -e "$STATE/claude.1" ]
}

@test "gh cannot answer, or the PR is not open: exit 1, no session" {
    GH_FAIL=1 run bash "$SCRIPT" security 12 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"#12"* ]]
    STUB_PR='12\tMERGED\tfeature/x\tmain\thttps://github.com/o/p/pull/12' run bash "$SCRIPT" security 12 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"MERGED"* ]]
    [ ! -e "$STATE/claude.1" ]
}

# --- launch rules shared with cloud-task.sh and cloud-rebase.sh ---

@test "a branch with no upstream: says to push it, no session" {
    NO_UPSTREAM=1 run bash "$SCRIPT" security 12 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"git push -u origin main"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "without --yes: Enter starts nothing, y starts it, gh never takes the y (B19)" {
    run bash "$SCRIPT" security 12 <<<""
    [ "$status" -eq 1 ]
    [[ "$output" == *"[y/N]"* ]]
    [ ! -e "$STATE/claude.1" ]
    GH_READS_STDIN=1 run bash "$SCRIPT" security 12 <<<"y"
    [ "$status" -eq 0 ]
    [ -e "$STATE/claude.1" ]
}

@test "model: sonnet by default, session.model from the config, --model wins" {
    run bash "$SCRIPT" security 12 --yes
    [ "$(cat "$STATE/claude.rest")" = "--model sonnet" ]
    printf '%s\n' 'version = 1' '[session]' 'model = "opus"' >"$TOPLEVEL/.claudinix.toml"
    cd "$TOPLEVEL"
    run bash "$SCRIPT" security 12 --yes
    [ "$(cat "$STATE/claude.rest")" = "--model opus" ]
    run bash "$SCRIPT" security 12 --model sonnet --yes
    [ "$(cat "$STATE/claude.rest")" = "--model sonnet" ]
}

@test "--dry-run prints the command, starts nothing, and gives the same prompt" {
    run bash "$SCRIPT" security 12 --yes
    cp "$STATE/claude.task" "$BATS_TEST_TMPDIR/launched"
    rm -f "$STATE/claude.task" "$STATE/claude.1"
    run bash "$SCRIPT" security 12 --dry-run </dev/null
    [ "$status" -eq 0 ]
    [ ! -e "$STATE/claude.1" ]
    [[ "${lines[0]}" == "claude --cloud "* ]]
    printf '%s\n' "$output" >"$BATS_TEST_TMPDIR/cmd.sh"
    bash "$BATS_TEST_TMPDIR/cmd.sh"
    cmp "$STATE/claude.task" "$BATS_TEST_TMPDIR/launched"
}

# --- the prompt ---

@test "the prompt: read the spec and diff, one role, one comment, read-only, report" {
    run bash "$SCRIPT" correctness 12 --yes
    [ "$status" -eq 0 ]
    local p="$STATE/claude.task"
    grep -qF 'AGENTS.md' "$p"
    grep -qF 'git diff origin/main...origin/feature/x' "$p"
    grep -qF 'one comment on the pull request' "$p"
    grep -qF 'Review: correctness' "$p"
    grep -qF 'do not commit, do not push' "$p"
    grep -qF 'merge' "$p"
    grep -qiF 'report' "$p"
    run ! grep -qF '@' "$p"
}

# --- just ---

@test "just review runs the script, one plain command" {
    grep -qxF 'review *args:' "$REPO/justfile"
    grep -qxF '    scripts/cloud-review.sh {{ args }}' "$REPO/justfile"
}
