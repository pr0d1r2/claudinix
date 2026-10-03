#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/guide.sh (SPEC scripts:T26, I.cmd `guide`,
# C2, .:V10). Answers come on stdin; open, the clipboard, claude and the
# inputs/domains tools are stubs, so nothing leaves the test.

setup() {
    REPO="$BATS_TEST_DIRNAME/../../.."
    SCRIPT="$REPO/scripts/guide.sh"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    LIB="$BATS_TEST_TMPDIR/lib"
    P="$BATS_TEST_TMPDIR/project"
    export LOG="$BATS_TEST_TMPDIR/log"
    export NCCC_SCRIPTS="$LIB"
    export NCCC_SETUP="$REPO/setup.sh"
    export CLAUDE_SETTINGS="$BATS_TEST_TMPDIR/settings.json"
    export CLIPBOARD_TOOLS="$STUBS/pbcopy"
    export GUIDE_OPEN_TOOLS="$STUBS/open"
    mkdir -p "$STUBS" "$LIB" "$P"
    : >"$LOG"
    cp "$REPO/scripts/guide-steps.tsv" "$LIB/"
    echo '{"remote":{"defaultEnvironmentId":"env_123"}}' >"$CLAUDE_SETTINGS"

    # shellcheck disable=SC2016 # expands inside the stubs, not here
    {
        printf '%s\n' '#!/usr/bin/env bash' 'echo "open $*" >>"$LOG"' >"$STUBS/open"
        printf '%s\n' '#!/usr/bin/env bash' 'echo "--- clip" >>"$LOG"' 'cat >>"$LOG"' >"$STUBS/pbcopy"
        printf '%s\n' '#!/usr/bin/env bash' 'echo "claude $*" >>"$LOG"' 'exit "${CLAUDE_RC:-0}"' >"$STUBS/claude"
        printf '%s\n' '#!/usr/bin/env bash' 'echo "inputs $*" >>"$LOG"' \
            'echo "pr0d1r2/a 1111 attach"' 'echo "NixOS/nixpkgs 2222 cached"' >"$LIB/inputs.sh"
        printf '%s\n' '#!/usr/bin/env bash' 'echo "domains $*" >>"$LOG"' \
            'printf "%s\n" pr0d1r2.cachix.org index.crates.io' >"$LIB/domains.sh"
    }
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"
    cd "$P" || return 1
}

# Every step's title, in order, as the guide prints it.
titles() {
    grep -E '^== ' <<<"$1"
}

@test "parity: guide steps are the SETUP.md step headings, in order (no drift)" {
    want="$(grep -E '^## ([0-9]+\. |Updating the environment)' "$REPO/docs/SETUP.md" |
        while IFS= read -r h; do
            h="${h#\#\# }"
            case "$h" in
            [0-9]*) printf '%s\t%s\n' "${h%%. *}" "${h#*. }" ;;
            *) printf 'update\t%s\n' "$h" ;;
            esac
        done)"
    [ -n "$want" ]
    have="$(grep -v '^#' "$REPO/scripts/guide-steps.tsv" | cut -f 1,2)"
    [ "$have" = "$want" ]
}

@test "full walk: steps 0-5 in order, exit 0" {
    run bash "$SCRIPT" <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    t="$(titles "$output")"
    [ "$(sed -n 1p <<<"$t")" = "== 0. Before your first cloud session: protect your money ==" ]
    [ "$(sed -n 6p <<<"$t")" = "== 5. Run a first session and check that it works ==" ]
    [ "$(wc -l <<<"$t" | tr -d ' ')" -eq 6 ]
}

@test "step 0 needs an explicit y for each money check" {
    run bash "$SCRIPT" <<<$'y\n\n'
    [ "$status" -eq 1 ]
    [[ "$output" == *"usage credits"* ]]
    [[ "$output" != *"== 1."* ]]
}

@test "--from resumes at a step, but step 0 is never skipped" {
    run bash "$SCRIPT" --from 3 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    t="$(titles "$output")"
    [ "$(sed -n 1p <<<"$t")" = "== 0. Before your first cloud session: protect your money ==" ]
    [ "$(sed -n 2p <<<"$t")" = "== 3. Create the environment (browser, once) ==" ]
}

@test "each browser step opens its URL" {
    run bash "$SCRIPT" <<<$'y\ny\n'
    grep -qx 'open https://claude.ai/settings/usage' "$LOG"
    grep -qx 'open https://github.com/apps/claude' "$LOG"
    grep -qx 'open https://claude.ai/code' "$LOG"
}

@test "step 3 copies the env name, the allowed domains and the setup script" {
    run bash "$SCRIPT" --from 3 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    grep -qx 'nix' "$LOG"
    grep -qx 'domains .' "$LOG"
    grep -qx 'index.crates.io' "$LOG"
    grep -qx '#!/usr/bin/env bash' "$LOG"
    [ "$(grep -c '^--- clip' "$LOG")" -eq 3 ]
}

@test "step 3 lists the github repos to attach, from inputs" {
    run bash "$SCRIPT" --from 3 <<<$'y\ny\n'
    grep -qx 'inputs .' "$LOG"
    [[ "$output" == *"pr0d1r2/a"* ]]
    [[ "$output" != *"NixOS/nixpkgs 2222"* ]]
}

@test "step 1 checks the claude.ai sign-in" {
    CLAUDE_RC=1 run bash "$SCRIPT" <<<$'y\ny\n'
    grep -qx 'claude auth status' "$LOG"
    [[ "$output" == *"claude auth login"* ]]
}

@test "step 4 checks remote.defaultEnvironmentId" {
    run bash "$SCRIPT" --from 4 <<<$'y\ny\n'
    [[ "$output" == *"env_123"* ]]
    echo '{}' >"$CLAUDE_SETTINGS"
    run bash "$SCRIPT" --from 4 <<<$'y\ny\n'
    [[ "$output" == *"/remote-env"* ]]
}

@test "step 5 asks the model and prints the launch form; sonnet by default" {
    run bash "$SCRIPT" --from 5 <<<$'y\ny\n'
    [[ "$output" == *'claude --cloud "<task>" --model sonnet'* ]]
    [[ "$output" == *"Co-Authored-By"* ]]
    [[ "$output" == *"ANTHROPIC_MODEL"* ]]
    run bash "$SCRIPT" --from 5 <<<$'y\ny\nopus\n'
    [[ "$output" == *'claude --cloud "<task>" --model opus'* ]]
}

@test "update: the Updating the environment flow" {
    run bash "$SCRIPT" update <<<''
    [ "$status" -eq 0 ]
    [ "$(titles "$output")" = "== Updating the environment (after a change here) ==" ]
    [[ "$output" == *"start page"* ]]
    [[ "$output" == *"new session"* ]]
    grep -qx '#!/usr/bin/env bash' "$LOG"
    grep -qx 'index.crates.io' "$LOG"
}

@test "no clipboard and no opener: values printed, still passes" {
    CLIPBOARD_TOOLS=none GUIDE_OPEN_TOOLS=none run bash "$SCRIPT" --from 3 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"https://claude.ai/code"* ]]
    [[ "$output" == *"index.crates.io"* ]]
}

@test "unknown flag or step is a usage error" {
    run bash "$SCRIPT" --nope </dev/null
    [ "$status" -eq 2 ]
    run bash "$SCRIPT" --from 9 </dev/null
    [ "$status" -eq 2 ]
}
