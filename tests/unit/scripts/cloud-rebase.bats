#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/cloud-rebase.sh (SPEC scripts:T126, .:C29,
# scripts:V34). claude, script, git and gh are stubs: no session is
# started and nothing reaches GitHub.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../scripts/cloud-rebase.sh"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    export STATE="$BATS_TEST_TMPDIR/state"
    export TOPLEVEL="$BATS_TEST_TMPDIR/project"
    unset CLAUDINIX_CONFIG CLAUDINIX_CONFIG_JSON CLOUD_TASK_REMOTE STUB_PR GH_FAIL GH_READS_STDIN
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
        'echo "$*" >>"$STATE/script.log"' \
        '[ "$1" != --version ] || exit 1' \
        'while [ "$1" != /dev/null ]; do shift; done; shift; exec "$@"' >"$STUBS/script"
    # git: a work tree at $TOPLEVEL on branch main, pushed to origin/main.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$STATE/git.log"' \
        'case "$*" in' \
        'remote\ get-url\ *) [ -z "${NO_REMOTE:-}" ] || exit 2; echo https://github.com/o/p ; exit 0 ;;' \
        'symbolic-ref*) echo main; exit 0 ;;' \
        'rev-parse\ --show-toplevel) echo "$TOPLEVEL"; exit 0 ;;' \
        '*--symbolic-full-name*) [ -z "${NO_UPSTREAM:-}" ] || exit 128; echo origin/main; exit 0 ;;' \
        'rev-parse\ HEAD) echo aaaa; exit 0 ;;' \
        'rev-parse\ @{u}) echo aaaa; exit 0 ;;' \
        'esac' \
        'case "$1" in' \
        'rev-parse) echo true ;;' \
        '*) exit 9 ;;' \
        'esac' >"$STUBS/git"
    # gh: `pr view` answers number, state, head, base and URL as TSV.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$STATE/gh.log"' \
        '[ -z "${GH_READS_STDIN:-}" ] || cat >/dev/null' \
        '[ -z "${GH_FAIL:-}" ] || { echo "GraphQL: Could not resolve to a PullRequest" >&2; exit 1; }' \
        'printf "%b\n" "${STUB_PR:-8\tOPEN\tclaude/dev-t123-dk9i03\tmain\thttps://github.com/o/p/pull/8\tfalse}"' >"$STUBS/gh"
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"
}

# --- the pull request ---

@test "a PR number: launches a session for that PR's branch" {
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 0 ]
    grep -q '^pr view 8 ' "$STATE/gh.log"
    [ "$(cat "$STATE/claude.1")" = "--cloud" ]
    grep -qF 'claude/dev-t123-dk9i03' "$STATE/claude.task"
    grep -qF 'https://github.com/o/p/pull/8' "$STATE/claude.task"
    [[ "$output" == *"cloud: started the rebase of #8 (claude/dev-t123-dk9i03) onto main"* ]]
}

@test "a PR URL: asks gh about its number" {
    run bash "$SCRIPT" https://github.com/o/p/pull/8 --yes
    [ "$status" -eq 0 ]
    grep -q '^pr view 8 ' "$STATE/gh.log"
}

@test "no PR, two PRs, a bad PR or an unknown flag: usage, no session" {
    for args in "" "8 9" "abc" "https://github.com/o/p/issues/8" "8 --bogus" "8 --model"; do
        # shellcheck disable=SC2086 # split on purpose: each word one arg
        run bash "$SCRIPT" $args
        [ "$status" -eq 2 ]
        [[ "$output" == *"usage: cloud-rebase.sh"* ]]
    done
    [ ! -e "$STATE/claude.1" ]
}

@test "gh cannot answer: exit 1 naming the PR, no session" {
    GH_FAIL=1 run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"#8"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "a merged or closed PR is refused, naming its state" {
    STUB_PR='8\tMERGED\tclaude/x\tmain\thttps://github.com/o/p/pull/8' run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"MERGED"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "any branch of origin but main is rebased; a fork, main or a non-plain ref is refused (scripts:T145)" {
    STUB_PR='8\tOPEN\tfeature/x\tmain\thttps://github.com/o/p/pull/8\tfalse' run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 0 ]
    grep -qF 'git push --force-with-lease origin HEAD:feature/x' "$STATE/claude.task"
    rm -f "$STATE/claude.1"
    # shellcheck disable=SC2016 # $(id) is the literal branch name under test
    for head in 'feature/x\ttrue' 'main\tfalse' 'x$(id)\tfalse'; do
        STUB_PR="8\tOPEN\t${head%%\\t*}\tmain\thttps://github.com/o/p/pull/8\t${head#*\\t}" run bash "$SCRIPT" 8 --yes
        [ "$status" -eq 1 ]
        [[ "$output" == *"#8"* ]]
    done
    [ ! -e "$STATE/claude.1" ]
}

@test "a branch starting with - is refused: git would read it as an option (scripts:V43)" {
    STUB_PR='8\tOPEN\t-x\tmain\thttps://github.com/o/p/pull/8\tfalse' run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"not a plain branch name"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "a URL of another repository is refused; owner and repo compare with the case folded (scripts:T145)" {
    run bash "$SCRIPT" https://github.com/other/repo/pull/8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"other/repo"* ]]
    [ ! -e "$STATE/claude.1" ]
    run bash "$SCRIPT" https://github.com/O/P/pull/8 --yes
    [ "$status" -eq 0 ]
}

@test "a base other than main is refused" {
    STUB_PR='8\tOPEN\tclaude/x\tdevelop\thttps://github.com/o/p/pull/8' run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"develop"* ]]
    [ ! -e "$STATE/claude.1" ]
}

