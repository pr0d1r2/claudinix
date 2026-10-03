#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/guide.sh (SPEC scripts:T26, I.cmd `guide`,
# C2, .:V10). Answers come on stdin; open, the clipboard, claude and the
# inputs/domains/setup-line tools are stubs, so nothing leaves the test.

setup() {
    REPO="$BATS_TEST_DIRNAME/../../.."
    SCRIPT="$REPO/scripts/guide.sh"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    LIB="$BATS_TEST_TMPDIR/lib"
    P="$BATS_TEST_TMPDIR/project"
    export LOG="$BATS_TEST_TMPDIR/log"
    export CLAUDINIX_SCRIPTS="$LIB"
    export CLAUDINIX_SETUP_REV=0123456789abcdef0123456789abcdef01234567
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
            'echo "pr0d1r2/a 1111 uncached"' 'echo "NixOS/nixpkgs 2222 cached"' >"$LIB/inputs.sh"
        printf '%s\n' '#!/usr/bin/env bash' 'echo "domains $*" >>"$LOG"' \
            'printf "%s\n" pr0d1r2.cachix.org index.crates.io' >"$LIB/domains.sh"
        printf '%s\n' '#!/usr/bin/env bash' 'echo "setup-line $*" >>"$LOG"' \
            '[ "${SETUP_LINE_RC:-0}" = 0 ] || { echo "setup-line: CI is not green -- pass --force" >&2; exit 1; }' \
            'echo "SETUP-LINE ${*: -1}"' >"$LIB/setup-line.sh"
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

@test "step 3 copies the env name, the allowed domains and the setup line" {
    run bash "$SCRIPT" --from 3 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    grep -qx 'nix' "$LOG"
    grep -qx 'domains .' "$LOG"
    grep -qx 'index.crates.io' "$LOG"
    grep -qx "setup-line $CLAUDINIX_SETUP_REV" "$LOG"
    grep -qx "SETUP-LINE $CLAUDINIX_SETUP_REV" "$LOG"
    run ! grep -qx '#!/usr/bin/env bash' "$LOG"
    [ "$(grep -c '^--- clip' "$LOG")" -eq 3 ]
}

@test "step 5 lists the uncached github inputs with the remedy, before the launch (T81)" {
    run bash "$SCRIPT" --from 5 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    grep -qx 'inputs .' "$LOG"
    [[ "$output" == *"  pr0d1r2/a"* ]]
    [[ "$output" != *"NixOS/nixpkgs"* ]]
    [[ "$output" == *"nix-dev"* ]]
    [[ "$output" == *"git+https://github.com/<owner>/<repo>"* ]]
    inputs_at="$(grep -n '  pr0d1r2/a' <<<"$output" | head -n 1 | cut -d: -f1)"
    launch_at="$(grep -n 'claude --cloud "<task>"' <<<"$output" | head -n 1 | cut -d: -f1)"
    [ "$inputs_at" -lt "$launch_at" ]
}

@test "step 5 with every input cached: says nothing comes from GitHub (T81)" {
    printf '%s\n' '#!/usr/bin/env bash' 'echo "NixOS/nixpkgs 2222 cached"' >"$LIB/inputs.sh"
    run bash "$SCRIPT" --from 5 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"every github input is in a cache"* ]]
}

@test "step 5 when inputs cannot run: says so and goes on (T81)" {
    printf '%s\n' '#!/usr/bin/env bash' 'echo "inputs: nix flake archive could not run" >&2' 'exit 1' >"$LIB/inputs.sh"
    run bash "$SCRIPT" --from 5 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"could not run"* ]]
    [[ "$output" == *"could not check the inputs"* ]]
}

@test "step 5's first check runs the dev shell through nix-dev on sonnet (T81)" {
    run bash "$SCRIPT" --from 5 <<<$'y\ny\n'
    [[ "$output" == *'claude --cloud "Run: nix --version && nix-dev -c true && echo DEVSHELL-OK. Report the output." --model sonnet'* ]]
    [[ "$output" != *"nix develop -c true"* ]]
}

@test "step 0 accepts none for a credit you were never offered (T81)" {
    run bash "$SCRIPT" --from 5 <<<$'none\ny\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"none"* ]]
    run bash "$SCRIPT" --from 5 <<<$'\ny\n'
    [ "$status" -eq 1 ]
}

@test "step 1 prints the project dir absolute (T81)" {
    run bash "$SCRIPT" --from 1 <<<$'y\ny\n'
    [[ "$output" == *"todo: run nix flake lock in $P "* ]]
    touch "$P/flake.lock"
    run bash "$SCRIPT" --from 1 <<<$'y\ny\n'
    [[ "$output" == *"ok: $P has a flake.lock"* ]]
}

