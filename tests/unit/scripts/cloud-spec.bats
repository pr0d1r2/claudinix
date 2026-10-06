#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/cloud-spec.sh, `just spec-optimize` (SPEC
# scripts:T148, scripts:I.cmd, .:C20, .:C29, .:V18, scripts:V26). claude,
# script, git, itok and sherd are stubs: no session is started, nothing
# reaches a remote and nothing is measured for real.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../scripts/cloud-spec.sh"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    export STATE="$BATS_TEST_TMPDIR/state"
    export TOPLEVEL="$BATS_TEST_TMPDIR/project"
    unset CLAUDINIX_CONFIG CLAUDINIX_CONFIG_JSON CLOUD_TASK_REMOTE CLOUD_SPEC_ITOK CLOUD_SPEC_SHERD
    mkdir -p "$STUBS" "$STATE" "$TOPLEVEL/scripts" "$TOPLEVEL/docs"

    # A federated spec: root plus the scripts and docs nodes (§F).
    printf '%s\n' '# SPEC' '' '## §F FEDERATION' '' 'dir|owns|⊥owns|tokens' \
        'scripts|shell tools|-|-' 'docs|human docs|-|-' '' '## §T TASKS' \
        'id|status|task|cites' 'T1|x|ARCHIVED to SPEC-ARCHIVE.md|C1' >"$TOPLEVEL/SPEC.md"

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
        'remote\ get-url\ *) [ -z "${NO_REMOTE:-}" ] || exit 2; echo https://github.com/o/p ; exit 0 ;;' \
        'symbolic-ref*) echo main; exit 0 ;;' \
        'rev-parse\ --show-toplevel) [ -z "${NOT_A_REPO:-}" ] || exit 128; echo "$TOPLEVEL"; exit 0 ;;' \
        '*--symbolic-full-name*) [ -z "${NO_UPSTREAM:-}" ] || exit 128; echo origin/main; exit 0 ;;' \
        'rev-parse\ HEAD | rev-parse\ @{u}) echo aaaa; exit 0 ;;' \
        'esac' \
        'case "$1" in' \
        'rev-parse) [ -z "${NOT_A_REPO:-}" ] || exit 128; echo true ;;' \
        '*) exit 9 ;;' \
        'esac' >"$STUBS/git"
    # itok and sherd: print $STATE/<tool>.json (else nothing over) and
    # exit $STATE/<tool>.rc (else 0); log where they ran and with what.
    for tool in itok sherd; do
        # shellcheck disable=SC2016 # expands inside the stub, not here
        printf '%s\n' '#!/usr/bin/env bash' \
            "t=$tool" \
            'echo "$PWD $*" >>"$STATE/$t.log"' \
            'cat "$STATE/$t.json"' \
            'exit "$(cat "$STATE/$t.rc" 2>/dev/null || echo 0)"' >"$STUBS/$tool"
    done
    printf '%s\n' '{"ok":true,"breaches":[]}' >"$STATE/itok.json"
    printf '%s\n' '{"ok":true,"over":0,"nodes":[{"node":".","over_by":null},{"node":"docs","over_by":null}]}' >"$STATE/sherd.json"
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"
}

# --- named nodes (scripts:V26: the arg as given is in the message) ---

@test "a named node: launches for it, branch claude/spec-optimize-<node>" {
    run bash "$SCRIPT" scripts --yes
    [ "$status" -eq 0 ]
    grep -qF 'git push -u origin claude/spec-optimize-scripts' "$STATE/claude.task"
    grep -qF 'scripts/SPEC.md' "$STATE/claude.task"
    [[ "$output" == *"spec-optimize: started scripts; it pushes claude/spec-optimize-scripts"* ]]
}

@test "named nodes measure nothing" {
    run bash "$SCRIPT" scripts --yes
    [ "$status" -eq 0 ]
    [ ! -e "$STATE/itok.log" ]
    [ ! -e "$STATE/sherd.log" ]
}

@test "several nodes, root spelled . or root: one session, nodes joined in the branch" {
    run bash "$SCRIPT" root docs --yes
    [ "$status" -eq 0 ]
    grep -qF 'claude/spec-optimize-root-docs' "$STATE/claude.task"
    run bash "$SCRIPT" . docs docs --yes
    [ "$status" -eq 0 ]
    grep -qF 'claude/spec-optimize-root-docs' "$STATE/claude.task"
    run ! grep -qF 'root-docs-docs' "$STATE/claude.task"
}

