#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/guide.sh (SPEC scripts:T26, I.cmd `guide`,
# C2, .:V10, .:C25). Answers come on stdin; open, the clipboard, claude and
# the inputs/domains/setup-line tools are stubs, so nothing leaves the test.
# The setup line comes from a README release block written by the real
# readme-setup-line.sh, so the guide reads the format the release writes.

setup() {
    REPO="$BATS_TEST_DIRNAME/../../.."
    SCRIPT="$REPO/scripts/guide.sh"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    LIB="$BATS_TEST_TMPDIR/lib"
    P="$BATS_TEST_TMPDIR/project"
    export LOG="$BATS_TEST_TMPDIR/log"
    export CLAUDINIX_SCRIPTS="$LIB"
    export SHA=0123456789abcdef0123456789abcdef01234567
    REL=89abcdef0123456789abcdef0123456789abcdef
    export CLAUDINIX_README="$BATS_TEST_TMPDIR/release/README.md"
    unset CLAUDINIX_SETUP_REV
    export CLAUDE_SETTINGS="$BATS_TEST_TMPDIR/settings.json"
    export CLIPBOARD_TOOLS="$STUBS/pbcopy"
    export GUIDE_OPEN_TOOLS="$STUBS/open"
    export GH_BIN="$STUBS/gh"
    mkdir -p "$STUBS" "$LIB" "$P" "${CLAUDINIX_README%/*}"
    : >"$LOG"
    cp "$REPO/scripts/guide-steps.tsv" "$LIB/"
    # The real config reader: a project without .claudinix.toml gets the
    # defaults and no nix call (scripts:T91).
    cp "$REPO/scripts/config.sh" "$REPO/scripts/config.jq" "$LIB/"
    unset CLAUDINIX_CONFIG CLAUDINIX_CONFIG_JSON
    echo '{"remote":{"defaultEnvironmentId":"env_123"}}' >"$CLAUDE_SETTINGS"

    # shellcheck disable=SC2016 # expands inside the stubs, not here
    {
        printf '%s\n' '#!/usr/bin/env bash' 'echo "open $*" >>"$LOG"' >"$STUBS/open"
        printf '%s\n' '#!/usr/bin/env bash' 'echo "--- clip" >>"$LOG"' 'cat >>"$LOG"' >"$STUBS/pbcopy"
        printf '%s\n' '#!/usr/bin/env bash' 'echo "claude $*" >>"$LOG"' 'exit "${CLAUDE_RC:-0}"' >"$STUBS/claude"
        # gh: the newest green main SHA for the pre-release hint (scripts:T114).
        printf '%s\n' '#!/usr/bin/env bash' 'echo "gh $*" >>"$LOG"' \
            '[ -z "${GH_HEAD:-}" ] || echo "$GH_HEAD"' 'exit "${GH_RC:-0}"' >"$STUBS/gh"
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
    printf '%s\n' '# claudinix' '<!-- BEGIN setup-line -->' '<!-- END setup-line -->' '' '## Next' >"$CLAUDINIX_README"
    README_FILE="$CLAUDINIX_README" bash "$REPO/scripts/guard/readme-setup-line.sh" --write "$REL"
    LINE="$(GH_BIN=claudinix-no-gh-offline bash "$REPO/scripts/setup-line.sh" --force "$REL" 2>/dev/null)"
    cd "$P" || return 1
}

# no_release: the README block as it is before the first release (.:C25).
no_release() {
    # shellcheck disable=SC2016 # literal Markdown backticks, not a command
    printf '%s\n' '<!-- BEGIN setup-line -->' \
        'No release yet: the maintainer publishes the line with `scripts/release.sh record`, then `scripts/release.sh publish`.' \
        '<!-- END setup-line -->' >"$CLAUDINIX_README"
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

@test "step 3 copies the env name, the allowed domains and the README's release line (.:C25)" {
    run bash "$SCRIPT" --from 3 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    grep -qx 'nix' "$LOG"
    grep -qx 'domains .' "$LOG"
    grep -qx 'index.crates.io' "$LOG"
    grep -qxF "$LINE" "$LOG"
    run ! grep -q 'setup-line' "$LOG"
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
    grep -qxF "$LINE" "$LOG"
    run ! grep -q 'setup-line' "$LOG"
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

@test "--agent-home appends --agent-home to the README's line, in setup and update flows (.:C24)" {
    run bash "$SCRIPT" --agent-home --from 3 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    grep -qxF "$LINE --agent-home" "$LOG"
    : >"$LOG"
    run bash "$SCRIPT" update --agent-home <<<''
    [ "$status" -eq 0 ]
    grep -qxF "$LINE --agent-home" "$LOG"
    run ! grep -q 'setup-line' "$LOG"
}

@test "without --agent-home, the copied line does not ask for it (.:C24)" {
    run bash "$SCRIPT" update <<<''
    [ "$status" -eq 0 ]
    run ! grep -q -- '--agent-home' "$LOG"
}

@test "no CLAUDINIX_README: the README beside the scripts dir (.:C25)" {
    unset CLAUDINIX_README
    cp "$BATS_TEST_TMPDIR/release/README.md" "$LIB/../README.md"
    run bash "$SCRIPT" update <<<''
    [ "$status" -eq 0 ]
    grep -qxF "$LINE" "$LOG"
}

@test "no release yet: says so, says what to do, stops before step 4, asks nobody (.:C25)" {
    no_release
    run bash "$SCRIPT" --from 3 <<<$'y\ny\n'
    [ "$status" -eq 1 ]
    [[ "$output" == *"guide: stop here -- no release yet"* ]]
    [[ "$output" == *"--rev SHA"* ]]
    [[ "$output" != *"== 4."* ]]
    run ! grep -q 'setup-line' "$LOG"
    run ! grep -q 'SETUP-LINE' "$LOG"
}

@test "no release yet in the update flow: stops the same way (.:C25)" {
    no_release
    run bash "$SCRIPT" update <<<''
    [ "$status" -eq 1 ]
    [[ "$output" == *"no release yet"* ]]
    run ! grep -q 'setup-line' "$LOG"
}

@test "a README with no setup-line block: names it and stops (.:C25)" {
    printf '%s\n' '# claudinix' >"$CLAUDINIX_README"
    run bash "$SCRIPT" update <<<''
    [ "$status" -eq 1 ]
    [[ "$output" == *"$CLAUDINIX_README"* ]]
    [[ "$output" == *"--rev SHA"* ]]
    rm "$CLAUDINIX_README"
    run bash "$SCRIPT" update <<<''
    [ "$status" -eq 1 ]
    [[ "$output" == *"$CLAUDINIX_README"* ]]
}

@test "the repo's own README: a release line, or no release yet (.:C25)" {
    CLAUDINIX_README="$REPO/README.md" run bash "$SCRIPT" update <<<''
    if [ "$status" -eq 0 ]; then
        grep -qE '^d=\$\(mktemp -d\) && curl ' "$LOG"
    else
        [ "$status" -eq 1 ]
        [[ "$output" == *"no release yet"* ]]
    fi
}

@test "no release yet and --rev SHA: setup-line.sh prints the line for that SHA (.:C25)" {
    no_release
    run bash "$SCRIPT" --rev "$SHA" --from 3 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    grep -qx "setup-line $SHA" "$LOG"
    grep -qx "SETUP-LINE $SHA" "$LOG"
}

@test "--rev wins over a release in the README (.:C25)" {
    run bash "$SCRIPT" update --rev "$SHA" <<<''
    [ "$status" -eq 0 ]
    grep -qx "setup-line $SHA" "$LOG"
    run ! grep -qxF "$LINE" "$LOG"
}

@test "--rev needs a full SHA (.:C25)" {
    run bash "$SCRIPT" --rev abc123 </dev/null
    [ "$status" -eq 2 ]
    run bash "$SCRIPT" --rev </dev/null
    [ "$status" -eq 2 ]
}

@test "CLAUDINIX_SETUP_REV still pins the line through setup-line.sh (maintainer path)" {
    no_release
    CLAUDINIX_SETUP_REV="$SHA" run bash "$SCRIPT" update <<<''
    [ "$status" -eq 0 ]
    grep -qx "setup-line $SHA" "$LOG"
    grep -qx "SETUP-LINE $SHA" "$LOG"
}

@test "setup line refused (CI not green): guide stops, copies nothing for it (T69)" {
    no_release
    SETUP_LINE_RC=1 run bash "$SCRIPT" --rev "$SHA" --from 3 <<<$'y\ny\n'
    [ "$status" -eq 1 ]
    [[ "$output" == *"--force"* ]]
    run ! grep -q 'SETUP-LINE' "$LOG"
}

@test "--force and --agent-home reach setup-line with --rev, in setup and update flows (T69, .:C24)" {
    no_release
    run bash "$SCRIPT" --force --rev "$SHA" --from 3 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    grep -qx "setup-line --force $SHA" "$LOG"
    : >"$LOG"
    run bash "$SCRIPT" update --force --agent-home --rev "$SHA" <<<''
    [ "$status" -eq 0 ]
    grep -qx "setup-line --force --agent-home $SHA" "$LOG"
    : >"$LOG"
    run bash "$SCRIPT" update --agent-home --rev "$SHA" <<<''
    [ "$status" -eq 0 ]
    grep -qx "setup-line --agent-home $SHA" "$LOG"
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

# .claudinix.toml (scripts:T91, scripts:V34): flag (or answer) > file > default.

# config LINE...: the project's .claudinix.toml.
config() {
    printf '%s\n' 'version = 1' "$@" >"$P/.claudinix.toml"
}

@test "session.model is step 5's default; the answer still wins" {
    config '[session]' 'model = "opus"'
    run bash "$SCRIPT" --from 5 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"(Enter: opus)"* ]]
    [[ "$output" == *'claude --cloud "<task>" --model opus'* ]]
    run bash "$SCRIPT" --from 5 <<<$'y\ny\nsonnet\n'
    [[ "$output" == *'claude --cloud "<task>" --model sonnet'* ]]
    run bash "$SCRIPT" --from 5 <<<$'y\ny\nhaiku\n'
    [[ "$output" == *"using opus"* ]]
    [[ "$output" == *'claude --cloud "<task>" --model opus'* ]]
}

@test "session.agent_home = true asks the line for the agent home; --no-agent-home wins" {
    config '[session]' 'agent_home = true'
    run bash "$SCRIPT" update <<<''
    [ "$status" -eq 0 ]
    grep -qxF "$LINE --agent-home" "$LOG"
    : >"$LOG"
    run bash "$SCRIPT" update --no-agent-home <<<''
    [ "$status" -eq 0 ]
    run ! grep -q -- '--agent-home' "$LOG"
    : >"$LOG"
    run bash "$SCRIPT" update --no-agent-home --rev "$SHA" <<<''
    grep -qx "setup-line $SHA" "$LOG"
}

@test "devshell.installable goes into the first check's nix-dev" {
    config '[devshell]' 'installable = ".#ci"'
    run bash "$SCRIPT" --from 5 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *'nix-dev .#ci -c true && echo DEVSHELL-OK'* ]]
}