@test "a missing project dir: stops before step 0, naming it as given (T81)" {
    run bash "$SCRIPT" "$BATS_TEST_TMPDIR/nonexistent" <<<$'y\ny\n'
    [ "$status" -eq 1 ]
    [[ "$output" == *"$BATS_TEST_TMPDIR/nonexistent"* ]]
    [[ "$output" != *"== 0."* ]]
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
    run ! grep -q "(probe 6)" <<<"$output"
    run bash "$SCRIPT" --from 5 <<<$'y\ny\nopus\n'
    [[ "$output" == *'claude --cloud "<task>" --model opus'* ]]
}

@test "update: the Updating the environment flow" {
    run bash "$SCRIPT" update <<<''
    [ "$status" -eq 0 ]
    [ "$(titles "$output")" = "== Updating the environment (after a change here) ==" ]
    [[ "$output" == *"start page"* ]]
    [[ "$output" == *"new session"* ]]
    grep -qx "SETUP-LINE $CLAUDINIX_SETUP_REV" "$LOG"
    grep -qx 'index.crates.io' "$LOG"
}

@test "no clipboard and no opener: values printed, still passes" {
    CLIPBOARD_TOOLS=none GUIDE_OPEN_TOOLS=none run bash "$SCRIPT" --from 3 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"https://claude.ai/code"* ]]
    [[ "$output" == *"index.crates.io"* ]]
}

@test "the clipboard tool's own output never reaches ours (xclip, scripts:T80)" {
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' 'cat >>"$LOG"' 'echo CLIP-STDOUT' 'echo CLIP-STDERR >&2' >"$STUBS/xclip"
    chmod +x "$STUBS/xclip"
    CLIPBOARD_TOOLS="$STUBS/xclip" run bash "$SCRIPT" update <<<''
    [ "$status" -eq 0 ]
    [[ "$output" == *"(copied to the clipboard)"* ]]
    [[ "$output" != *"CLIP-STDOUT"* ]]
    [[ "$output" != *"CLIP-STDERR"* ]]
}

@test "unknown flag or step is a usage error" {
    run bash "$SCRIPT" --nope </dev/null
    [ "$status" -eq 2 ]
    run bash "$SCRIPT" --from 9 </dev/null
    [ "$status" -eq 2 ]
}

# A MODEL.md price table with prices no real model has, so a hit can
# only come from reading this file (scripts:T26).
model_doc() {
    printf '%s\n' '# Model choice' '' '| model | input | output |' '|---|---|---|' \
        "| Claude Opus 5.5 | $1 |" "| Claude Sonnet 5.5 | $2 |" >"$BATS_TEST_TMPDIR/MODEL.md"
}

# shellcheck disable=SC2016 # literal dollar prices, not expansions
@test "step 5 reads the Sonnet and Opus prices from MODEL.md (scripts:T26)" {
    model_doc '$7.77 | $38.88' '$3.33 | $16.66'
    CLAUDINIX_MODEL_DOC="$BATS_TEST_TMPDIR/MODEL.md" run bash "$SCRIPT" --from 5 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *'$3.33'* ]]
    [[ "$output" == *'$16.66'* ]]
    [[ "$output" == *'$7.77'* ]]
    [[ "$output" == *'$38.88'* ]]
    [[ "$output" != *"see docs/MODEL.md"* ]]
}

# shellcheck disable=SC2016 # literal dollar prices, not expansions
@test "step 5: the repo's own MODEL.md parses, prices match its table (scripts:T26)" {
    doc="$REPO/docs/MODEL.md"
    sonnet="$(grep -F '| Claude Sonnet 5.5 |' "$doc" | cut -d'|' -f3 | tr -d ' ')"
    opus="$(grep -F '| Claude Opus 5.5 |' "$doc" | cut -d'|' -f3 | tr -d ' ')"
    [ -n "$sonnet" ] && [ -n "$opus" ]
    CLAUDINIX_MODEL_DOC="$doc" run bash "$SCRIPT" --from 5 <<<$'y\ny\n'
    [[ "$output" == *"$sonnet"* ]]
    [[ "$output" == *"$opus"* ]]
    [[ "$output" != *"see docs/MODEL.md"* ]]
}

# shellcheck disable=SC2016 # literal dollar prices, not expansions
@test "step 5: MODEL.md missing: points at it, shows no price (scripts:T26)" {
    CLAUDINIX_MODEL_DOC="$BATS_TEST_TMPDIR/nope.md" run bash "$SCRIPT" --from 5 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"see docs/MODEL.md"* ]]
    run ! grep -E '\$[0-9]' <<<"$output"
}

# shellcheck disable=SC2016 # literal dollar prices, not expansions
@test "step 5: a price that is not a dollar amount is not shown (scripts:T26)" {
    model_doc 'TBD | $38.88' '$3.33 | soon'
    CLAUDINIX_MODEL_DOC="$BATS_TEST_TMPDIR/MODEL.md" run bash "$SCRIPT" --from 5 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    [ "$(grep -c 'see docs/MODEL.md' <<<"$output")" -eq 2 ]
    run ! grep -E '\$[0-9]' <<<"$output"
}

