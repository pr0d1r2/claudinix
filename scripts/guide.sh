#!/usr/bin/env bash
# Walk docs/SETUP.md from the terminal (SPEC scripts:T26, I.cmd `guide`,
# C2, .:V10).
#
# The cloud environment can only be made in the browser, so this does
# the rest: for each step it says what to do and where, opens the URL,
# copies the value to paste (env name, allowed domains, the one-line
# setup script from setup-line.sh) to the clipboard, waits for you, and
# checks locally what it can: the claude.ai sign-in,
# `remote.defaultEnvironmentId`, and, before the launch in step 5, the
# github inputs no cache holds with the remedy (T81). Step 0 (money)
# always runs and needs an explicit answer for each check (`y`, or `none`
# for a credit never offered). Paths are printed absolute. Step titles and URLs come from guide-steps.tsv, which a test
# keeps equal to the SETUP.md headings. No network writes, no secrets.
#
# The setup line is the one the release published in the README block
# (.:C25): no gh, no clone. Before the first release the guide says so
# and stops, naming the newest green main commit when gh can tell (T114).
# --rev SHA (else CLAUDINIX_SETUP_REV, the maintainer path; a short SHA
# too, V37) prints a line for that SHA with setup-line.sh instead, which
# refuses a SHA whose CI on main is not green unless --force is given
# (T69).
# --agent-home asks the setup line for the opt-in agent home (.:C24).
#
# The project's .claudinix.toml (scripts:T91, read by config.sh) sets
# the defaults: session.model for step 5's answer, session.agent_home
# for --agent-home (--no-agent-home turns it off), devshell.installable
# for the first check's nix-dev. Flags and answers win (scripts:V34); a
# bad file stops the guide before step 0 with exit 2.
#
# Usage: guide.sh [--force] [--[no-]agent-home] [--rev SHA] [--from STEP] [FLAKE_DIR]
#                 steps 0-5 (dir: .)
#        guide.sh update [--force] [--[no-]agent-home] [--rev SHA] [FLAKE_DIR]
#                 the "Updating" flow
# Env:   CLAUDINIX_SCRIPTS    dir with guide-steps.tsv, inputs.sh, domains.sh,
#                             setup-line.sh
#        CLAUDINIX_README     README.md with the release's setup-line block
#                             (default: beside the scripts dir)
#        CLAUDINIX_SETUP_REV  full SHA of this repo to pin the setup line to
#                             with setup-line.sh; --rev wins over it
#        CLAUDINIX_MODEL_DOC  MODEL.md with the prices (default: ../docs/)
#        CLAUDINIX_ENV_NAMES  env-names.txt to list (default: beside scripts/)
#        CLAUDE_SETTINGS      user settings (default ~/.claude/settings.json)
#        CLIPBOARD_TOOLS      tried in order (default: pbcopy wl-copy xclip)
#        GUIDE_OPEN_TOOLS  tried in order (default: open xdg-open)
#        GH_BIN               the GitHub CLI for the pre-release hint (default: gh)

set -euo pipefail

usage() {
    echo "usage: guide.sh [--force] [--[no-]agent-home] [--rev SHA] [--from STEP] [FLAKE_DIR] | guide.sh update [--force] [--[no-]agent-home] [--rev SHA] [FLAKE_DIR]" >&2
    exit 2
}

flow=setup
from=0
dir=
force=()
agent_home_flag=
rev="${CLAUDINIX_SETUP_REV:-}"
while [ "$#" -gt 0 ]; do
    case "$1" in
    update) flow=update ;;
    --force) force=(--force) ;;
    --agent-home) agent_home_flag=true ;;
    --no-agent-home) agent_home_flag=false ;;
    --rev)
        [ "$#" -ge 2 ] || usage
        # A short SHA too; setup-line.sh resolves it on GitHub (V37).
        if ! [[ "$2" =~ ^[0-9a-f]{7,40}$ ]]; then
            echo "guide: --rev wants a claudinix commit SHA (7 to 40 hex characters), got $2" >&2
            exit 2
        fi
        rev="$2"
        shift
        ;;
    --from)
        [ "$#" -ge 2 ] || usage
        from="$2"
        shift
        ;;
    -*) usage ;;
    *)
        [ -z "$dir" ] || usage
        dir="$1"
        ;;
    esac
    shift
done
case "$from" in
[0-5]) ;;
*) usage ;;
esac
given="${dir:-.}"
dir="$given"
# Messages name the project absolute (T81); the tools get it as given.
if ! abs="$(cd "$given" 2>/dev/null && pwd)"; then
    echo "guide: no directory $given -- nothing was checked" >&2
    exit 1
fi

lib="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"