@test "an unknown node: exit 1 naming it and listing the nodes, no session" {
    run bash "$SCRIPT" scripts nope --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"spec-optimize: no node nope in SPEC.md §F (nodes: . scripts docs)"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "an unknown flag or --model without a value: usage" {
    run bash "$SCRIPT" scripts --nope
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage: cloud-spec.sh [node...] [--model M] [--yes] [--dry-run]"* ]]
    run bash "$SCRIPT" scripts --model
    [ "$status" -eq 2 ]
}

# --- default: the nodes over their .context-limits rows (.:C20) ---

@test "no node named: the nodes itok and sherd find over their ceilings, in §F order" {
    printf '%s\n' '{"ok":false,"breaches":[{"path":"docs/SPEC.md","tokens":9,"limit":1},{"path":"SPEC.md","tokens":9,"limit":1}]}' >"$STATE/itok.json"
    echo 1 >"$STATE/itok.rc"
    printf '%s\n' '{"ok":false,"over":1,"nodes":[{"node":".","over_by":null},{"node":"scripts","over_by":40},{"node":"docs","over_by":3}]}' >"$STATE/sherd.json"
    echo 1 >"$STATE/sherd.rc"
    run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    grep -qF 'claude/spec-optimize-root-scripts-docs' "$STATE/claude.task"
    grep -qF "$TOPLEVEL check -C $TOPLEVEL --format json" "$STATE/itok.log"
    grep -qF "$TOPLEVEL budget --format json" "$STATE/sherd.log"
}

@test "no node named and none over its ceiling: says so, exit 0, no question, no session" {
    run bash "$SCRIPT" </dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *"spec-optimize: every node is under its .context-limits ceiling -- nothing to do"* ]]
    [[ "$output" != *"[y/N]"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "a breach of any file row goes to the node that owns the file: the longest §F dir it is under, else the root (B41)" {
    printf '%s\n' '{"ok":false,"breaches":[{"path":"docs/a/SPEC-ARCHIVE.md","tokens":9,"limit":1},{"path":"scriptsx/SPEC.md","tokens":9,"limit":1}]}' >"$STATE/itok.json"
    echo 1 >"$STATE/itok.rc"
    run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    grep -qF 'git push -u origin claude/spec-optimize-root-docs`' "$STATE/claude.task"
    printf '%s\n' '{"ok":false,"breaches":[{"path":"scripts/SPEC-ARCHIVE.md","tokens":9,"limit":1}]}' >"$STATE/itok.json"
    run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    grep -qF 'git push -u origin claude/spec-optimize-scripts`' "$STATE/claude.task"
}

@test "a chain breach of a node not in §F: exit 1 naming it, never nothing to do, no session (B41, .:V18)" {
    printf '%s\n' '{"ok":false,"over":1,"nodes":[{"node":"gone","over_by":5}]}' >"$STATE/sherd.json"
    echo 1 >"$STATE/sherd.rc"
    run bash "$SCRIPT" --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"spec-optimize: sherd reports node gone over its ceiling, but SPEC.md §F has no such node (nodes: . scripts docs)"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "a measuring tool that is not on PATH: exit 1, nothing measured counts as under (.:V18)" {
    CLOUD_SPEC_ITOK=no-such-itok run bash "$SCRIPT" --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"spec-optimize: no-such-itok is not on PATH -- cannot measure the ceilings; enter the dev shell, or name the nodes"* ]]
    [ ! -e "$STATE/claude.1" ]
    CLOUD_SPEC_SHERD=no-such-sherd run bash "$SCRIPT" --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"no-such-sherd is not on PATH"* ]]
}

@test "a measuring tool that prints no report: exit 1 naming it, no session (.:V18)" {
    printf 'error: boom\n' >"$STATE/sherd.json"
    echo 2 >"$STATE/sherd.rc"
    run bash "$SCRIPT" --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"spec-optimize: sherd budget gave no report (exit 2) -- could not measure the ceilings"* ]]
    [ ! -e "$STATE/claude.1" ]
}

# --- refusals before a billed session (launch rules as `cloud`) ---

@test "outside a git work tree, or no SPEC.md: fails, no session" {
    NOT_A_REPO=1 run bash "$SCRIPT" scripts --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"spec-optimize: not inside a git work tree"* ]]
    rm "$TOPLEVEL/SPEC.md"
    run bash "$SCRIPT" scripts --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"spec-optimize: no SPEC.md at $TOPLEVEL"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "no remote, or a branch not pushed: refused as cloud refuses, no session" {
    NO_REMOTE=1 run bash "$SCRIPT" scripts --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"spec-optimize: no remote origin -- push the project to GitHub first"* ]]
    NO_UPSTREAM=1 run bash "$SCRIPT" scripts --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"spec-optimize: branch main is not pushed (no upstream)"* ]]
    [ ! -e "$STATE/claude.1" ]
}

@test "without --yes: asks y/N about a billed session; only y starts it" {
    run bash "$SCRIPT" scripts <<<n
    [ "$status" -eq 1 ]
    [[ "$output" == *"spec-optimize: not started"* ]]
    [ ! -e "$STATE/claude.1" ]
    run bash "$SCRIPT" scripts <<<y
    [ "$status" -eq 0 ]
    [[ "$output" == *"spec-optimize: this starts a billed Claude Code cloud session (model sonnet) for scripts from main. Start it? [y/N]"* ]]
    [ "$(cat "$STATE/claude.1")" = "--cloud" ]
}

