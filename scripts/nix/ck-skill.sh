#!/usr/bin/env bash
# A cavekit skill under the name `ck-<name>` (SPEC nix:T154, nix:V47).
# Plugins are not installed in the cloud, so the `ck:` namespace a plugin
# gives cavekit's skills is lost; naming them `ck-<name>` keeps them
# apart from caveman's own skills, whose `caveman` then ships bare.
# Copies the skill directory SRC to OUT, sets its frontmatter
# `name: NAME` to `name: ck-NAME`, and rewrites each reference to a
# cavekit verb in every markdown file (`/ck:<verb>` from the plugin, or a
# bare `/<verb>`) to `/ck-<verb>`. Paths such as `skills/spec/SKILL.md`
# and longer words such as `/specs` are left as they are.
#
# Usage: ck-skill.sh SRC NAME OUT

set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "usage: ck-skill.sh SRC NAME OUT" >&2
    exit 2
fi

src="$1"
name="$2"
out="$3"

if [ ! -f "$src/SKILL.md" ]; then
    echo "ck-skill: $src has no SKILL.md" >&2
    exit 1
fi
declared="$(awk '/^---$/ { n++; next } n == 1 && /^name: / { print; exit }' "$src/SKILL.md")"
if [ "$declared" != "name: $name" ]; then
    echo "ck-skill: $src/SKILL.md says '$declared', not 'name: $name'" >&2
    exit 1
fi

verbs='spec|build|check|backprop|caveman|deepen|grill|research|review'
# One verb reference: not preceded by a word or path character, not
# followed by one. Applied twice, so a reference right after another one
# (whose closing character the first pass consumed) is caught too.
ref="(^|[^[:alnum:]_./:-])/(ck:)?($verbs)([^[:alnum:]_/-]|\$)"

cp -R "$src" "$out"
chmod -R u+w "$out"
awk -v from="name: $name" -v to="name: ck-$name" \
    '/^---$/ { n++ } n == 1 && $0 == from && !done { $0 = to; done = 1 } { print }' \
    "$out/SKILL.md" >"$out/SKILL.md.new"
mv "$out/SKILL.md.new" "$out/SKILL.md"
find "$out" -type f -name '*.md' | while read -r file; do
    sed -E -e "s#$ref#\\1/ck-\\3\\4#g" -e "s#$ref#\\1/ck-\\3\\4#g" "$file" >"$file.new"
    mv "$file.new" "$file"
done
