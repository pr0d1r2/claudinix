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
repo_re='^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$'
for repo in ${repos[@]+"${repos[@]}"}; do
    if [[ ! "$repo" =~ $repo_re ]] || [[ "$repo" == */. || "$repo" == */.. ]]; then
        echo "enroll: refused: '$repo' is not owner/repo" >&2
        exit 2
    fi
done

# repos_with_open_pr: owner/repo of the owner's own same-repo PRs under the label.
repos_with_open_pr() {
    local owner found rows name author url repo is_fork
    # </dev/null: gh must not share the terminal the y/N answer comes from (cloud:B19).
    owner="$(gh api user --jq .login </dev/null)" || return 1
    found="$(gh search prs --owner "$owner" --label "$label" --state open --limit 100 \
        --json number,url,repository,author </dev/null)" || return 1
    rows="$(jq -r 'sort_by(.url) | .[] | ["\(.repository.nameWithOwner)#\(.number)", (.author.login // "ghost"), .repository.nameWithOwner, .url] | @tsv' <<<"$found")"
    while IFS=$'\t' read -r name author repo url; do
        [ -n "$name" ] || continue
        if [ "$author" != "$owner" ]; then
            echo "enroll: skip $name: its author is $author, not $owner" >&2
        elif ! is_fork="$(gh pr view "$url" --json isCrossRepository --jq .isCrossRepository </dev/null)"; then
            echo "enroll: skip $name: cannot tell whether it comes from a fork" >&2
        elif [ "$is_fork" != false ]; then
            echo "enroll: skip $name: it comes from a fork" >&2
        else
            echo "$repo"
        fi
    done <<<"$rows" | awk '!seen[$0]++'
}

if [ "${#repos[@]}" -eq 0 ]; then
    found_repos="$(repos_with_open_pr)" || exit 1
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
pick=
[ ! -f "$settings" ] || pick="$(jq -r '.remote.defaultEnvironmentId // empty' "$settings" 2>/dev/null || true)"

# origin_is REPO DIR: DIR's origin is github.com/REPO, case folded (cloud:V59).
origin_is() {
    local url
    url="$(git -C "$2" remote get-url origin 2>/dev/null)" || return 1
    url="${url%.git}"
    url="$(tr '[:upper:]' '[:lower:]' <<<"$url")"
    case "$url" in
    "https://github.com/$(tr '[:upper:]' '[:lower:]' <<<"$1")" | "git@github.com:$(tr '[:upper:]' '[:lower:]' <<<"$1")") ;;
    *) return 1 ;;
    esac
}

# enroll_one REPO: print the status word for REPO's checkout.
enroll_one() {
    local repo="$1" dir="$CLAUDINIX_PROJECTS/${1#*/}" file existing exclude
    if [ ! -e "$dir" ]; then
        gh repo clone "$repo" "$dir" </dev/null >&2 || {
            echo failed
            return 0
        }
    fi
    origin_is "$repo" "$dir" || {
        echo failed
        return 0
    }
    git -C "$dir" fetch origin </dev/null >&2 || {
        echo failed
        return 0
    }
    [ -n "$pick" ] || {
        echo needs-env
        return 0
    }

    file="$dir/.claude/settings.local.json"
    existing='{}'
    if [ -e "$file" ]; then
        existing="$(jq -e 'if type == "object" then . else error end' "$file" 2>/dev/null)" || {
            echo failed
            return 0
        }
    fi
    case "$(jq -r '.remote.defaultEnvironmentId // empty' <<<"$existing")" in
    '' | "$pick") ;;
    *)
        echo needs-env
        return 0
        ;;
    esac
    mkdir -p "${file%/*}"
    if ! { jq --arg id "$pick" '.remote = ((.remote // {}) | .defaultEnvironmentId = $id)' <<<"$existing" >"$file.tmp.$$" && mv "$file.tmp.$$" "$file"; }; then
        echo failed
        return 0
    fi

    exclude="$(git -C "$dir" rev-parse --path-format=absolute --git-path info/exclude)"
    mkdir -p "${exclude%/*}"
    grep -qxF '/.claude/settings.local.json' "$exclude" 2>/dev/null ||
        echo '/.claude/settings.local.json' >>"$exclude"
    echo enrolled
}

failed=0
for repo in "${repos[@]}"; do
    status="$(enroll_one "$repo")"
    [ "$status" != failed ] || failed=1
    echo "enroll: report: $repo $status"
done
exit "$failed"