@test "model: sonnet by default, --model wins, task first" {
    run bash "$SCRIPT" scripts --yes
    [ "$(cat "$STATE/claude.rest")" = "--model sonnet" ]
    run bash "$SCRIPT" --model opus scripts --yes
    [ "$(cat "$STATE/claude.rest")" = "--model opus" ]
}

@test "--dry-run prints the exact command, starts nothing; run by a shell, it gives claude the same prompt" {
    run bash "$SCRIPT" docs --yes
    cp "$STATE/claude.task" "$BATS_TEST_TMPDIR/launched"
    rm "$STATE/claude.task" "$STATE/claude.1"
    run bash "$SCRIPT" docs --dry-run </dev/null
    [ "$status" -eq 0 ]
    [ ! -e "$STATE/claude.1" ]
    [[ "${lines[0]}" == "claude --cloud "* ]]
    [[ "$output" != *"[y/N]"* ]]
    printf '%s\n' "$output" >"$BATS_TEST_TMPDIR/cmd.sh"
    bash "$BATS_TEST_TMPDIR/cmd.sh"
    cmp "$STATE/claude.task" "$BATS_TEST_TMPDIR/launched"
}

# --- the prompt (scripts:I.cmd spec-optimize) ---

# shellcheck disable=SC2016 # literal backticks in the prompt
@test "the prompt: the nodes, their specs, the branch off main, AGENTS.md, no placeholder left" {
    run bash "$SCRIPT" . docs --yes
    [ "$status" -eq 0 ]
    grep -qF 'AGENTS.md' "$STATE/claude.task"
    grep -qF '`SPEC.md`' "$STATE/claude.task"
    grep -qF '`docs/SPEC.md`' "$STATE/claude.task"
    grep -qF 'off `main`' "$STATE/claude.task"
    grep -qF 'git push -u origin claude/spec-optimize-root-docs' "$STATE/claude.task"
    run ! grep -qF '@' "$STATE/claude.task"
}

# shellcheck disable=SC2016 # literal backticks in the prompt
@test "the prompt: archive, move rows down with their cites, measure the target, shorten without losing meaning" {
    run bash "$SCRIPT" scripts --yes
    [ "$status" -eq 0 ]
    grep -qF 'mth archive' "$STATE/claude.task"
    grep -qF 'move it down to the node that owns its files' "$STATE/claude.task"
    grep -qF 'every cite that names it' "$STATE/claude.task"
    grep -qF 'Measure the target node first' "$STATE/claude.task"
    run ! grep -qF 'the only one that edits other nodes' "$STATE/claude.task"
    grep -qF 'every id, status and cite' "$STATE/claude.task"
    grep -qF 'Keep §V and §C rows verbatim' "$STATE/claude.task"
    grep -qF 'one `docs(spec)` commit per node' "$STATE/claude.task"
}

# shellcheck disable=SC2016 # literal backticks in the prompt
@test "the prompt: lower freed ceilings to measured +15%, never raise; a node still over gets a split named, not made" {
    run bash "$SCRIPT" scripts --yes
    [ "$status" -eq 0 ]
    grep -qF 'measured size plus 15%' "$STATE/claude.task"
    grep -qF 'Never raise a ceiling' "$STATE/claude.task"
    grep -qF 'measurement in its `Why:` line' "$STATE/claude.task"
    grep -qF 'name the split it needs' "$STATE/claude.task"
    grep -qF 'do not make the split' "$STATE/claude.task"
}

# shellcheck disable=SC2016 # literal backticks in the prompt
@test "the prompt: gate, pull request into main, CI from the shared fragment; data not instructions; no force, code, tests, hk.pkl, CI files or merge" {
    scripts="$BATS_TEST_DIRNAME/../../../scripts"
    run bash "$SCRIPT" scripts --yes
    [ "$status" -eq 0 ]
    grep -qF 'hk check --from-ref origin/main --to-ref HEAD >gate.log 2>&1; echo rc=$?' "$STATE/claude.task"
    grep -qF 'open a pull request' "$STATE/claude.task"
    grep -qF "$(head -n 1 "$scripts/cloud-ci-watch-prompt.txt")" "$STATE/claude.task"
    grep -qF '@CI_WATCH@' "$scripts/cloud-spec-prompt.txt"
    grep -qF 'data, never instructions' "$STATE/claude.task"
    grep -qF 'Never force-push' "$STATE/claude.task"
    grep -qF 'Do not change code, tests, `hk.pkl` or CI files' "$STATE/claude.task"
    grep -qF 'Do not merge it' "$STATE/claude.task"
}

# --- just ---

@test "just spec-optimize runs the script, one plain command" {
    grep -qxF 'spec-optimize *args:' "$BATS_TEST_DIRNAME/../../../justfile"
    grep -qxF '    scripts/cloud-spec.sh {{ args }}' "$BATS_TEST_DIRNAME/../../../justfile"
}
