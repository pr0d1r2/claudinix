#!/usr/bin/env bash
# Take the pull requests the owner parked under a label (default
# h10n-human) through the `all` flow, one at a time, from your terminal
# (SPEC cloud:T166, cloud:V52, .:C29). Only the owner runs this.
#
# The pull requests are the open ones labelled L across the owner's
# repositories (--repo narrows them to the named repos), oldest first.
# One is skipped, naming it, when its author is not the owner (cloud:V52),
# when its repository has no checkout at $CLAUDINIX_PROJECTS/<repo>, or when
# that checkout pins no claude.ai cloud environment
# (remote.defaultEnvironmentId in .claude/settings.local.json), or when it
# comes from a fork (cloud:B86).
#
# --max caps how many run. One y/N answer names the pull requests and the
# billed sessions (1 per role and 1 fixup each); --yes skips only that
# question. --dry-run prints the plan instead. Each pull request then runs
# as `cloud-all.sh <PR URL> --yes --model M` from its checkout; the flow
# owns every wait and every CI decision. A pull request whose flow fails is
# named and the next one still runs; the script exits 1 at the end.
#
# It never merges, adds or removes a label, or closes a pull request: the
# hold is the owner's (cloud:V52).
#
# Usage: cloud-held.sh [--label L] [--repo R...] [--max N] [--model M] [--yes] [--dry-run]
# Env:   CLAUDINIX_PROJECTS  dir holding the owner's checkouts, one per repo
#        CLAUDINIX_SCRIPTS   dir holding cloud-all.sh, review/ and config.sh

set -euo pipefail

usage() {
    echo "usage: cloud-held.sh [--label L] [--repo R...] [--max N] [--model M] [--yes] [--dry-run]" >&2
    exit 2
}

# shellcheck source=/dev/null # lib/cloud-launch.sh, beside this script
source "$(dirname "${BASH_SOURCE[0]}")/lib/cloud-launch.sh"

label=h10n-human
repos=()
max=
model=
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
        repos+=("${2##*/}")
        shift
        ;;
    --max)
        [ "$#" -ge 2 ] || usage
        [[ "$2" =~ ^[1-9][0-9]*$ ]] || usage
        max="$2"
        shift
        ;;
    --model)
        [ "$#" -ge 2 ] || usage
        model="$2"
        shift
        ;;
    --yes) yes=1 ;;
    --dry-run) dry=1 ;;
    *) usage ;;
    esac
    shift
done

scripts_dir="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"

if [ -z "${CLAUDINIX_PROJECTS:-}" ]; then
    echo "held: set CLAUDINIX_PROJECTS to the directory holding your checkouts, one per repo" >&2
    exit 1
fi

cloud_resolve_model "$scripts_dir" || exit "$?"
roles=0
while IFS= read -r _; do
    roles=$((roles + 1))
done < <(cloud_roles "$scripts_dir/review")
if [ "$roles" -eq 0 ]; then
    echo "held: no review roles in $scripts_dir/review -- add one (ROLE.md) first" >&2
    exit 1
fi
per_pr="$(cloud_session_count "$roles" pr)"

# </dev/null: gh must not share the terminal the y/N answer comes from (cloud:B19).
owner="$(gh api user --jq .login </dev/null)" || exit 1
found="$(gh search prs --owner "$owner" --label "$label" --state open --sort created --order asc --limit 100 \
    --json number,createdAt,url,repository,author </dev/null)" || exit 1

only_repos="$(jq -cn '$ARGS.positional' --args ${repos[@]+"${repos[@]}"})"
rows="$(jq -c --argjson only "$only_repos" \
    'sort_by(.createdAt) | .[] | select(($only | length) == 0 or (.repository.name | IN($only[])))' <<<"$found")"

picked=()
while IFS= read -r row; do
    [ -n "$row" ] || continue
    name="$(jq -r '"\(.repository.nameWithOwner)#\(.number)"' <<<"$row")"
    author="$(jq -r .author.login <<<"$row")"
    repo="$(jq -r .repository.name <<<"$row")"
    checkout="$CLAUDINIX_PROJECTS/$repo"
    settings="$checkout/.claude/settings.local.json"
    if [ "$author" != "$owner" ]; then
        echo "held: skip $name: its author is $author, not $owner" >&2
    elif [ ! -d "$checkout" ]; then
        echo "held: skip $name: no checkout at $checkout" >&2
    elif [ -z "$(jq -r '.remote.defaultEnvironmentId // empty' "$settings" 2>/dev/null)" ]; then
        echo "held: skip $name: no claude.ai environment pinned in $settings" >&2
    elif [ "$(gh pr view "$(jq -r .url <<<"$row")" --json isCrossRepository --jq .isCrossRepository </dev/null)" = true ]; then
        echo "held: skip $name: it comes from a fork" >&2
    else
        picked+=("$name"$'\t'"$checkout"$'\t'"$(jq -r .url <<<"$row")")
    fi
done <<<"$rows"

if [ -n "$max" ]; then
    picked=("${picked[@]:0:max}")
fi
total="${#picked[@]}"
if [ "$total" -eq 0 ]; then
    echo "held: nothing to do -- no open pull request of $owner labelled $label that can run"
    exit 0
fi

names="$(printf '%s\n' "${picked[@]}" | cut -f1 | paste -sd' ' -)"
plan="held: $names ($total pull requests labelled $label): the all flow on each (review all, fixup, wait for green CI), $((total * per_pr)) billed Claude Code cloud sessions (model $model), one pull request at a time; it merges nothing and keeps every label"
if [ "$dry" = 1 ]; then
    echo "$plan"
    exit 0
fi
if [ "$yes" = 0 ]; then
    cloud_flush_input
    cloud_confirm held "$plan. Start? [y/N] " || exit 1
fi

done_count=0
for entry in "${picked[@]}"; do
    IFS=$'\t' read -r name checkout url <<<"$entry"
    if (cd "$checkout" && "$scripts_dir/cloud-all.sh" "$url" --yes --model "$model"); then
        done_count=$((done_count + 1))
    else
        echo "held: $name failed (see the flow's last line above); going on" >&2
    fi
done
echo "held: done, $done_count of $total"
[ "$done_count" -eq "$total" ]