# The project's .claudinix.toml, read once (scripts:T91, V34): flag >
# file > default. config.sh names a bad file and exits 2.
config="$(bash "$lib/config.sh" --dir "$given" json)" || exit "$?"
IFS="$(printf '\t')" read -r default_model file_agent_home installable < <(
    jq -r '[.session.model, .session.agent_home, .devshell.installable] | @tsv' <<<"$config"
)
# domains and inputs take it from here, not from the file (scripts:T96).
export CLAUDINIX_CONFIG_JSON="$config"
agent_home=()
if [ "${agent_home_flag:-$file_agent_home}" = true ]; then
    agent_home=(--agent-home)
fi
# `.` is a bare nix-dev, as the check has always been written. The
# installable is quoted twice (scripts:T95): `printf %q` for the
# session's shell, then `\ $ `` "` escaped for the double quotes the
# terminal's shell reads the task in. `.#ci` prints as it is.
dev_shell="nix-dev -c true"
if [ "$installable" != . ]; then
    quoted="$(printf '%q' "$installable")"
    quoted="${quoted//\\/\\\\}"
    quoted="${quoted//\$/\\\$}"
    quoted="${quoted//\`/\\\`}"
    quoted="${quoted//\"/\\\"}"
    dev_shell="nix-dev $quoted -c true"
fi

readme="${CLAUDINIX_README:-$lib/../README.md}"
model_doc="${CLAUDINIX_MODEL_DOC:-$lib/../docs/MODEL.md}"
env_names="${CLAUDINIX_ENV_NAMES:-$lib/../env-names.txt}"
settings="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
gh="${GH_BIN:-gh}"
# The environment is named after the project by default (T116): the git
# top of the project, else the directory itself; step 3 may change it.
env_name="$(basename "$(git -C "$abs" rev-parse --show-toplevel 2>/dev/null || echo "$abs")")"

answer=
# ask PROMPT: one line of stdin into $answer; end of input is "".
ask() {
    printf '%s ' "$1"
    answer=
    IFS= read -r answer || true
    echo
}

stop() {
    echo "guide: stop here -- $*" >&2
    exit 1
}

open_url() {
    local tool
    echo "Open: $1"
    for tool in ${GUIDE_OPEN_TOOLS:-open xdg-open}; do
        if command -v "$tool" >/dev/null 2>&1; then
            "$tool" "$1" >/dev/null 2>&1 || true
            return 0
        fi
    done
}

# copy FILE: true when a clipboard tool took FILE's content.
copy() {
    local tool
    for tool in ${CLIPBOARD_TOOLS:-pbcopy wl-copy xclip}; do
        command -v "$tool" >/dev/null 2>&1 || continue
        case "${tool##*/}" in
        xclip) "$tool" -selection clipboard <"$1" >/dev/null 2>&1 && return 0 ;;
        *) "$tool" <"$1" >/dev/null 2>&1 && return 0 ;;
        esac
        return 1
    done
    return 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# setup_line: the one-line UI setup script (V20). With --rev (or
# CLAUDINIX_SETUP_REV) setup-line.sh prints it for that SHA, and the
# guide stops when it refuses (T69). Otherwise it is the line the release
# published in the README block (.:C25), + --agent-home as setup-line.sh
# appends it; the guide stops when there is no release yet or no block.
setup_line() {
    local line
    if [ -n "$rev" ]; then
        bash "$lib/setup-line.sh" ${force[@]+"${force[@]}"} ${agent_home[@]+"${agent_home[@]}"} "$rev" ||
            stop "no setup line for $rev (see above); pick a SHA CI passed, or run the guide with --force"
        return 0
    fi
    if [ ! -f "$readme" ]; then
        stop "no README at $readme to copy the release's setup line from; copy the line from https://github.com/pr0d1r2/claudinix#readme, or pass --rev SHA (a claudinix commit CI passed; needs gh signed in)"
    fi
    # The line inside the ```sh fence of the setup-line block.
    line="$(awk '
        $0 == "<!-- END setup-line -->" { inblock = 0 }
        inblock && fence && $0 == "```" { exit }
        inblock && fence { print; exit }
        inblock && $0 == "```sh" { fence = 1 }
        $0 == "<!-- BEGIN setup-line -->" { inblock = 1 }
    ' "$readme")"
    if [ -n "$line" ]; then
        printf '%s%s\n' "$line" "${agent_home[@]+ ${agent_home[*]}}"
        return 0
    fi
    if grep -q '^No release yet' "$readme"; then
        local green
        green="$(green_main)"
        if [ -n "$green" ]; then
            stop "no release yet, so there is no published setup line to copy. The newest green main commit is $green: run the guide again with --rev $green (needs gh signed in), or wait for the first release"
        fi
        stop "no release yet, so there is no published setup line to copy. Run the guide again after the first release, or pass --rev SHA (a claudinix commit CI passed; needs gh signed in) to print a line for that commit"
    fi
    stop "no setup line in the setup-line block of $readme; copy the line from https://github.com/pr0d1r2/claudinix#readme, or pass --rev SHA (a claudinix commit CI passed; needs gh signed in)"
}