# --- launch rules shared with cloud-task.sh ---

@test "a branch with no upstream: says to push it, no session" {
    NO_UPSTREAM=1 run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"git push -u origin main"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "without --yes: Enter starts nothing, y starts it" {
    run bash "$SCRIPT" 8 <<<""
    [ "$status" -eq 1 ]
    [[ "$output" == *"[y/N]"* ]]
    [ ! -e "$STATE/claude.1" ]
    run bash "$SCRIPT" 8 <<<"y"
    [ "$status" -eq 0 ]
    [ -e "$STATE/claude.1" ]
}

@test "model: sonnet by default, session.model from the config, --model wins" {
    run bash "$SCRIPT" 8 --yes
    [ "$(cat "$STATE/claude.rest")" = "--model sonnet" ]
    printf '%s\n' 'version = 1' '[session]' 'model = "opus"' >"$TOPLEVEL/.claudinix.toml"
    cd "$TOPLEVEL"
    run bash "$SCRIPT" 8 --yes
    [ "$(cat "$STATE/claude.rest")" = "--model opus" ]
    run bash "$SCRIPT" 8 --model sonnet --yes
    [ "$(cat "$STATE/claude.rest")" = "--model sonnet" ]
}

@test "--dry-run prints the command, starts nothing, and gives the same prompt" {
    run bash "$SCRIPT" 8 --yes
    cp "$STATE/claude.task" "$BATS_TEST_TMPDIR/launched"
    rm -f "$STATE/claude.task" "$STATE/claude.1"
    run bash "$SCRIPT" 8 --dry-run </dev/null
    [ "$status" -eq 0 ]
    [ ! -e "$STATE/claude.1" ]
    [[ "${lines[0]}" == "claude --cloud "* ]]
    printf '%s\n' "$output" >"$BATS_TEST_TMPDIR/cmd.sh"
    bash "$BATS_TEST_TMPDIR/cmd.sh"
    cmp "$STATE/claude.task" "$BATS_TEST_TMPDIR/launched"
}

@test "gh never reads the y/N answer: it gets no stdin (B19)" {
    GH_READS_STDIN=1 run bash "$SCRIPT" 8 <<<"y"
    [ "$status" -eq 0 ]
    [ -e "$STATE/claude.1" ]
}

# --- the prompt ---

# shellcheck disable=SC2016 # literal backticks and $ in the prompt
@test "the prompt: rebase onto main, re-write generated files, gate, lease push, report" {
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 0 ]
    local p="$STATE/claude.task"
    grep -qF 'AGENTS.md' "$p"
    grep -qF 'git rebase origin/main' "$p"
    grep -qF 'claudinix-dev badges --write' "$p"
    grep -qF 'claudinix-dev steps --write' "$p"
    grep -qF 'git rebase --abort' "$p"
    grep -qF 'hk check --from-ref origin/main --to-ref HEAD >gate.log 2>&1; echo rc=$?' "$p"
    grep -qF 'git push --force-with-lease origin HEAD:claude/dev-t123-dk9i03' "$p"
    grep -qF 'Do not merge' "$p"
    grep -qF 'open no new pull request' "$p"
    grep -qiF 'report' "$p"
    run ! grep -qF '@' "$p"
}

# --- just ---

@test "just rebase runs the script, one plain command" {
    grep -qxF 'rebase *args:' "$BATS_TEST_DIRNAME/../../../justfile"
    grep -qxF '    scripts/cloud-rebase.sh {{ args }}' "$BATS_TEST_DIRNAME/../../../justfile"
}

@test "the prompt: mechanical conflicts are resolved, a shared spec id renumbered, then CI watched (scripts:T145)" {
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 0 ]
    local p="$STATE/claude.task"
    grep -qF 'keep both' "$p"
    grep -qF 'next free id' "$p"
    grep -qF 'every citation of it' "$p"
    grep -qF 'opposite things' "$p"
    grep -qF 'Watch CI on the pull request' "$p"
    grep -qF 'at most 3 red rounds' "$p"
}