# shellcheck disable=SC2016 # literal $ in the installable, not expanded
@test "devshell.installable is shell-quoted in the first check: run as printed, it is one word (scripts:T95)" {
    config '[devshell]' 'installable = "./a;b$c|d&e"'
    run bash "$SCRIPT" --from 5 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    line="$(grep -F 'DEVSHELL-OK. Report the output.' <<<"$output")"
    # The terminal's shell: claude gets the task as one argument.
    claude() { printf '%s' "$2"; }
    task="$(eval "$line")"
    cmd="${task#Run: }"
    cmd="${cmd%. Report the output.}"
    # The session's shell: nix-dev gets the installable as one argument.
    nix() { :; }
    nix-dev() { printf '%s\n' "$#" "$1" >"$BATS_TEST_TMPDIR/args"; }
    eval "$cmd" >/dev/null
    [ "$(sed -n 1p "$BATS_TEST_TMPDIR/args")" = 3 ]
    [ "$(sed -n 2p "$BATS_TEST_TMPDIR/args")" = './a;b$c|d&e' ]
}

@test "an installable with a space is refused before step 0 (scripts:T95)" {
    config '[devshell]' 'installable = "path:./a b"'
    run bash "$SCRIPT" <<<$'y\ny\n'
    [ "$status" -eq 2 ]
    [[ "$output" == *'devshell.installable'*'"path:./a b"'* ]]
    [[ "$output" != *"== 0."* ]]
}

