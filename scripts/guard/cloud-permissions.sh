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

for rule in \
    'Bash(git push * main)' \
    'Bash(git push * main *)' \
    'Bash(git push *:main)' \
    'Bash(git push *:main *)' \
    'Bash(git push *refs/heads/main*)'; do
    # Its rtk twin is required by the twin check below (V44).
    if ! jq -e --arg rule "$rule" '.deny | index($rule)' "$list" >/dev/null; then
        fail "$list must deny \"$rule\" -- an unattended task never pushes main"
        status=1
    fi
done

# The rtk hook (nix:T151) rewrites git and cargo commands to `rtk <cmd>`,
# so each such rule needs its rtk twin in the same list, and an rtk rule
# its bare one (V44, B45, B53). A deny without its twin lets the rewritten
# command through; an allow without it leaves an unattended task waiting
# on a prompt, since rtk allows a rewrite only on its own match and its
# matcher never accepts `claude/*` (B52, probed against rtk 0.51). Which
# commands rtk really rewrites is checked against the pinned rtk by
# `checks.rtk-twins`; this fast step knows git and cargo.
#
# twin RULE: RULE's rtk form, or the bare form of an rtk RULE.
twin() {
    case "$1" in
    'Bash(rtk '*) echo "Bash(${1#Bash(rtk }" ;;
    *) echo "Bash(rtk ${1#Bash(}" ;;
    esac
}
for key in allow deny; do
    while IFS= read -r rule; do
        [ -n "$rule" ] || continue
        want="$(twin "$rule")"
        if ! jq -e --arg key "$key" --arg rule "$want" '.[$key] | index($rule)' "$list" >/dev/null; then
            fail "$list $key has \"$rule\" but not \"$want\" -- the rtk hook rewrites one into the other, so they must come in pairs"
            status=1
        fi
    done < <(jq -r --arg key "$key" '.[$key][] | select(test("^Bash\\((rtk )?(git|cargo) "))' "$list")
done

if [ -f "$settings" ] && jq -e 'has("permissions")' "$settings" >/dev/null 2>&1; then
    fail "$settings carries permissions -- local sessions read it; the cloud rules live in $list only"
    status=1
fi

exit "$status"
