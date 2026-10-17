#!/usr/bin/env bash
# The one permission list cloud sessions get is narrow (SPEC T101, C29).
#
# nix/cloud-permissions.json is `{"allow": [...], "deny": [...]}`. The
# agent home writes it into ~/.claude/settings.json, and the opt-in
# SessionStart fallback into .claude/settings.local.json; both read this
# file, so this is the one place the rules are judged:
#
#   - no allow rule may cover a whole tool (`Bash`), start with a
#     wildcard (`*`, `Bash(*)`), or allow an environment runner without
#     its inner command (`Bash(nix develop *)`, `Bash(nix-dev *)`): the
#     permissions docs note such a runner rule matches anything after it;
#   - deny keeps every rule that confines a push to one ref (no main, no
#     force, no option after the remote, no second ref);
#   - every git or cargo rule, in allow and in deny, has its `rtk` twin
#     (what the agent home's hook rewrites it to), and every `rtk` rule
#     its bare one;
#   - the committed project settings carry no `permissions`: local
#     sessions read that file, and they must not get these rules.
#
# Every offence is reported. jq missing is a failure, never a pass.
#
# Usage: cloud-permissions.sh
# Env:   PERMISSIONS_FILE (default nix/cloud-permissions.json)
#        SETTINGS_FILE    (default .claude/settings.json)

set -euo pipefail

list="${PERMISSIONS_FILE:-nix/cloud-permissions.json}"
settings="${SETTINGS_FILE:-.claude/settings.json}"

fail() {
    echo "cloud-permissions: $1" >&2
}

if ! command -v jq >/dev/null 2>&1; then
    fail "jq not on PATH -- nothing was checked, which is a failure rather than a pass"
    exit 1
fi

if [ ! -f "$list" ]; then
    fail "$list not found -- nothing was checked"
    exit 1
fi

if ! jq -e '
    type == "object"
    and (.allow | type == "array" and all(type == "string"))
    and (.deny | type == "array" and all(type == "string"))
' "$list" >/dev/null 2>&1; then
    fail "$list must be {\"allow\": [strings], \"deny\": [strings]} -- nothing else was checked"
    exit 1
fi

status=0

blanket="$(jq -r '.allow[] | select(
    test("^[A-Za-z_]+$")
    or test("^\\*")
    or test("^[A-Za-z_]+\\(\\*")
    or test("^Bash\\((nix develop|nix-dev)( -c)? ?(\\*|:\\*)\\)$")
)' "$list")"
while IFS= read -r rule; do
    [ -n "$rule" ] || continue
    fail "$list allows \"$rule\": a blanket rule (whole tool, leading wildcard, or a runner without its inner command) -- name the command instead"
    status=1
done <<<"$blanket"

# Denies the list must keep (its rtk twins are required by the twin check
# below). One array: a rule that must stay denied is added here.
required_denies=(
    'Bash(git push * main)'
    'Bash(git push * main *)'
    'Bash(git push *:main)'
    'Bash(git push *:main *)'
    'Bash(git push *refs/heads/main*)'
    'Bash(git push *--force)'
    'Bash(git push *--force *)'
    'Bash(git push *--delete*)'
    'Bash(git push *--mirror*)'
    'Bash(git push * -f)'
    'Bash(git push -f *)'
    'Bash(git push * -f *)'
    # Every allowed push takes its options before the remote, so any
    # option after it is denied: no glob names every short-flag cluster
    # (home:V49, home:B58).
    'Bash(git push * -*)'
    # An allowed push writes one ref: one refspec after the remote, and a
    # claude/ source names no destination of its own (home:V50, home:B59).
    'Bash(git push origin * *)'
    'Bash(git push * origin * *)'
    'Bash(git push * claude/*:*)'
    # git resolves a partial ref to refs/heads/main (home:V50, home:B60).
    'Bash(git push *:heads/main*)'
    # Only the owner merges, from the owner's terminal (.:C29, cloud:V51).
    # The other PR verbs come from pr_verbs below.
    'Bash(gh api *merge*)'
    'mcp__github__merge_pull_request'
    'mcp__github__enable_pr_auto_merge'
    # update_pull_request closes or edits a PR as `gh pr close | edit` do
    # (home:V58, home:B98).
    'mcp__github__update_pull_request'
    # Any other way to write main: the MCP file writes take a branch, and
    # a ref update moves it (home:V50, home:B75).
    'Bash(gh api *refs/heads/main*)'
    'mcp__github__push_files'
    'mcp__github__create_or_update_file'
    'mcp__github__delete_file'
)
# The PR verbs a cloud session never runs (.:C29, cloud:V51, cloud:V52):
# the owner merges, and a launcher acting on another repo's PR neither
# closes nor edits it. A new verb is one line here; the plain and the
# `gh -R x` forms are derived, and the rtk twins follow from the twin check.
pr_verbs=(merge close edit)
for verb in "${pr_verbs[@]}"; do
    required_denies+=("Bash(gh pr $verb *)" "Bash(gh * pr $verb *)")
done
for rule in "${required_denies[@]}"; do
    if ! jq -e --arg rule "$rule" '.deny | index($rule)' "$list" >/dev/null; then
        fail "$list must deny \"$rule\" -- see the comment above required_denies"
        status=1
    fi
done

# The rtk hook (nix:T151) rewrites git, cargo and gh commands to `rtk <cmd>`,
# so each such rule needs its rtk twin in the same list, and an rtk rule
# its bare one (V44, B45, B53). A deny without its twin lets the rewritten
# command through; an allow without it leaves an unattended task waiting
# on a prompt, since rtk allows a rewrite only on its own match and its
# matcher never accepts `claude/*` (B52, probed against rtk 0.51). Which
# commands rtk really rewrites is checked against the pinned rtk by
# `checks.rtk-twins`; this fast step knows git, cargo and gh.
#
# One jq call lists every rule whose twin is missing from its own list.
missing_twins="$(jq -r '
    . as $list
    | ["allow", "deny"][] as $key
    | $list[$key][]
    | select(test("^Bash\\((rtk )?(git|cargo|gh) "))
    | . as $rule
    | (if startswith("Bash(rtk ") then "Bash(" + .[9:] else "Bash(rtk " + .[5:] end) as $twin
    | select($list[$key] | index($twin) | not)
    | [$key, $rule, $twin] | @tsv
' "$list")"
while IFS=$'\t' read -r key rule want; do
    [ -n "$rule" ] || continue
    fail "$list $key has \"$rule\" but not \"$want\" -- the rtk hook rewrites one into the other, so they must come in pairs"
    status=1
done <<<"$missing_twins"

if [ -f "$settings" ] && jq -e 'has("permissions")' "$settings" >/dev/null 2>&1; then
    fail "$settings carries permissions -- local sessions read it; the cloud rules live in $list only"
    status=1
fi

exit "$status"