@test "one nix eval per run: the real domains and inputs get the config the guide read (scripts:T96)" {
    # The real tools in place of the stubs; nix logs each call, eval is
    # the real nix, flake archive prints the fixture tree.
    local repo_scripts="$REPO/scripts"
    cp -R "$repo_scripts/domains" "$LIB/"
    cp "$repo_scripts/domains.sh" "$repo_scripts/inputs.sh" "$repo_scripts/inputs.jq" "$LIB/"
    cp "$REPO/tests/fixtures/inputs/nested/flake.lock" "$P/"
    export NIX_ARCHIVE="$REPO/tests/fixtures/inputs/nested/archive.json"
    export NIX_LOG="$BATS_TEST_TMPDIR/nix.log"
    export CLAUDINIX_ALLOWLIST="$REPO/allowlist.txt"
    REAL_NIX="$(command -v nix)"
    export REAL_NIX
    # shellcheck disable=SC2016 # expands inside the stubs, not here
    {
        printf '%s\n' '#!/usr/bin/env bash' 'echo "$*" >>"$NIX_LOG"' \
            '[ "$1" != eval ] || exec "$REAL_NIX" "$@"' \
            '[ "$1 $2" = "flake archive" ] || exit 9' 'cat "$NIX_ARCHIVE"' >"$STUBS/nix"
        printf '%s\n' '#!/usr/bin/env bash' 'printf 404' >"$STUBS/curl"
    }
    chmod +x "$STUBS/nix" "$STUBS/curl"
    : >"$NIX_LOG"
    config '[network]' 'extra_domains = ["extra.example.org"]' '[cache]' 'name = "forker"'
    run bash "$SCRIPT" <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *extra.example.org* ]]
    grep -q '^flake archive' "$NIX_LOG"
    [ "$(grep -c '^eval ' "$NIX_LOG")" -eq 1 ]
}

