#!/usr/bin/env bash
# The launch rules cloud-task.sh, cloud-rebase.sh and cloud-review.sh
# share (SPEC scripts:I.cmd, scripts:B19). Source it; it defines functions
# only. Every function takes the caller's LABEL first ("cloud", "rebase",
# "review"), which prefixes its messages.

set -euo pipefail

# cloud_fill KEY VALUE: replace every KEY in $prompt with VALUE, as written.
# Not ${prompt//KEY/VALUE}: bash 5.2 turns an `&` in VALUE into the match
# (patsub_replacement), and quoting VALUE there keeps the quotes in bash
# 3.2 (macOS /bin/bash). Fill the text that may spell a placeholder last,
# so that placeholder is not filled.
cloud_fill() {
    local text="$prompt" out=
    while [[ "$text" == *"$1"* ]]; do
        out="$out${text%%"$1"*}$2"
        text="${text#*"$1"}"
    done
    prompt="$out$text"
}

# cloud_require_remote LABEL REMOTE: the project must be on GitHub.
cloud_require_remote() {
    if ! git remote get-url "$2" >/dev/null 2>&1; then
        echo "$1: no remote $2 -- push the project to GitHub first" >&2
        return 1
    fi
}

# cloud_require_pushed_branch LABEL REMOTE: the session clones GitHub, so
# the branch must be there as it is here. Sets $current to its name.
cloud_require_pushed_branch() {
    local upstream
    if ! current="$(git symbolic-ref --quiet --short HEAD)"; then
        echo "$1: HEAD is detached -- check out the branch the session should clone" >&2
        return 1
    fi
    if ! upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
        echo "$1: branch $current is not pushed (no upstream) -- push it first: git push -u $2 $current" >&2
        return 1
    fi
    if [ "$(git rev-parse HEAD)" != "$(git rev-parse '@{u}')" ]; then
        echo "$1: branch $current is not up to date with $upstream -- push (or pull) first" >&2
        return 1
    fi
}

# cloud_resolve_model SCRIPTS_DIR: keep $model when --model gave one, else
# the project's .claudinix.toml session.model, else sonnet (scripts:V34).
cloud_resolve_model() {
    if [ -z "$model" ]; then
        model="$(bash "$1/config.sh" get session.model)" || return "$?"
    fi
}

# cloud_flush_input: drop what the terminal left in the input buffer, such
# as a reply to a query gh sent it, so only the typed answer is read (B19).
# Whole seconds: macOS /bin/bash 3.2 has no fractional -t.
cloud_flush_input() {
    if [ -t 0 ]; then
        while IFS= read -r -t 1 _; do :; done
    fi
}

# cloud_confirm LABEL QUESTION: ask the billed-session question; only y,
# Y or yes starts it. Returns 1 otherwise.
cloud_confirm() {
    local answer=
    printf '%s' "$2"
    IFS= read -r answer || true
    case "$answer" in
    y | Y | yes) ;;
    *)
        echo "$1: not started" >&2
        return 1
        ;;
    esac
}

# cloud_launch PROMPT MODEL: start the cloud session; returns claude's
# status. util-linux `script` takes the command as a string, BSD `script`
# as arguments; both give claude a TTY. The string reads the prompt from
# the environment, so no quoting of it is needed.
cloud_launch() {
    if script --version >/dev/null 2>&1; then
        # shellcheck disable=SC2016 # script's shell expands these, not this one
        CLOUD_TASK_PROMPT="$1" CLOUD_TASK_MODEL="$2" script -q -e \
            -c 'claude --cloud "$CLOUD_TASK_PROMPT" --model "$CLOUD_TASK_MODEL"' /dev/null
    else
        script -q /dev/null claude --cloud "$1" --model "$2"
    fi
}
