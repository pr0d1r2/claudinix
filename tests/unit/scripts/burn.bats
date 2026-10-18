#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/burn.sh (SPEC scripts:T176, I.cmd `burn`, V61,
# V26). Transcripts are fixtures; gh is a stub: no network, no writes.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../scripts/burn.sh"
    FIXTURES="$BATS_TEST_DIRNAME/../../fixtures/burn"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    export HOME="$BATS_TEST_TMPDIR/home"
    export GH_LOG="$BATS_TEST_TMPDIR/gh.log"
    export GH_COMMENTS="$FIXTURES/pr-comments.json"
    SESSIONS="$HOME/.claude/projects/-p"
    mkdir -p "$STUBS" "$SESSIONS"
    unset CLAUDINIX_SCRIPTS CLAUDE_CONFIG_DIR
    # gh: `pr view N --json comments` prints the fixture; `pr comment`
    # logs its body (stdin).
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$GH_LOG"' \
        'case "$1 $2" in' \
        '"pr view") cat "$GH_COMMENTS" ;;' \
        '"pr comment") cat >>"$GH_LOG" ;;' \
        '*) exit 9 ;;' \
        'esac' >"$STUBS/gh"
    chmod +x "$STUBS/gh"
    export PATH="$STUBS:$PATH"
}

@test "a transcript FILE prints 1 row per model and a total, last duplicate id wins" {
    run --separate-stderr "$SCRIPT" "$FIXTURES/two-models.jsonl"
    [ "$status" -eq 0 ]
    [ "${lines[2]}" = "| claude-opus-5-5 | 1000000 | 3000000 | 10000000 | 500000 | 36.00 |" ]
    [ "${lines[3]}" = "| claude-sonnet-5-5 | 500000 | 0 | 1000000 | 100000 | 2.20 |" ]
    [ "${lines[4]}" = "| total | 1500000 | 3000000 | 11000000 | 600000 | 38.20 |" ]
}

@test "a DIR sums every transcript below it, subagents included" {
    cp "$FIXTURES/two-models.jsonl" "$SESSIONS/sess1.jsonl"
    mkdir -p "$SESSIONS/sess1/subagents"
    cp "$FIXTURES/subagent.jsonl" "$SESSIONS/sess1/subagents/agent-x.jsonl"
    run --separate-stderr "$SCRIPT" "$SESSIONS"
    [ "$status" -eq 0 ]
    [ "${lines[3]}" = "| claude-sonnet-5-5 | 1000000 | 0 | 1000000 | 200000 | 4.20 |" ]
}

@test "no argument reads the newest session and its subagents" {
    cp "$FIXTURES/unknown.jsonl" "$SESSIONS/old.jsonl"
    touch -d '2020-01-01' "$SESSIONS/old.jsonl"
    cp "$FIXTURES/two-models.jsonl" "$SESSIONS/sess1.jsonl"
    mkdir -p "$SESSIONS/sess1/subagents"
    cp "$FIXTURES/subagent.jsonl" "$SESSIONS/sess1/subagents/agent-x.jsonl"
    run --separate-stderr "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "${lines[4]}" = "| total | 2000000 | 3000000 | 11000000 | 700000 | 40.20 |" ]
}

@test "an unknown model keeps its tokens, its dollars are ? and the total says so" {
    run --separate-stderr "$SCRIPT" "$FIXTURES/unknown.jsonl"
    [ "$status" -eq 0 ]
    [ "${lines[2]}" = "| claude-mystery-9 | 100 | 0 | 0 | 50 | ? |" ]
    [ "${lines[3]}" = "| total | 100 | 0 | 0 | 50 | ? |" ]
}

@test "a known total plus an unknown model reads <known>+?" {
    cat "$FIXTURES/two-models.jsonl" "$FIXTURES/unknown.jsonl" >"$BATS_TEST_TMPDIR/mixed.jsonl"
    run --separate-stderr "$SCRIPT" "$BATS_TEST_TMPDIR/mixed.jsonl"
    [ "${lines[-1]}" = "| total | 1500100 | 3000000 | 11000000 | 600050 | 38.20+? |" ]
}

@test "--self prints the 1 line summary of the newest session" {
    cp "$FIXTURES/two-models.jsonl" "$SESSIONS/sess1.jsonl"
    run --separate-stderr "$SCRIPT" --self
    [ "$status" -eq 0 ]
    [ "$output" = "Burn: in=1500000 cw=3000000 cr=11000000 out=600000 \$38.20 (claude-opus-5-5, claude-sonnet-5-5)" ]
}

@test "--self with an unknown model prints \$?" {
    run --separate-stderr "$SCRIPT" --self "$FIXTURES/unknown.jsonl"
    [ "$output" = "Burn: in=100 cw=0 cr=0 out=50 \$? (claude-mystery-9)" ]
}

@test "--self without a transcript is unmeasured (no-transcript), exit 0, no path" {
    run --separate-stderr "$SCRIPT" --self
    [ "$status" -eq 0 ]
    [ "$output" = "Burn: unmeasured (no-transcript)" ]
}

@test "--self with a transcript lacking usage is unmeasured (no-usage)" {
    run --separate-stderr "$SCRIPT" --self "$FIXTURES/nousage"
    [ "$status" -eq 0 ]
    [ "$output" = "Burn: unmeasured (no-usage)" ]
}

@test "no transcript exits 1 naming the dir (V26)" {
    run --separate-stderr "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"$HOME/.claude/projects"* ]]
}

@test "--pr sums trusted Burn lines only; a non-member's line is skipped" {
    run --separate-stderr "$SCRIPT" --pr 7
    [ "$status" -eq 0 ]
    [ "${lines[2]}" = "| 1 | 100 | 200 | 300 | 400 | 1.50 |" ]
    [ "${lines[3]}" = "| 2 | 10 | 20 | 30 | 40 | 0.25 |" ]
    [ "${lines[4]}" = "| total | 110 | 220 | 330 | 440 | 1.75 |" ]
    run ! grep -q '^pr comment' "$GH_LOG"
}

@test "--pr --post writes 1 ## Burn comment" {
    run --separate-stderr "$SCRIPT" --pr 7 --post
    [ "$status" -eq 0 ]
    grep -q '^pr comment 7' "$GH_LOG"
    grep -q '^## Burn$' "$GH_LOG"
    grep -q '^| total | 110 ' "$GH_LOG"
}

@test "--post without --pr is refused" {
    run --separate-stderr "$SCRIPT" --post
    [ "$status" -eq 2 ]
}