@test "a bad .claudinix.toml stops before step 0, naming the file and key (V34)" {
    config '[session]' 'model = "haiku"'
    run bash "$SCRIPT" <<<$'y\ny\n'
    [ "$status" -eq 2 ]
    [[ "$output" == *".claudinix.toml"* ]]
    [[ "$output" == *"session.model"* ]]
    [[ "$output" != *"== 0."* ]]
}

# scripts:T114, V37: --rev takes a short SHA; before the first release
# the stop names the newest green main commit to rerun with.

@test "--rev takes a short SHA and passes it on to setup-line.sh (V37)" {
    no_release
    run bash "$SCRIPT" --rev 0123456 --from 3 <<<$'y\ny\n'
    [ "$status" -eq 0 ]
    grep -qx "setup-line 0123456" "$LOG"
    run bash "$SCRIPT" update --rev "${SHA:0:12}" <<<''
    [ "$status" -eq 0 ]
    grep -qx "setup-line ${SHA:0:12}" "$LOG"
}

@test "--rev with a bad value: exit 2 naming the flag and the value (V26)" {
    run bash "$SCRIPT" --rev abc123 </dev/null
    [ "$status" -eq 2 ]
    [[ "$output" == *"--rev"* ]]
    [[ "$output" == *"abc123"* ]]
    run bash "$SCRIPT" --rev main </dev/null
    [ "$status" -eq 2 ]
    [[ "$output" == *"main"* ]]
}

@test "no release yet: names the newest green main commit as the --rev to use (T114)" {
    no_release
    GH_HEAD="$SHA" run bash "$SCRIPT" update <<<''
    [ "$status" -eq 1 ]
    [[ "$output" == *"no release yet"* ]]
    [[ "$output" == *"--rev ${SHA:0:12}"* ]]
    grep -q -- "^gh run list --repo pr0d1r2/claudinix --branch main --workflow ci.yml --status success" "$LOG"
}

@test "no release yet and gh missing or silent: today's message, no hint (T114)" {
    no_release
    GH_BIN="$BATS_TEST_TMPDIR/no-such-gh" run bash "$SCRIPT" update <<<''
    [ "$status" -eq 1 ]
    [[ "$output" == *"--rev SHA"* ]]
    [[ "$output" != *"newest green"* ]]
    GH_RC=1 GH_HEAD="$SHA" run bash "$SCRIPT" update <<<''
    [ "$status" -eq 1 ]
    [[ "$output" != *"${SHA:0:12}"* ]]
    GH_HEAD='not-a-sha' run bash "$SCRIPT" update <<<''
    [ "$status" -eq 1 ]
    [[ "$output" != *"not-a-sha"* ]]
}

# scripts:T116: the environment name defaults to the project's name.

@test "step 3 offers the project name as the environment name and copies it (T116)" {
    run bash "$SCRIPT" --from 3 <<<$'y\ny\n'
    [[ "$output" == *"Environment name (Enter: project)"* ]]
    grep -A1 -x -- '--- clip' "$LOG" | grep -qx project
    run ! grep -qx nix "$LOG"
}

@test "a typed environment name is copied and reused by step 4 (T116)" {
    run bash "$SCRIPT" --from 3 <<<$'y\ny\nmyenv\n\n\n\n\n\n'
    grep -A1 -x -- '--- clip' "$LOG" | grep -qx myenv
    [[ "$output" == *"pick myenv"* ]]
}

@test "the default is the git top's name, not the subdirectory's (T116)" {
    while read -r var; do unset "$var"; done < <(env | sed -n 's/^\(GIT_[A-Z_]*\)=.*/\1/p')
    top="$BATS_TEST_TMPDIR/widget"
    git init -q "$top"
    mkdir -p "$top/sub"
    run bash "$SCRIPT" --from 4 "$top/sub" <<<$'y\ny\n\n'
    [[ "$output" == *"pick widget"* ]]
}

@test "step 4 and the update flow name the default without step 3 (T116)" {
    run bash "$SCRIPT" --from 4 <<<$'y\ny\n\n'
    [[ "$output" == *"pick project"* ]]
    [[ "$output" == *".claude/settings.json"* ]]
    run bash "$SCRIPT" update <<<''
    [[ "$output" == *"Hover over project"* ]]
}