# green_main: the newest main commit whose CI passed, short, as the
# --rev to rerun with before the first release (T114). Read-only; prints
# nothing when gh is missing, fails or answers something else.
green_main() {
    local sha
    command -v "$gh" >/dev/null 2>&1 || return 0
    sha="$("$gh" run list --repo pr0d1r2/claudinix --branch main --workflow ci.yml \
        --status success --limit 1 --json headSha --jq '.[0].headSha // empty' 2>/dev/null)" || return 0
    if [[ "$sha" =~ ^[0-9a-f]{40}$ ]]; then
        printf '%s' "${sha:0:12}"
    fi
}

# paste KIND: say where the value goes, copy it, print it, wait.
paste() {
    local value="$tmp/value"
    case "$1" in
    env-name)
        ask "Environment name (Enter: $env_name):"
        env_name="${answer:-$env_name}"
        echo "Name: $env_name"
        echo "$env_name" >"$value"
        ;;
    domains)
        echo "Network access: Custom, with \"Also include default list of common package managers\" checked."
        echo "Allowed domains, one per line:"
        CLIPBOARD_TOOLS=none bash "$lib/domains.sh" "$dir" >"$value"
        ;;
    setup)
        echo "Setup script: select all of the old one (if any) and paste this one line over it."
        setup_line >"$value"
        ;;
    esac
    if copy "$value"; then
        echo "(copied to the clipboard)"
        sed 's/^/  /' "$value"
    else
        sed 's/^/  /' "$value"
    fi
    ask "Press Enter when it is pasted."
}

# env_vars: each variable line of env-names.txt, marked when the comment
# block right above it starts with "# Optional" (T48).
env_vars() {
    local line optional=0
    if [ ! -f "$env_names" ]; then
        echo "Environment variables: the lines of env-names.txt in this repository; never secrets."
        return 0
    fi
    echo "Environment variables, one per line (never secrets):"
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
        '# Optional'*) optional=1 ;;
        '#'*) ;;
        '') optional=0 ;;
        *)
            if [ "$optional" = 1 ]; then
                echo "  $line   (optional)"
            else
                echo "  $line"
            fi
            optional=0
            ;;
        esac
    done <"$env_names"
}

step_0() {
    echo "Do both before any cloud session, a test or probe session included."
    ask "Claimed any cloud credit you were offered (/claim-credit), and the usage page shows it? Type y, or none if you were offered none:"
    case "$answer" in
    y | none) ;;
    *) stop "claim the credit and check claude.ai/settings/usage (or answer none if you had none), then run the guide again" ;;
    esac
    ask "On the same page the usage credits (metered overage) toggle is OFF? Type y:"
    [ "$answer" = y ] || stop "turn usage credits OFF, or sessions past your credit bill your card"
}

step_1() {
    if claude auth status >/dev/null 2>&1; then
        echo "ok: Claude Code is signed in to claude.ai."
    else
        echo "todo: sign in with claude auth login (an API key is not enough for claude --cloud)."
    fi
    if [ -f "$abs/flake.lock" ]; then
        echo "ok: $abs has a flake.lock."
    else
        echo "todo: run nix flake lock in $abs and commit flake.lock."
    fi
    echo "Also: the project is on GitHub and your branch is pushed (a session clones GitHub, not your disk)."
    ask "Press Enter when done."
}

step_2() {
    echo "Install the Claude GitHub App with \"Only select repositories\", listing only the ones sessions may change."
    echo "Check: your repository shows in the repository picker at claude.ai/code."
    ask "Press Enter when done."
}

