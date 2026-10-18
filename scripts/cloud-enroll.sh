#!/usr/bin/env bash
# Prepare your checkouts for `just held` and `just all` on other repos: clone
# a missing one, fetch an existing one, and pin the claude.ai cloud
# environment /remote-env picked (SPEC cloud:T174, cloud:V52, cloud:V59,
# .:C29). Only the owner runs this.
#
# The repos are the --repo ones, else those with an open pull request
# labelled L (default h10n-human) that the owner authored in the same repo; a
# pull request from anyone else or from a fork is skipped, naming it. Each
# repo is owner/repo, validated before anything runs. Its checkout is
# $CLAUDINIX_PROJECTS/<repo>: cloned with `gh repo clone` when missing,
# otherwise fetched. A checkout whose origin is another repo is failed and
# left untouched. Nothing from the repo runs: no hook, direnv or nix.
#
# The pin is remote.defaultEnvironmentId from your user settings (what
# /remote-env saved), merged into the checkout's .claude/settings.local.json
# and listed in its .git/info/exclude. No pick, or a checkout already pinned
# to another environment, is `needs-env`; nothing is picked, committed or
# pushed. One y/N answer names the repos unless --yes. Running it again
# changes nothing. No billed session starts.
#
# Usage: cloud-enroll.sh [--repo owner/repo...] [--label L] [--yes] [--dry-run]
# Env:   CLAUDINIX_PROJECTS  dir holding the owner's checkouts, one per repo
#        CLAUDE_SETTINGS     user settings file (default ~/.claude/settings.json)

set -euo pipefail

usage() {
    echo "usage: cloud-enroll.sh [--repo owner/repo...] [--label L] [--yes] [--dry-run]" >&2
    exit 2
}

# shellcheck source=/dev/null # lib/cloud-launch.sh, beside this script
source "$(dirname "${BASH_SOURCE[0]}")/lib/cloud-launch.sh"

label=h10n-human
repos=()
yes=0
dry=0
while [ "$#" -gt 0 ]; do
    case "$1" in
    --label)
        [ "$#" -ge 2 ] || usage
        label="$2"
        shift
        ;;
    --repo)
        [ "$#" -ge 2 ] || usage
        repos+=("$2")
        shift
        ;;
    --yes) yes=1 ;;
    --dry-run) dry=1 ;;
    *) usage ;;
    esac
    shift
done

if [ -z "${CLAUDINIX_PROJECTS:-}" ]; then
    echo "enroll: set CLAUDINIX_PROJECTS to the directory holding your checkouts, one per repo" >&2
    exit 1
fi

# cloud:V59: owner/repo, nothing else, before any gh call.
for repo in ${repos[@]+"${repos[@]}"}; do
    if ! cloud_valid_repo "$repo"; then
        echo "enroll: refused: '$repo' is not owner/repo" >&2
        exit 2
    fi
done

# Case folded: the checkout is $CLAUDINIX_PROJECTS/<repo>, one per name (cloud:V59).
dup_name="$(printf '%s\n' ${repos[@]+"${repos[@]}"} | sed 's|.*/||' | tr '[:upper:]' '[:lower:]' | sort | uniq -d | head -n 1)"
if [ -n "$dup_name" ]; then
    echo "enroll: refused: two repos are named $dup_name; they would share one checkout" >&2
    exit 2
fi

if [ "${#repos[@]}" -eq 0 ]; then
    found_repos="$(cloud_repos_with_label enroll "$label")" || exit 1
    while IFS= read -r repo; do
        [ -z "$repo" ] || repos+=("$repo")
    done <<<"$found_repos"
fi

if [ "${#repos[@]}" -eq 0 ]; then
    echo "enroll: nothing to do -- no repo named and no open pull request labelled $label"
    exit 0
fi

plan="enroll: ${repos[*]} (${#repos[@]} repos): clone or fetch under $CLAUDINIX_PROJECTS and pin the /remote-env environment; it picks, commits and pushes nothing and starts no billed session"
if [ "$dry" = 1 ]; then
    echo "$plan"
    exit 0
fi
if [ "$yes" = 0 ]; then
    cloud_flush_input
    cloud_confirm enroll "$plan. Start? [y/N] " || exit 1
fi

settings="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
pick="$(cloud_pin_env "$settings")"

# enroll_one REPO: print enrolled or needs-env for REPO's checkout; return 1,
# after a reason on stderr, when it cannot be enrolled (the caller reports failed).
enroll_one() {
    local repo="$1" dir file existing exclude
    dir="$(cloud_repo_checkout "$repo")"
    if [ -z "$pick" ]; then
        echo needs-env
        return 0
    fi
    if [ ! -e "$dir" ]; then
        gh repo clone "$repo" "$dir" </dev/null >&2 || return 1
    fi
    cloud_origin_is "$repo" "$dir" || {
        echo "enroll: $repo: origin is $(git -C "$dir" remote get-url origin 2>/dev/null || echo missing), not $repo" >&2
        return 1
    }
    git -C "$dir" fetch origin </dev/null >&2 || return 1

    file="$dir/$CLOUD_PIN_FILE"
    if [ -L "$dir/.claude" ] || [ -L "$file" ]; then
        echo "enroll: $repo: .claude is a symlink; not writing through it" >&2
        return 1
    fi
    if git -C "$dir" ls-files --error-unmatch -- "$CLOUD_PIN_FILE" >/dev/null 2>&1; then
        echo "enroll: $repo: the repo tracks $CLOUD_PIN_FILE; not touching it" >&2
        return 1
    fi
    existing='{}'
    if [ -e "$file" ]; then
        existing="$(jq -e 'if type == "object" then . else error end' "$file" 2>/dev/null)" || {
            echo "enroll: $repo: $CLOUD_PIN_FILE is not a JSON object" >&2
            return 1
        }
    fi
    case "$(cloud_pin_env <(echo "$existing"))" in
    '' | "$pick") ;;
    *)
        echo needs-env
        return 0
        ;;
    esac
    mkdir -p "${file%/*}" || return 1
    cloud_pin_set "$pick" <<<"$existing" >"$file.tmp.$$" || return 1
    mv "$file.tmp.$$" "$file" || return 1

    exclude="$(git -C "$dir" rev-parse --path-format=absolute --git-path info/exclude)" || return 1
    mkdir -p "${exclude%/*}" || return 1
    grep -qxF "/$CLOUD_PIN_FILE" "$exclude" 2>/dev/null ||
        echo "/$CLOUD_PIN_FILE" >>"$exclude" || return 1
    echo enrolled
}

failed=0
for repo in "${repos[@]}"; do
    status="$(enroll_one "$repo")" || status=failed
    [ "$status" != failed ] || failed=1
    cloud_report enroll "$repo" "$status"
done
exit "$failed"
