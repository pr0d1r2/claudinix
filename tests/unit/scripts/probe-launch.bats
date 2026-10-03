#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/probe-launch.sh (SPEC scripts:T28, I.cmd
# `probe`, .:T3, C8). claude, script and git are stubs: no session is
# started and nothing reaches a remote.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../scripts/probe-launch.sh"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    export STATE="$BATS_TEST_TMPDIR/state"
    export PROBE_POLL_SECONDS=0 PROBE_POLL_TRIES=3
    export TOPLEVEL="$BATS_TEST_TMPDIR/project"
    unset CLAUDINIX_CONFIG CLAUDINIX_CONFIG_JSON
    mkdir -p "$STUBS" "$STATE" "$TOPLEVEL"
    : >"$STATE/branches"
    printf '%s\n' 'facts: ok' 'nix-dev: tier 2' >"$STATE/report"

    # claude: records its args; the "session" pushes a probe branch.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'printf "%s\n" "$1" >"$STATE/claude.1"' \
        'printf "%s" "$2" >"$STATE/claude.task"' \
        'shift 2; echo "$*" >"$STATE/claude.rest"' \
        '[ -n "${NO_PUSH:-}" ] || echo "${PUSH_BRANCH:-claude/nix-probe-x7k2q9}" >>"$STATE/branches"' >"$STUBS/claude"
    # script: util-linux form when STUB_LINUX is set, else BSD form.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$STATE/script.log"' \
        'if [ "$1" = --version ]; then [ -n "${STUB_LINUX:-}" ] && exit 0; exit 1; fi' \
        'if [ -n "${STUB_LINUX:-}" ]; then' \
        '  while [ "$1" != -c ]; do shift; done; exec sh -c "$2"' \
        'fi' \
        'while [ "$1" != /dev/null ]; do shift; done; shift; exec "$@"' >"$STUBS/script"
    # git: a work tree on branch main, pushed to origin/main, whose remote
    # holds the branches in $STATE/branches. NO_REMOTE, DETACHED,
    # NO_UPSTREAM and BEHIND each break one of those. Its top level is
    # $TOPLEVEL, where a test may put a .claudinix.toml (scripts:T91).
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$STATE/git.log"' \
        'case "$*" in' \
        'remote\ get-url\ *) [ -z "${NO_REMOTE:-}" ] || { echo "error: No such remote" >&2; exit 2; }; echo https://github.com/o/p ; exit 0 ;;' \
        'symbolic-ref*) [ -z "${DETACHED:-}" ] || exit 1; echo main; exit 0 ;;' \
        'rev-parse\ --show-toplevel) [ -z "${NOT_A_REPO:-}" ] || exit 128; echo "$TOPLEVEL"; exit 0 ;;' \
        '*--symbolic-full-name*) [ -z "${NO_UPSTREAM:-}" ] || exit 128; echo origin/main; exit 0 ;;' \
        'rev-parse\ HEAD) echo aaaa; exit 0 ;;' \
        'rev-parse\ @{u}) if [ -n "${BEHIND:-}" ]; then echo bbbb; else echo aaaa; fi; exit 0 ;;' \
        'esac' \
        'case "$1" in' \
        'rev-parse) [ -z "${NOT_A_REPO:-}" ] || exit 128; echo true ;;' \
        'ls-remote) while read -r b; do printf "0000\trefs/heads/%s\n" "$b"; done <"$STATE/branches" ;;' \
        'fetch) ;;' \
        'show) [ -z "${NO_REPORT:-}" ] || exit 128; cat "$STATE/report" ;;' \
        'push) ;;' \
        '*) exit 9 ;;' \
        'esac' >"$STUBS/git"
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"
}

@test "launch: claude --cloud TASK --model sonnet, in that order, under script" {
    run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE/claude.1")" = "--cloud" ]
    [ "$(cat "$STATE/claude.rest")" = "--model sonnet" ]
    grep -q '/dev/null claude --cloud' "$STATE/script.log"
}

@test "the task carries probe.sh, the report file and the branch prefix (.:T3)" {
    run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    grep -qF 'report nix-version' "$STATE/claude.task"
    grep -qF 'nix-probe-report.txt' "$STATE/claude.task"
    grep -qF 'claude/nix-probe' "$STATE/claude.task"
}

