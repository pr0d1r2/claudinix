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
#   - deny keeps every rule against pushing main;
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

for rule in \
    'Bash(git push * main)' \
    'Bash(git push * main *)' \
    'Bash(git push *:main)' \
    'Bash(git push *:main *)' \
    'Bash(git push *refs/heads/main*)'; do
    if ! jq -e --arg rule "$rule" '.deny | index($rule)' "$list" >/dev/null; then
        fail "$list must deny \"$rule\" -- an unattended task never pushes main"
        status=1
    fi
done

if [ -f "$settings" ] && jq -e 'has("permissions")' "$settings" >/dev/null 2>&1; then
    fail "$settings carries permissions -- local sessions read it; the cloud rules live in $list only"
    status=1
fi

exit "$status"
