#!/usr/bin/env bash
# `checks.x86_64-linux.cloud-home`: the agent home's activation package
# carries what a cloud session needs at launch (SPEC nix:T16, nix:V14,
# C12): the cavekit skills, the FORMAT.md they read, and the set rules.
# Every missing file is reported; empty files and dangling links count as
# missing. OUT is created only when nothing is missing.
#
# Usage: cloud-home-check.sh ACTIVATION_PACKAGE OUT

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: cloud-home-check.sh ACTIVATION_PACKAGE OUT" >&2
    exit 2
fi

claude="$1/home-files/.claude"
if [ ! -d "$1/home-files" ]; then
    echo "cloud-home-check: $1 has no home-files -- not an activation package, nothing was checked" >&2
    exit 1
fi

status=0
for file in \
    skills/spec/SKILL.md \
    skills/build/SKILL.md \
    skills/check/SKILL.md \
    skills/backprop/SKILL.md \
    skills/caveman/SKILL.md \
    FORMAT.md; do
    if [ ! -s "$claude/$file" ]; then
        echo "cloud-home-check: missing ~/.claude/$file" >&2
        status=1
    fi
done

# The set's rules are generated, so their names are not fixed: any
# non-empty markdown file under rules/set proves the set landed.
rules="$(find -L "$claude/rules/set" -name '*.md' -type f -size +0 2>/dev/null || true)"
if [ -z "$rules" ]; then
    echo "cloud-home-check: missing ~/.claude/rules/set/*.md (the set's rules)" >&2
    status=1
fi

if [ "$status" -eq 0 ]; then
    touch "$2"
fi
exit "$status"
