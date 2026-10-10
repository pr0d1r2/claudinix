#!/usr/bin/env bash
# A cavekit skill under the name `ck-<name>` (SPEC nix:T154, nix:V47).
# Plugins are not installed in the cloud, so the `ck:` namespace a plugin
# gives cavekit's skills is lost; naming them `ck-<name>` keeps them
# apart from caveman's own skills, whose `caveman` then ships bare.
# Copies the skill directory SRC to OUT, sets its frontmatter
# `name: NAME` to `name: ck-NAME`, and rewrites each reference to a
# cavekit verb in every markdown file to `/ck-<verb>` (ck-refs.sh).
#
# VERB... are the cavekit skills the home ships (nix/cloud-skills.nix); a
# reference to any other word, or to a skill that is switched off, is left
# as it is (nix:B50).
#
# Usage: ck-skill.sh SRC NAME OUT VERB...

set -euo pipefail

if [ "$#" -lt 4 ]; then
    echo "usage: ck-skill.sh SRC NAME OUT VERB..." >&2
    exit 2
fi

src="$1"
name="$2"
out="$3"
shift 3
if [ ! -f "$src/SKILL.md" ]; then
    echo "ck-skill: $src has no SKILL.md" >&2
    exit 1
fi
declared="$(awk '/^---$/ { n++; next } n == 1 && /^name: / { print; exit }' "$src/SKILL.md")"
if [ "$declared" != "name: $name" ]; then
    echo "ck-skill: $src/SKILL.md says '$declared', not 'name: $name'" >&2
    exit 1
fi

cp -R "$src" "$out"
chmod -R u+w "$out"
awk -v from="name: $name" -v to="name: ck-$name" \
    '/^---$/ { n++ } n == 1 && $0 == from && !done { $0 = to; done = 1 } { print }' \
    "$out/SKILL.md" >"$out/SKILL.md.new"
mv "$out/SKILL.md.new" "$out/SKILL.md"
find "$out" -type f -name '*.md' | while read -r file; do
    bash "$(dirname "$0")/ck-refs.sh" "$file" "$file.new" "$@"
    mv "$file.new" "$file"
done
