#!/usr/bin/env bash
# Review one pull request as one role in a fresh, read-only cloud
# session, from your terminal (SPEC scripts:T129, .:C29).
#
# ROLE names a file scripts/review/ROLE.md: the directory is the list of
# roles, so a new role is a new file and no code changes. PR is a number
# or a GitHub pull request URL; `gh pr view` must find it open. Any head
# branch will do, since the session pushes nothing.
#
# The launch rules are cloud-task.sh's, less the local branch: the remote
# must exist, and a y/N answer must confirm that a billed cloud session
# starts; --yes skips only that question. The session fetches the pull
# request's branch from GitHub itself, so it does not matter which branch
# is checked out here, pushed or not. --dry-run
# runs the same checks, then prints the exact claude command
# (shell-quoted, pasteable) instead of asking or launching. The model:
# --model, else the project's .claudinix.toml session.model
# (scripts/config.sh, scripts:V34), else sonnet.
#
# The prompt is cloud-review-prompt.txt with @ROLE@, @PR@, @URL@,
# @BRANCH@, @BASE@ and the role file's text (@ROLE_TEXT@) filled in. The
# session posts its findings as one comment on the pull request; it
# commits, pushes and merges nothing. This does not wait for the session;
# follow it at claude.ai/code.
#
# ROLE `all` starts one session per role file, all behind one y/N question
# that names the count, the model, the roles and the billing.
#
# Usage: cloud-review.sh <ROLE | all> <PR# | URL> [--model M] [--yes] [--dry-run]
# Env:   CLOUD_TASK_REMOTE  remote that must hold the branch (default origin)
#        CLAUDINIX_SCRIPTS  dir holding review/, cloud-review-prompt.txt and
#                           config.sh (default: here)

set -euo pipefail

usage() {
    echo "usage: cloud-review.sh <ROLE | all> <PR# | URL> [--model M] [--yes] [--dry-run]" >&2
    exit 2
}

args=()
model=
yes=0
dry=0
while [ "$#" -gt 0 ]; do
    case "$1" in
    --model)
        [ "$#" -ge 2 ] || usage
        model="$2"
        shift
        ;;
    --yes) yes=1 ;;
    --dry-run) dry=1 ;;
    -*) usage ;;
    *) args+=("$1") ;;
    esac
    shift
done
[ "${#args[@]}" -eq 2 ] || usage
role="${args[0]}"
arg="${args[1]}"

lib="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"
remote="${CLOUD_TASK_REMOTE:-origin}"

