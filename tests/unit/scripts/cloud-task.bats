#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/cloud-task.sh (SPEC .:T100, .:C29,
# scripts:V34, scripts:V26, .:V24). claude, script and git are stubs: no
# session is started and nothing reaches a remote.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../scripts/cloud-task.sh"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    export STATE="$BATS_TEST_TMPDIR/state"
    export TOPLEVEL="$BATS_TEST_TMPDIR/project"
    unset CLAUDINIX_CONFIG CLAUDINIX_CONFIG_JSON CLOUD_TASK_REMOTE
    mkdir -p "$STUBS" "$STATE" "$TOPLEVEL/scripts" "$TOPLEVEL/docs"

    # A federated spec: root plus the scripts and docs nodes (§F).
    printf '%s\n' '# SPEC' '' '## §F FEDERATION' '' 'dir|owns|⊥owns|tokens' \
        'scripts|shell tools|-|-' 'docs|human docs|-|-' '' '## §T TASKS' \
        'id|status|task|cites' \
        'T1|x|ARCHIVED to SPEC-ARCHIVE.md|C1' \
        'T10|.|root task ten|C29' \
        'T11|~|root task in progress|C29' >"$TOPLEVEL/SPEC.md"
    # shellcheck disable=SC2016 # literal Markdown backticks, not a command
    printf '%s\n' '# SPEC' '' '## §T TASKS' 'id|status|task|cites' \
        'T20|.|write `a.sh` \& test it|V26,`.:C29`' \
        'T21|.|shared id, scripts side|V26' >"$TOPLEVEL/scripts/SPEC.md"
    printf '%s\n' '# SPEC' '' '## §T TASKS' 'id|status|task|cites' \
        'T21|.|shared id, docs side|V1' \
        'T30|x|done docs task|V1' >"$TOPLEVEL/docs/SPEC.md"

    # claude: records its args, one file each.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'printf "%s\n" "$1" >"$STATE/claude.1"' \
        'printf "%s" "$2" >"$STATE/claude.task"' \
        'shift 2; echo "$*" >"$STATE/claude.rest"' >"$STUBS/claude"
    # script: util-linux form when STUB_LINUX is set, else BSD form.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$STATE/script.log"' \
        'if [ "$1" = --version ]; then [ -n "${STUB_LINUX:-}" ] && exit 0; exit 1; fi' \
        'if [ -n "${STUB_LINUX:-}" ]; then' \
        '  while [ "$1" != -c ]; do shift; done; exec sh -c "$2"' \
        'fi' \
        'while [ "$1" != /dev/null ]; do shift; done; shift; exec "$@"' >"$STUBS/script"
    # git: a work tree at $TOPLEVEL on branch main, pushed to origin/main.
    # NO_REMOTE, DETACHED, NO_UPSTREAM, BEHIND and NOT_A_REPO each break
    # one of those.
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
        '*) exit 9 ;;' \
        'esac' >"$STUBS/git"
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"
}

# config LINE...: the project's .claudinix.toml.
config() {
    printf '%s\n' 'version = 1' "$@" >"$TOPLEVEL/.claudinix.toml"
}

# --- task resolution (scripts:V26: the arg as given is in the message) ---

@test "a bare Tn found in one node: launches with that node and task" {
    run bash "$SCRIPT" T20 --yes
    [ "$status" -eq 0 ]
    grep -qF 'scripts:T20' "$STATE/claude.task"
    grep -qF 'claude/scripts-T20' "$STATE/claude.task"
}

@test "a root task: node . and branch claude/root-Tn" {
    run bash "$SCRIPT" T10 --yes
    [ "$status" -eq 0 ]
    grep -qF '.:T10' "$STATE/claude.task"
    grep -qF 'claude/root-T10' "$STATE/claude.task"
    grep -qF 'root task ten' "$STATE/claude.task"
}

@test "node:Tn picks the node even when the id is in two" {
    run bash "$SCRIPT" docs:T21 --yes
    [ "$status" -eq 0 ]
    grep -qF 'shared id, docs side' "$STATE/claude.task"
    run ! grep -qF 'scripts side' "$STATE/claude.task"
}

@test "root:T10 and .:T10 name the root node" {
    run bash "$SCRIPT" root:T10 --yes
    [ "$status" -eq 0 ]
    grep -qF 'root task ten' "$STATE/claude.task"
    run bash "$SCRIPT" .:T10 --yes
    [ "$status" -eq 0 ]
}

@test "a missing task: exit 1 naming it, no session" {
    run bash "$SCRIPT" T999 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud: no task T999 in any node's SPEC.md"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "a task missing from the named node: names the arg and the file" {
    run bash "$SCRIPT" docs:T20 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud: no task docs:T20 in docs/SPEC.md"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "a done task is refused" {
    run bash "$SCRIPT" docs:T30 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud: docs:T30 is done (x) in docs/SPEC.md -- nothing to build"* ]]
    [ ! -e "$STATE/claude.1" ]
    run bash "$SCRIPT" T1 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud: T1 is done (x) in SPEC.md"* ]]
}

