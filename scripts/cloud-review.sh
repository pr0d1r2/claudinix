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

scripts_dir="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"
# shellcheck source=/dev/null # lib/cloud-launch.sh, beside this script
source "$(dirname "${BASH_SOURCE[0]}")/lib/cloud-launch.sh"
remote="${CLOUD_TASK_REMOTE:-origin}"

# The roles: one per file in review/; `all` runs every one of them.
all_roles=()
while IFS= read -r r; do
    all_roles+=("$r")
done < <(cloud_roles "$scripts_dir/review")
if [ "$role" = all ] && [ "${#all_roles[@]}" -eq 0 ]; then
    echo "review: no role files in scripts/review/ -- add one, such as scripts/review/correctness.md" >&2
    exit 2
elif [ "$role" = all ]; then
    selected_roles=("${all_roles[@]}")
elif [[ "$role" =~ ^[a-z][a-z0-9-]*$ ]] && [ -f "$scripts_dir/review/$role.md" ]; then
    selected_roles=("$role")
else
    echo "review: no role $role -- roles: ${all_roles[*]:-none}, or all (each role is a file in scripts/review/)" >&2
    exit 2
fi

pr= # set by cloud_parse_pr
cloud_parse_pr "$arg" || usage

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

cloud_require_remote review "$remote" || exit 1
if [ -n "$url_repo" ]; then
    remote_repo="$(git remote get-url "$remote" | sed -E 's#^.*[:/]([^/]+/[^/]+)$#\1#; s#\.git$##')"
    if [ "$(printf %s "$url_repo" | tr '[:upper:]' '[:lower:]')" != "$(printf %s "$remote_repo" | tr '[:upper:]' '[:lower:]')" ]; then
        echo "review: $arg is a pull request of $url_repo, but remote $remote is $remote_repo -- run it from a checkout of $url_repo" >&2
        exit 1
    fi
fi

cloud_resolve_model "$scripts_dir" || exit "$?"

# build ROLE: $prompt for one role's session.
build() {
    prompt="$(cat "$scripts_dir/cloud-review-prompt.txt")"
    cloud_fill @ROLE_TEXT@ @ROLE_TEXT_SLOT@
    cloud_fill @ROLE@ "$1"
    cloud_fill @PR@ "$pr"
    cloud_fill @BASE@ "$base"
    cloud_fill @BRANCH@ "$head"
    cloud_fill @URL@ "$url"
    cloud_fill @ROLE_TEXT_SLOT@ "$(cat "$scripts_dir/review/$1.md")"
}

if [ "$dry" = 1 ]; then
    for r in "${selected_roles[@]}"; do
        build "$r"
        printf 'claude --cloud %q --model %q\n' "$prompt" "$model"
    done
    exit 0
fi

n="${#selected_roles[@]}"
if [ "$yes" = 0 ]; then
    cloud_flush_input
    if [ "$role" = all ]; then
        question="$(
            printf 'review: this starts %s billed Claude Code cloud sessions at once (model %s), one per role, each reviewing #%s (%s) and posting one comment:\n' "$n" "$model" "$pr" "$head"
            printf '  %s\n' "${selected_roles[@]}"
            printf 'Each session is billed on its own. That is about %s times the cost of one review. Start all %s? [y/N] ' "$n" "$n"
        )"
    else
        question="$(printf 'review: this starts a billed Claude Code cloud session (model %s) for a %s review of #%s (%s). Start it? [y/N] ' "$model" "$role" "$pr" "$head")"
    fi
    cloud_confirm review "$question" || exit 1
fi

# Each launch returns once its session exists, so the sessions are running
# side by side, though they start one after another. A failed launch is
# recorded and the rest still start (B22): the sessions already started
# are billed.
started=()
failed=()
for r in "${selected_roles[@]}"; do
    build "$r"
    if cloud_launch "$prompt" "$model"; then
        started+=("$r")
    else
        failed+=("$r")
    fi
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