step_3() {
    echo "On the start page of claude.ai/code (not inside a session), select the cloud icon above the message box,"
    echo "then Cloud, then Add cloud environment, and fill in the dialog:"
    local kind
    for kind in ${1//,/ }; do
        paste "$kind"
    done
    env_vars
    echo "Then select Create environment."
    ask "Press Enter when done."
}

# uncached_inputs: before the launch, the github inputs no cache holds
# and what to do about them (T81).
uncached_inputs() {
    echo "Before you launch: GitHub inputs no cache holds (a session must fetch them from GitHub):"
    if ! bash "$lib/inputs.sh" "$dir" >"$tmp/inputs" 2>"$tmp/inputs.err"; then
        sed 's/^/  /' "$tmp/inputs.err"
        echo "  could not check the inputs; run the inputs app in $abs later."
    elif grep -q ' uncached$' "$tmp/inputs"; then
        grep ' uncached$' "$tmp/inputs" | sed 's/ [^ ]* uncached$//; s/^/  /'
        echo "  nix-dev fetches these over git, so start the dev shell with nix-dev;"
        echo "  or rewrite each as git+https://github.com/<owner>/<repo> in flake.nix."
    else
        echo "  every github input is in a cache: nothing comes from GitHub."
    fi
}

step_4() {
    echo "Run /remote-env in Claude Code and pick $env_name."
    local id=
    if [ -f "$settings" ] && command -v jq >/dev/null 2>&1; then
        id="$(jq -r '.remote.defaultEnvironmentId // empty' "$settings" 2>/dev/null || true)"
    fi
    if [ -n "$id" ]; then
        echo "ok: remote.defaultEnvironmentId = $id (check it is $env_name)."
    else
        echo "todo: remote.defaultEnvironmentId is not set in $settings: run /remote-env."
    fi
    echo "/remote-env sets it for every project. To keep $env_name for this one only, copy that env_... id"
    echo "into remote.defaultEnvironmentId in $abs/.claude/settings.json and commit it."
    ask "Press Enter when done."
}

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    printf '%s' "${s%"${s##*[![:space:]]}"}"
}

# price MODEL: its input and output price per million tokens, read from
# the price table in MODEL.md (never a number of our own), or a pointer
# to MODEL.md when the file, the row or a dollar amount is missing.
price() {
    local line input output
    local -a cells
    if [ -f "$model_doc" ]; then
        while IFS= read -r line; do
            IFS='|' read -r -a cells <<<"$line"
            [ "${#cells[@]}" -ge 4 ] && [ "$(trim "${cells[1]}")" = "$1" ] || continue
            input="$(trim "${cells[2]}")"
            output="$(trim "${cells[3]}")"
            if [[ "$input" =~ ^\$[0-9]+(\.[0-9]+)?$ ]] && [[ "$output" =~ ^\$[0-9]+(\.[0-9]+)?$ ]]; then
                echo "$input input, $output output per million tokens (docs/MODEL.md)"
                return 0
            fi
            break
        done <"$model_doc"
    fi
    echo "price: see docs/MODEL.md"
}

step_5() {
    echo "Pick the session's model. It is fixed at launch: ANTHROPIC_MODEL on the environment does not set it (measured, see docs/FACTS.md)."
    echo "  sonnet  Claude Sonnet 5.5, for everyday work: $(price 'Claude Sonnet 5.5')."
    echo "  opus    Claude Opus 5.5, for harder work: $(price 'Claude Opus 5.5')."
    # The project's session.model is the default (scripts:T91).
    ask "Model [sonnet/opus] (Enter: $default_model):"
    local model="${answer:-$default_model}"
    case "$model" in
    sonnet | opus) ;;
    *)
        echo "Not a choice here: using $default_model."
        model="$default_model"
        ;;
    esac
    uncached_inputs
    echo "Launch from a checkout of the project ($abs), branch pushed (the task comes right after --cloud):"
    echo "  claude --cloud \"<task>\" --model $model"
    echo "First check, it works when the output shows a Nix version and DEVSHELL-OK:"
    echo "  claude --cloud \"Run: nix --version && $dev_shell && echo DEVSHELL-OK. Report the output.\" --model $model"
    echo "In the browser, use the model picker when you start the session instead."
    echo "Which model ran: the Co-Authored-By trailer of the session's commits."
}

step_update() {
    echo "1. On the start page of claude.ai/code (not inside a session), select the cloud icon above the message box, then Cloud."
    echo "2. Hover over $env_name and select the gear icon."
    echo "3. Change only what the commit changed:"
    local kind
    for kind in ${1//,/ }; do
        paste "$kind"
    done
    echo "4. Save, then check the change in a new session: a running session keeps its old VM."
}

# fd 3, so the steps still read answers from stdin.
while IFS="$(printf '\t')" read -r id title url pastes <&3; do
    case "$id" in
    '' | '#'*) continue ;;
    update) [ "$flow" = update ] || continue ;;
    *)
        [ "$flow" = setup ] || continue
        [ "$id" = 0 ] || [ "$id" -ge "$from" ] || continue
        ;;
    esac
    echo
    if [ "$id" = update ]; then
        echo "== $title =="
    else
        echo "== $id. $title =="
    fi
    [ "$url" = - ] || open_url "$url"
    "step_$id" "$pastes"
done 3<"$lib/guide-steps.tsv"