@test "a task in progress is refused" {
    run bash "$SCRIPT" T11 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud: T11 is in progress (~) in SPEC.md -- finish or reset it first"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "an id in two nodes is ambiguous: names both, asks for node:Tn" {
    run bash "$SCRIPT" T21 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud: T21 is in more than one node (scripts docs) -- name one, e.g. scripts:T21"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "an unknown node: exit 1 naming it and listing the nodes" {
    run bash "$SCRIPT" nope:T10 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud: no node nope in SPEC.md §F (nodes: . scripts docs)"* ]]
}

@test "a malformed task: usage error naming it" {
    run bash "$SCRIPT" 'T1x' --yes
    [ "$status" -eq 2 ]
    [[ "$output" == *"cloud: bad task T1x -- want Tn or node:Tn"* ]]
    run bash "$SCRIPT" 'a b:T1' --yes
    [ "$status" -eq 2 ]
    [[ "$output" == *"a b:T1"* ]]
}

@test "no task, two tasks, unknown flag or --model without a value: usage" {
    run bash "$SCRIPT" --yes
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage: cloud-task.sh <node:Tn | Tn>"* ]]
    run bash "$SCRIPT" T10 T20
    [ "$status" -eq 2 ]
    run bash "$SCRIPT" T10 --nope
    [ "$status" -eq 2 ]
    run bash "$SCRIPT" T10 --model
    [ "$status" -eq 2 ]
}

# --- refusals before a billed session (as probe-launch, scripts:T81) ---

@test "outside a git repository: fails, no session" {
    NOT_A_REPO=1 run bash "$SCRIPT" T10 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud: not inside a git work tree"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "no remote origin: says to push to GitHub first, no session" {
    NO_REMOTE=1 run bash "$SCRIPT" T10 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud: no remote origin -- push the project to GitHub first"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "CLOUD_TASK_REMOTE names the remote checked" {
    NO_REMOTE=1 CLOUD_TASK_REMOTE=upstream run bash "$SCRIPT" T10 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud: no remote upstream"* ]]
}

@test "a branch with no upstream: says to push it, no session" {
    NO_UPSTREAM=1 run bash "$SCRIPT" T10 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud: branch main is not pushed (no upstream) -- push it first: git push -u origin main"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "a branch that differs from its upstream: says so, no session" {
    BEHIND=1 run bash "$SCRIPT" T10 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud: branch main is not up to date with origin/main -- push (or pull) first"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "a detached HEAD: says to check out a branch, no session" {
    DETACHED=1 run bash "$SCRIPT" T10 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"detached"* ]]
    [ ! -e "$STATE/claude.1" ]
}

# --- confirmation ---

@test "without --yes: asks y/N about a billed session; y starts it" {
    run bash "$SCRIPT" T10 <<<y
    [ "$status" -eq 0 ]
    [[ "$output" == *"cloud: this starts a billed Claude Code cloud session (model sonnet) for .:T10 from main. Start it? [y/N]"* ]]
    [ "$(cat "$STATE/claude.1")" = "--cloud" ]
}

@test "without --yes: Enter, n or no input starts nothing" {
    run bash "$SCRIPT" T10 <<<''
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud: not started"* ]]
    [ ! -e "$STATE/claude.1" ]
    run bash "$SCRIPT" T10 <<<n
    [ "$status" -eq 1 ]
    run bash "$SCRIPT" T10 </dev/null
    [ "$status" -eq 1 ]
    [ ! -e "$STATE/claude.1" ]
}

# --- launch: task first, --model after (.:C29, probe 7) ---

@test "launch: claude --cloud TASK --model sonnet, in that order, under script" {
    run bash "$SCRIPT" T10 --yes
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE/claude.1")" = "--cloud" ]
    [ "$(cat "$STATE/claude.rest")" = "--model sonnet" ]
    grep -q '/dev/null claude --cloud' "$STATE/script.log"
    [[ "$output" == *"cloud: started .:T10; it pushes claude/root-T10"* ]]
}

@test "util-linux script: the same claude args through script -c" {
    STUB_LINUX=1 run bash "$SCRIPT" T10 --model opus --yes
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE/claude.1")" = "--cloud" ]
    [ "$(cat "$STATE/claude.rest")" = "--model opus" ]
    grep -qF 'root task ten' "$STATE/claude.task"
}

# --- model precedence (scripts:V34): flag > file > sonnet ---

@test "model: sonnet without a file, --model wins" {
    run bash "$SCRIPT" T10 --yes
    [ "$(cat "$STATE/claude.rest")" = "--model sonnet" ]
    run bash "$SCRIPT" --model opus T10 --yes
    [ "$(cat "$STATE/claude.rest")" = "--model opus" ]
}

@test "model: session.model from .claudinix.toml; --model still wins" {
    config '[session]' 'model = "opus"'
    run bash "$SCRIPT" T10 --yes
    [ "$status" -eq 0 ]
    [ "$(cat "$STATE/claude.rest")" = "--model opus" ]
    run bash "$SCRIPT" T10 --yes --model sonnet
    [ "$(cat "$STATE/claude.rest")" = "--model sonnet" ]
}

