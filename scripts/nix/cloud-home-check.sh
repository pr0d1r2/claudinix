#!/usr/bin/env bash
# `checks.x86_64-linux.cloud-home`: the agent home's activation package
# carries what a cloud session needs at launch (SPEC nix:T16, nix:V14,
# C12): the cavekit skills, the FORMAT.md they read, and the set rules;
# and the settings.json its activation writes carries exactly the cloud
# permissions in PERMISSIONS (T101). It also carries the rtk pieces
# (nix:T151): the rtk binary, RTK.md and the @RTK.md line in the home
# files, and the rtk Bash hook in settings.json. settings.json is not a
# home file: the claude-code module merges settings into
# ~/.claude/settings.json from a `run-merge-settings.sh` the `activate`
# script calls, so the check
# runs that merge against a scratch HOME and reads what it wrote.
# Every missing file is reported; empty files and dangling links count as
# missing. OUT is created only when nothing is missing.
#
# Usage: cloud-home-check.sh ACTIVATION_PACKAGE PERMISSIONS OUT

set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "usage: cloud-home-check.sh ACTIVATION_PACKAGE PERMISSIONS OUT" >&2
    exit 2
fi

claude="$1/home-files/.claude"
if [ ! -d "$1/home-files" ]; then
    echo "cloud-home-check: $1 has no home-files -- not an activation package, nothing was checked" >&2
    exit 1
fi

status=0
# cavekit v4.1.0, all nine skills, and the caveman skills the owner uses
# (nix:T153); caveman's own `caveman` skill is not one: cavekit owns the name.
for skill in spec build check backprop caveman deepen grill research review \
    caveman-review caveman-help caveman-compress; do
    if [ ! -s "$claude/skills/$skill/SKILL.md" ]; then
        echo "cloud-home-check: missing ~/.claude/skills/$skill/SKILL.md" >&2
        status=1
    fi
done
# caveman-commit tells a session to skip the commit body that the repo's
# `commit-msg` gate requires (nix:V45).
if [ -e "$claude/skills/caveman-commit" ]; then
    echo "cloud-home-check: ~/.claude/skills/caveman-commit competes with the commit-msg gate" >&2
    status=1
fi
if [ ! -s "$claude/FORMAT.md" ]; then
    echo "cloud-home-check: missing ~/.claude/FORMAT.md" >&2
    status=1
fi

# rtk (nix:T151): the binary setup links onto PATH, the RTK.md it reads,
# and the CLAUDE.md line that loads it.
if [ ! -s "$claude/RTK.md" ]; then
    echo "cloud-home-check: missing ~/.claude/RTK.md" >&2
    status=1
fi
if ! grep -qx '@RTK.md' "$claude/CLAUDE.md" 2>/dev/null; then
    echo "cloud-home-check: ~/.claude/CLAUDE.md has no @RTK.md line" >&2
    status=1
fi
if [ ! -x "$1/home-path/bin/rtk" ]; then
    echo "cloud-home-check: missing home-path/bin/rtk -- setup would link no rtk onto PATH" >&2
    status=1
fi

# The set's rules are generated, so their names are not fixed: any
# non-empty markdown file under rules/set proves the set landed.
rules="$(find -L "$claude/rules/set" -name '*.md' -type f -size +0 2>/dev/null || true)"
if [ -z "$rules" ]; then
    echo "cloud-home-check: missing ~/.claude/rules/set/*.md (the set's rules)" >&2
    status=1
fi

# The settings merge the activation runs, by its store name.
merge="$(grep -oE '/[^[:space:]"]*-run-merge-settings\.sh' "$1/activate" 2>/dev/null | head -n 1 || true)"
if [ -z "$merge" ] || [ ! -f "$merge" ]; then
    echo "cloud-home-check: $1/activate runs no settings merge -- ~/.claude/settings.json would carry no permissions" >&2
    status=1
else
    scratch="$(mktemp -d)"
    trap 'rm -rf "$scratch"' EXIT
    if ! HOME="$scratch" bash "$merge" >/dev/null 2>"$scratch/merge.log"; then
        echo "cloud-home-check: the settings merge failed:" >&2
        cat "$scratch/merge.log" >&2
        status=1
    elif ! jq -e --slurpfile want "$2" '.permissions == $want[0]' "$scratch/.claude/settings.json" >/dev/null 2>&1; then
        echo "cloud-home-check: ~/.claude/settings.json permissions are not exactly $2 -- got:" >&2
        jq -c '.permissions' "$scratch/.claude/settings.json" >&2 2>/dev/null || true
        status=1
    fi
    if ! jq -e '[.hooks.PreToolUse[]? | select(.matcher == "Bash") | .hooks[]?.command // "" | test("(^|/)rtk hook claude$")] | any' "$scratch/.claude/settings.json" >/dev/null 2>&1; then
        echo "cloud-home-check: ~/.claude/settings.json has no PreToolUse Bash hook running \`rtk hook claude\`" >&2
        status=1
    fi
    # caveman (nix:T153): each hook runs its script under an absolute node,
    # since a cloud session has no node on PATH, and a statusLine is set,
    # else caveman-activate.js asks the agent to set one up.
    for hook in SessionStart:caveman-activate.js SubagentStart:caveman-activate.js \
        UserPromptSubmit:caveman-mode-tracker.js; do
        event="${hook%%:*}"
        script="${hook#*:}"
        if ! jq -e --arg e "$event" --arg s "$script" '[.hooks[$e][]?.hooks[]?.command // "" | test("^/\\S+/bin/node \\S+/" + $s + "( |$)")] | any' "$scratch/.claude/settings.json" >/dev/null 2>&1; then
            echo "cloud-home-check: ~/.claude/settings.json has no $event hook running $script under an absolute node" >&2
            status=1
        fi
    done
    if ! jq -e '.statusLine.command | type == "string"' "$scratch/.claude/settings.json" >/dev/null 2>&1; then
        echo "cloud-home-check: ~/.claude/settings.json has no statusLine command" >&2
        status=1
    fi
fi

if [ "$status" -eq 0 ]; then
    touch "$3"
fi
exit "$status"