@test "--model picks the model" {
    run bash "$SCRIPT" --yes --model opus
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE/claude.rest")" = "--model opus" ]
}

@test "finds the new probe branch by prefix and prints its report" {
    echo claude/nix-probe-old111 >"$STATE/branches"
    run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"claude/nix-probe-x7k2q9"* ]]
    [[ "$output" == *"nix-dev: tier 2"* ]]
    grep -q '^fetch -q origin refs/heads/claude/nix-probe-x7k2q9' "$STATE/git.log"
    grep -q '^show FETCH_HEAD:nix-probe-report.txt' "$STATE/git.log"
}

@test "no new branch within the tries: exit 1, says where to look" {
    NO_PUSH=1 run bash "$SCRIPT" --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"no new claude/nix-probe"* ]]
    [ "$(grep -c '^ls-remote' "$STATE/git.log")" -eq 4 ]
}

@test "a branch without the report fails" {
    NO_REPORT=1 run bash "$SCRIPT" --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"nix-probe-report.txt"* ]]
}

@test "util-linux script: the same claude args through script -c" {
    STUB_LINUX=1 run bash "$SCRIPT" --model opus --yes
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE/claude.1")" = "--cloud" ]
    [ "$(cat "$STATE/claude.rest")" = "--model opus" ]
    grep -qF 'nix-probe-report.txt' "$STATE/claude.task"
}

@test "--cleanup deletes every probe branch and starts no session" {
    printf '%s\n' claude/nix-probe-a claude/nix-probe-b >"$STATE/branches"
    run bash "$SCRIPT" --cleanup
    [ "$status" -eq 0 ]
    grep -qx 'push origin --delete claude/nix-probe-a claude/nix-probe-b' "$STATE/git.log"
    [ ! -e "$STATE/claude.1" ]
}

@test "--cleanup with no probe branch says so and passes" {
    run bash "$SCRIPT" --cleanup
    [ "$status" -eq 0 ]
    [[ "$output" == *"no claude/nix-probe"* ]]
    run ! grep -q '^push' "$STATE/git.log"
}

@test "outside a git repository: fails before starting a session" {
    NOT_A_REPO=1 run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [ ! -e "$STATE/claude.1" ]
}

# scripts:T81 (review R3-15,16): check before a billed session starts.

@test "no remote origin: says to push to GitHub first, starts no session" {
    NO_REMOTE=1 run bash "$SCRIPT" --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"probe: no remote origin -- push the project to GitHub first"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "no remote named by PROBE_REMOTE: names that remote" {
    NO_REMOTE=1 PROBE_REMOTE=upstream run bash "$SCRIPT" --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"probe: no remote upstream -- push the project to GitHub first"* ]]
}

@test "--cleanup with no remote origin: same message, nothing pushed" {
    NO_REMOTE=1 run bash "$SCRIPT" --cleanup
    [ "$status" -eq 1 ]
    [[ "$output" == *"no remote origin"* ]]
    run ! grep -q '^push' "$STATE/git.log"
}

