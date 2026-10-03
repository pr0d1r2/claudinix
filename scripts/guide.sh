#!/usr/bin/env bash
# Walk docs/SETUP.md from the terminal (SPEC scripts:T26, I.cmd `guide`,
# C2, .:V10).
#
# The cloud environment can only be made in the browser, so this does
# the rest: for each step it says what to do and where, opens the URL,
# copies the value to paste (env name, allowed domains, setup script) to
# the clipboard, waits for you, and checks locally what it can: the
# claude.ai sign-in, `remote.defaultEnvironmentId`, the github inputs to
# attach. Step 0 (money) always runs and needs an explicit `y` for each
# check. Step titles and URLs come from guide-steps.tsv, which a test
# keeps equal to the SETUP.md headings. No network writes, no secrets.
#
# Usage: guide.sh [--from STEP] [FLAKE_DIR]   steps 0-5 (default dir: .)
#        guide.sh update [FLAKE_DIR]          the "Updating" flow
# Env:   NCCC_SCRIPTS      dir with guide-steps.tsv, inputs.sh, domains.sh
#        NCCC_SETUP        setup.sh to paste (default: beside scripts/)
#        NCCC_MODEL_DOC    MODEL.md with the prices (default: ../docs/)
#        CLAUDE_SETTINGS   user settings (default ~/.claude/settings.json)
#        CLIPBOARD_TOOLS   tried in order (default: pbcopy wl-copy xclip)
#        GUIDE_OPEN_TOOLS  tried in order (default: open xdg-open)

set -euo pipefail

usage() {
    echo "usage: guide.sh [--from STEP] [FLAKE_DIR] | guide.sh update [FLAKE_DIR]" >&2
    exit 2
}

flow=setup
from=0
dir=
while [ "$#" -gt 0 ]; do
    case "$1" in
    update) flow=update ;;
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
dir="${dir:-.}"

lib="${NCCC_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"
setup_file="${NCCC_SETUP:-$lib/../setup.sh}"
model_doc="${NCCC_MODEL_DOC:-$lib/../docs/MODEL.md}"
settings="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
env_name=nix

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
        xclip) "$tool" -selection clipboard <"$1" 2>/dev/null && return 0 ;;
        *) "$tool" <"$1" 2>/dev/null && return 0 ;;
        esac
        return 1
    done
    return 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# paste KIND: say where the value goes, copy it, print it, wait.
paste() {
    local value="$tmp/value"
    case "$1" in
    env-name)
        echo "Name: $env_name"
        echo "$env_name" >"$value"
        ;;
    domains)
        echo "Network access: Custom, with \"Also include default list of common package managers\" checked."
        echo "Allowed domains, one per line:"
        CLIPBOARD_TOOLS=none bash "$lib/domains.sh" "$dir" >"$value"
        ;;
    setup)
        echo "Setup script: select all of the old one (if any) and paste the whole of setup.sh over it."
        cat "$setup_file" >"$value"
        ;;
    esac
    if copy "$value"; then
        echo "(copied to the clipboard)"
        [ "$1" = setup ] || sed 's/^/  /' "$value"
    else
        sed 's/^/  /' "$value"
    fi
    ask "Press Enter when it is pasted."
}

step_0() {
    echo "Do both before any cloud session, a test or probe session included."
    ask "Claimed any cloud credit you were offered (/claim-credit), and the usage page shows it? Type y:"
    [ "$answer" = y ] || stop "claim the credit and check claude.ai/settings/usage, then run the guide again"
    ask "On the same page the usage credits (metered overage) toggle is OFF? Type y:"
    [ "$answer" = y ] || stop "turn usage credits OFF, or sessions past your credit bill your card"
}

step_1() {
    if claude auth status >/dev/null 2>&1; then
        echo "ok: Claude Code is signed in to claude.ai."
    else
        echo "todo: sign in with claude auth login (an API key is not enough for claude --cloud)."
    fi
    if [ -f "$dir/flake.lock" ]; then
        echo "ok: $dir has a flake.lock."
    else
        echo "todo: run nix flake lock in $dir and commit flake.lock."
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
    echo "Environment variables: only the names in env-names.txt; never secrets."
    echo "Then select Create environment."
    echo
    echo "GitHub repositories the flake fetches (a session gets only attached ones):"
    if bash "$lib/inputs.sh" "$dir" >"$tmp/inputs"; then
        if grep -q ' attach$' "$tmp/inputs"; then
            grep ' attach$' "$tmp/inputs" | sed 's/ attach$//; s/^/  attach or cache: /'
        else
            echo "  every github input is in a cache: nothing to attach."
        fi
    else
        echo "  could not check the inputs (see above); run the inputs app later."
    fi
    ask "Press Enter when done."
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
    echo "Pick the session's model. It is fixed at launch: ANTHROPIC_MODEL on the environment does not set it (probe 6)."
    echo "  sonnet  Claude Sonnet 5.5, the default here: $(price 'Claude Sonnet 5.5')."
    echo "  opus    Claude Opus 5.5, for harder work: $(price 'Claude Opus 5.5')."
    ask "Model [sonnet/opus] (Enter: sonnet):"
    local model="${answer:-sonnet}"
    case "$model" in
    sonnet | opus) ;;
    *)
        echo "Not a choice here: using sonnet."
        model=sonnet
        ;;
    esac
    echo "Launch from a checkout of the project, branch pushed (the task comes right after --cloud):"
    echo "  claude --cloud \"<task>\" --model $model"
    echo "First check, it works when the output shows a Nix version and DEVSHELL-OK:"
    echo "  claude --cloud \"Run: nix --version && nix develop -c true && echo DEVSHELL-OK. Report the output.\" --model $model"
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