# The roles: one per file in review/; `all` runs every one of them.
roles=()
for f in "$lib"/review/*.md; do
    [ -f "$f" ] && roles+=("$(basename "$f" .md)")
done
if [ "$role" = all ] && [ "${#roles[@]}" -eq 0 ]; then
    echo "review: no role files in scripts/review/ -- add one, such as scripts/review/correctness.md" >&2
    exit 2
elif [ "$role" = all ]; then
    run=("${roles[@]}")
elif [[ "$role" =~ ^[a-z][a-z0-9-]*$ ]] && [ -f "$lib/review/$role.md" ]; then
    run=("$role")
else
    echo "review: no role $role -- roles: ${roles[*]:-none}, or all (each role is a file in scripts/review/)" >&2
    exit 2
fi

url_repo=
if [[ "$arg" =~ ^[0-9]+$ ]]; then
    pr="$arg"
elif [[ "$arg" =~ ^https://github\.com/([^/]+/[^/]+)/pull/([0-9]+)/?$ ]]; then
    url_repo="${BASH_REMATCH[1]}"
    pr="${BASH_REMATCH[2]}"
else
    usage
fi

# </dev/null: gh must not share the terminal the y/N answer comes from (B19).
if ! info="$(gh pr view "$pr" --json number,state,headRefName,baseRefName,url \
    --jq '[.number, .state, .headRefName, .baseRefName, .url] | @tsv' </dev/null)"; then
    echo "review: gh could not read pull request #$pr -- check the number and that gh is signed in" >&2
    exit 1
fi
IFS="$(printf '\t')" read -r _ state head base url <<<"$info"

if [ "$state" != OPEN ]; then
    echo "review: #$pr is $state, not OPEN -- nothing to review" >&2
    exit 1
fi
# The author picks these names and the prompt pastes them into shell
# commands, so only plain ref characters pass (B20).
for ref in "$head" "$base"; do
    if [[ ! "$ref" =~ ^[A-Za-z0-9._/-]+$ ]]; then
        echo "review: #$pr has the branch name '$ref', which has characters beyond A-Z a-z 0-9 . _ / - -- refusing to put it in a prompt" >&2
        exit 1
    fi
done

if ! git remote get-url "$remote" >/dev/null 2>&1; then
    echo "review: no remote $remote -- push the project to GitHub first" >&2
    exit 1
fi
# A URL names its repository; gh looks only in this checkout's (B21).
if [ -n "$url_repo" ]; then
    remote_repo="$(git remote get-url "$remote" | sed -E 's#^.*[:/]([^/]+/[^/]+)$#\1#; s#\.git$##')"
    if [ "$(printf %s "$url_repo" | tr '[:upper:]' '[:lower:]')" != "$(printf %s "$remote_repo" | tr '[:upper:]' '[:lower:]')" ]; then
        echo "review: $arg is a pull request of $url_repo, but remote $remote is $remote_repo -- run it from a checkout of $url_repo" >&2
        exit 1
    fi
fi

if [ -z "$model" ]; then
    model="$(bash "$lib/config.sh" get session.model)" || exit "$?"
fi

# fill KEY VALUE: replace every KEY in $prompt with VALUE, as written
# (see cloud-task.sh for why not ${prompt//KEY/VALUE}). The role text goes
# in last, so a placeholder spelled inside it is not filled.
fill() {
    local text="$prompt" out=
    while [[ "$text" == *"$1"* ]]; do
        out="$out${text%%"$1"*}$2"
        text="${text#*"$1"}"
    done
    prompt="$out$text"
}
# build ROLE: $prompt for one role's session.
build() {
    prompt="$(cat "$lib/cloud-review-prompt.txt")"
    fill @ROLE_TEXT@ @ROLE_TEXT_SLOT@
    fill @ROLE@ "$1"
    fill @PR@ "$pr"
    fill @BASE@ "$base"
    fill @BRANCH@ "$head"
    fill @URL@ "$url"
    fill @ROLE_TEXT_SLOT@ "$(cat "$lib/review/$1.md")"
}

if [ "$dry" = 1 ]; then
    for r in "${run[@]}"; do
        build "$r"
        printf 'claude --cloud %q --model %q\n' "$prompt" "$model"
    done
    exit 0
fi

n="${#run[@]}"
if [ "$yes" = 0 ]; then
    # Drop what the terminal left in the input buffer, so only the typed
    # answer is read (B19). Whole seconds: macOS /bin/bash 3.2 has no
    # fractional -t.
    if [ -t 0 ]; then
        while IFS= read -r -t 1 _; do :; done
    fi
    if [ "$role" = all ]; then
        printf 'review: this starts %s billed Claude Code cloud sessions at once (model %s), one per role, each reviewing #%s (%s) and posting one comment:\n' "$n" "$model" "$pr" "$head"
        printf '  %s\n' "${run[@]}"
        printf 'Each session is billed on its own. Start all %s? [y/N] ' "$n"
    else
        printf 'review: this starts a billed Claude Code cloud session (model %s) for a %s review of #%s (%s). Start it? [y/N] ' "$model" "$role" "$pr" "$head"
    fi
    answer=
    IFS= read -r answer || true
    case "$answer" in
    y | Y | yes) ;;
    *)
        echo "review: not started" >&2
        exit 1
        ;;
    esac
fi

# util-linux `script` takes the command as a string, BSD `script` as
# arguments; both get a TTY for claude. Each call returns once its
# session exists, so the sessions are running side by side, though they
# start one after another. A failed launch is recorded and the rest
# still start (B22): the sessions already started are billed.
started=()
failed=()
for r in "${run[@]}"; do
    build "$r"
    if script --version >/dev/null 2>&1; then
        # shellcheck disable=SC2016 # script's shell expands these, not this one
        CLOUD_TASK_PROMPT="$prompt" CLOUD_TASK_MODEL="$model" script -q -e \
            -c 'claude --cloud "$CLOUD_TASK_PROMPT" --model "$CLOUD_TASK_MODEL"' /dev/null && ok=1 || ok=0
    else
        script -q /dev/null claude --cloud "$prompt" --model "$model" && ok=1 || ok=0
    fi
    if [ "$ok" = 1 ]; then started+=("$r"); else failed+=("$r"); fi
done

if [ "${#failed[@]}" -gt 0 ]; then
    echo "cloud: failed to start: ${failed[*]}" >&2
fi
if [ "${#started[@]}" -eq 0 ]; then
    exit 1
fi
if [ "$role" = all ]; then
    echo "cloud: started ${#started[@]} review sessions for #$pr ($head): ${started[*]}; each comments on the pull request -- follow them at claude.ai/code"
else
    echo "cloud: started the $role review of #$pr ($head); it comments on the pull request -- follow it at claude.ai/code"
fi
[ "${#failed[@]}" -eq 0 ]