# shellcheck disable=SC2016 # literal dollar prices, not expansions
@test "step 5: a model missing from the table points at MODEL.md (scripts:T26)" {
    printf '%s\n' '| model | input | output |' '| Claude Opus 5.5 | $7.77 | $38.88 |' >"$BATS_TEST_TMPDIR/MODEL.md"
    CLAUDINIX_MODEL_DOC="$BATS_TEST_TMPDIR/MODEL.md" run bash "$SCRIPT" --from 5 <<<$'y\ny\n'
    [[ "$output" == *'$7.77'* ]]
    [[ "$output" == *"see docs/MODEL.md"* ]]
}

@test "setup line refused (CI not green): guide stops, copies nothing for it (T69)" {
    SETUP_LINE_RC=1 run bash "$SCRIPT" --from 3 <<<$'y\ny\n'
    [ "$status" -eq 1 ]
    [[ "$output" == *"--force"* ]]
    run ! grep -q 'SETUP-LINE' "$LOG"
}

@test "--force reaches setup-line, in setup and update flows (T69)" {
    run bash "$SCRIPT" --force --from 3 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    grep -qx "setup-line --force $CLAUDINIX_SETUP_REV" "$LOG"
    : >"$LOG"
    run bash "$SCRIPT" update --force <<<''
    [ "$status" -eq 0 ]
    grep -qx "setup-line --force $CLAUDINIX_SETUP_REV" "$LOG"
}

@test "--agent-home reaches setup-line, in setup and update flows (.:C24)" {
    run bash "$SCRIPT" --agent-home --from 3 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    grep -qx "setup-line --agent-home $CLAUDINIX_SETUP_REV" "$LOG"
    : >"$LOG"
    run bash "$SCRIPT" update --force --agent-home <<<''
    [ "$status" -eq 0 ]
    grep -qx "setup-line --force --agent-home $CLAUDINIX_SETUP_REV" "$LOG"
}

@test "without --agent-home, setup-line is not asked for it (.:C24)" {
    run bash "$SCRIPT" update <<<''
    [ "$status" -eq 0 ]
    run ! grep -q -- '--agent-home' "$LOG"
}

@test "no CLAUDINIX_SETUP_REV: the line is for HEAD of the clone the guide runs from" {
    while read -r var; do unset "$var"; done < <(env | sed -n 's/^\(GIT_[A-Z_]*\)=.*/\1/p')
    unset CLAUDINIX_SETUP_REV
    clone="$BATS_TEST_TMPDIR/clone"
    mkdir -p "$clone"
    cp -R "$LIB" "$clone/scripts"
    git init -q "$clone"
    git -C "$clone" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m one
    head="$(git -C "$clone" rev-parse HEAD)"
    CLAUDINIX_SCRIPTS="$clone/scripts" run bash "$SCRIPT" update <<<''
    [ "$status" -eq 0 ]
    grep -qx "setup-line $head" "$LOG"
}

@test "no CLAUDINIX_SETUP_REV and not in a clone: says how to pin, stops" {
    unset CLAUDINIX_SETUP_REV
    GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" run bash "$SCRIPT" update <<<''
    [ "$status" -eq 1 ]
    [[ "$output" == *"CLAUDINIX_SETUP_REV"* ]]
    run ! grep -q 'SETUP-LINE' "$LOG"
}

@test "step 3 lists the env vars from env-names.txt, optional ones marked (T48)" {
    env_file="$BATS_TEST_TMPDIR/env-names.txt"
    printf '%s\n' '# header' '' '# Does something.' 'NEEDED=1' \
        '# Optional: not needed.' 'EXTRA_MS=5' >"$env_file"
    CLAUDINIX_ENV_NAMES="$env_file" run bash "$SCRIPT" --from 3 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    grep -qx '  NEEDED=1' <<<"$output"
    grep -qx '  EXTRA_MS=5   (optional)' <<<"$output"
    run ! grep -q 'header' <<<"$output"
}

@test "step 3 with the repo's env-names.txt shows the optional Bash timeout (T48)" {
    CLAUDINIX_ENV_NAMES="$REPO/env-names.txt" run bash "$SCRIPT" --from 3 <<<$'y\ny\n'
    grep -qx '  BASH_DEFAULT_TIMEOUT_MS=600000   (optional)' <<<"$output"
    [[ "$output" != *"ANTHROPIC_MODEL="* ]]
}

@test "step 3 without env-names.txt points at it and goes on (T48)" {
    CLAUDINIX_ENV_NAMES="$BATS_TEST_TMPDIR/none.txt" run bash "$SCRIPT" --from 3 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"env-names.txt"* ]]
}