@test "a branch with no upstream: says to push it, starts no session" {
    NO_UPSTREAM=1 run bash "$SCRIPT" --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"main"*"not pushed"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "a branch that differs from its upstream: says so, starts no session" {
    BEHIND=1 run bash "$SCRIPT" --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"main"*"origin/main"* ]]
    [[ "$output" == *"not up to date"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "a detached HEAD: says to check out a branch, starts no session" {
    DETACHED=1 run bash "$SCRIPT" --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"detached"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "without --yes: asks y/N about a billed session; y starts it" {
    run bash "$SCRIPT" <<<y
    [ "$status" -eq 0 ]
    [[ "$output" == *"billed"* ]]
    [[ "$output" == *"[y/N]"* ]]
    [ "$(cat "$STATE/claude.1")" = "--cloud" ]
}

@test "without --yes: Enter, n or no input starts nothing" {
    run bash "$SCRIPT" <<<''
    [ "$status" -eq 1 ]
    [[ "$output" == *"not started"* ]]
    [ ! -e "$STATE/claude.1" ]
    run bash "$SCRIPT" <<<n
    [ "$status" -eq 1 ]
    run bash "$SCRIPT" </dev/null
    [ "$status" -eq 1 ]
    [ ! -e "$STATE/claude.1" ]
}

@test "unknown flag or --model without a value is a usage error" {
    run bash "$SCRIPT" --nope
    [ "$status" -eq 2 ]
    run bash "$SCRIPT" --model
    [ "$status" -eq 2 ]
}

# .claudinix.toml (scripts:T91, scripts:V34): flag > file > default.

# config LINE...: the project's .claudinix.toml.
config() {
    printf '%s\n' 'version = 1' "$@" >"$TOPLEVEL/.claudinix.toml"
}

@test "session.model picks the model; --model still wins" {
    config '[session]' 'model = "opus"'
    run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE/claude.rest")" = "--model opus" ]
    run bash "$SCRIPT" --yes --model sonnet
    [ "$(cat "$STATE/claude.rest")" = "--model sonnet" ]
}

# shellcheck disable=SC2016 # literal Markdown backticks, not a command
@test "probe.branch_prefix: the task names it and the new branch is found by it" {
    config '[probe]' 'branch_prefix = "claude/probe-me"'
    echo claude/nix-probe-other >"$STATE/branches"
    PUSH_BRANCH=claude/probe-me-abc123 run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    grep -qF 'Create a branch named `claude/probe-me`' "$STATE/claude.task"
    run ! grep -qF 'claude/nix-probe' "$STATE/claude.task"
    grep -q '^ls-remote --heads origin refs/heads/claude/probe-me\*' "$STATE/git.log"
    grep -q '^fetch -q origin refs/heads/claude/probe-me-abc123' "$STATE/git.log"
}

@test "probe.branch_prefix: --cleanup looks only for its branches" {
    config '[probe]' 'branch_prefix = "claude/probe-me"'
    run bash "$SCRIPT" --cleanup
    [ "$status" -eq 0 ]
    [[ "$output" == *"no claude/probe-me*"* ]]
    grep -q '^ls-remote --heads origin refs/heads/claude/probe-me\*' "$STATE/git.log"
}

@test "devshell.installable: the task runs that dev shell" {
    config '[devshell]' 'installable = ".#ci"'
    run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    grep -qF 'time nix-dev .#ci --command true' "$STATE/claude.task"
    grep -qF 'time nix develop .#ci --command true' "$STATE/claude.task"
}

# shellcheck disable=SC2016 # literal $ in the values, not expanded
@test "devshell.installable and probe.branch_prefix are shell-quoted in the task (scripts:T95)" {
    config '[devshell]' 'installable = "./a;b$c|d"' '[probe]' 'branch_prefix = "claude/p$x"'
    PUSH_BRANCH='claude/p$x-1' run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    grep -qF 'time nix-dev ./a\;b\$c\|d --command true' "$STATE/claude.task"
    grep -qF 'time nix develop ./a\;b\$c\|d --command true' "$STATE/claude.task"
    grep -qF 'Create a branch named `claude/p\$x`' "$STATE/claude.task"
}

@test "an installable with a space is refused, no session (scripts:T95)" {
    config '[devshell]' 'installable = "path:./a b"'
    run bash "$SCRIPT" --yes
    [ "$status" -eq 2 ]
    [[ "$output" == *'"path:./a b"'* ]]
    [ ! -e "$STATE/claude.1" ]
}

# shellcheck disable=SC2016 # literal Markdown backticks, not a command
@test "without a file the task is the prompt as written" {
    run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    grep -qF 'time nix-dev --command true' "$STATE/claude.task"
    grep -qF 'Create a branch named `claude/nix-probe`' "$STATE/claude.task"
    run ! grep -qF '@NIX_' "$STATE/claude.task"
}

@test "a bad .claudinix.toml: exit 2 naming the file and key, no session" {
    config '[probe]' 'branch_prefix = 1'
    run bash "$SCRIPT" --yes
    [ "$status" -eq 2 ]
    [[ "$output" == *"$TOPLEVEL/.claudinix.toml"* ]]
    [[ "$output" == *"probe.branch_prefix"* ]]
    [ ! -e "$STATE/claude.1" ]
}