@test "a bad .claudinix.toml: exit 2 naming the file and key, no session" {
    config '[session]' 'model = 1'
    run bash "$SCRIPT" T10 --yes
    [ "$status" -eq 2 ]
    [[ "$output" == *"$TOPLEVEL/.claudinix.toml"* ]]
    [[ "$output" == *"session.model"* ]]
    [ ! -e "$STATE/claude.1" ]
}

# --- the prompt ---

@test "the prompt: AGENTS.md, /build, RED GREEN flip, gate, branch, report" {
    run bash "$SCRIPT" T20 --yes
    [ "$status" -eq 0 ]
    grep -qF 'AGENTS.md' "$STATE/claude.task"
    grep -qF '/build scripts:T20' "$STATE/claude.task"
    grep -qF 'docs(spec): mark T20 done' "$STATE/claude.task"
    grep -qF 'hk check --from-ref origin/main --to-ref HEAD >gate.log 2>&1; echo rc=$?' "$STATE/claude.task"
    run ! grep -qF 'hk check --all' "$STATE/claude.task"
    grep -qF 'git push -u origin claude/scripts-T20' "$STATE/claude.task"
    grep -qF 'scripts/SPEC.md' "$STATE/claude.task"
    grep -qiF 'report' "$STATE/claude.task"
    run ! grep -qF '@' "$STATE/claude.task"
}

# shellcheck disable=SC2016 # literal backticks, not expanded
@test "the prompt: open a pull request to main after the push, never merge it (scripts:T124)" {
    run bash "$SCRIPT" T20 --yes
    [ "$status" -eq 0 ]
    grep -qF 'open a pull request' "$STATE/claude.task"
    grep -qF 'into `main`' "$STATE/claude.task"
    grep -qF 'Do not merge it' "$STATE/claude.task"
    grep -qF 'the pull request URL' "$STATE/claude.task"
    run ! grep -qF 'open no pull request' "$STATE/claude.task"
}

# shellcheck disable=SC2016 # literal $ and backticks in the row, not expanded
@test "the task row goes in as written: & \\& backticks and \$() stay literal" {
    printf '%s\n' 'T40|.|a & b \& c `d` $(rm -rf x) @TASK@ ~/y|V1' >>"$TOPLEVEL/scripts/SPEC.md"
    run bash "$SCRIPT" T40 --yes
    [ "$status" -eq 0 ]
    grep -qF 'T40|.|a & b \& c `d` $(rm -rf x) @TASK@ ~/y|V1' "$STATE/claude.task"
}

@test "the prompt: watch CI after the push; red is fixed and pushed again, at most 3 rounds; a cancelled run is reported (scripts:T140)" {
    run bash "$SCRIPT" T20 --yes
    [ "$status" -eq 0 ]
    grep -qF 'Watch CI on the pull request' "$STATE/claude.task"
    grep -qF 'at most 3 red rounds' "$STATE/claude.task"
    grep -qF 'cancelled before any step ran' "$STATE/claude.task"
    grep -qF 'never weaken a check' "$STATE/claude.task"
}

# --- dry run ---

@test "--dry-run prints the exact command, starts nothing, needs no answer" {
    run bash "$SCRIPT" T20 --dry-run </dev/null
    [ "$status" -eq 0 ]
    [ ! -e "$STATE/claude.1" ]
    [ ! -e "$STATE/script.log" ]
    [[ "${lines[0]}" == "claude --cloud "* ]]
    [[ "$output" == *" --model sonnet" ]]
    [[ "$output" != *"[y/N]"* ]]
}

@test "--dry-run output, run by a shell, gives claude the same prompt" {
    run bash "$SCRIPT" T20 --yes
    cp "$STATE/claude.task" "$BATS_TEST_TMPDIR/launched"
    run bash "$SCRIPT" T20 --dry-run --model opus
    [ "$status" -eq 0 ]
    printf '%s\n' "$output" >"$BATS_TEST_TMPDIR/cmd.sh"
    rm -f "$STATE/claude.task"
    bash "$BATS_TEST_TMPDIR/cmd.sh"
    cmp "$STATE/claude.task" "$BATS_TEST_TMPDIR/launched"
    [ "$(cat "$STATE/claude.rest")" = "--model opus" ]
}

@test "--dry-run still refuses what a launch would" {
    NO_UPSTREAM=1 run bash "$SCRIPT" T20 --dry-run
    [ "$status" -eq 1 ]
    run bash "$SCRIPT" T30 --dry-run
    [ "$status" -eq 1 ]
}

# --- just ---

@test "just cloud runs the script, one plain command" {
    grep -qxF 'cloud *args:' "$BATS_TEST_DIRNAME/../../../justfile"
    grep -qxF '    scripts/cloud-task.sh {{ args }}' "$BATS_TEST_DIRNAME/../../../justfile"
}
