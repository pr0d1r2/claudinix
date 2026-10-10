#!/usr/bin/env bash
# Copies the markdown file IN to OUT, rewriting each reference to a cavekit verb
# (`/ck:<verb>` from the plugin, or a bare `/<verb>`) to `/ck-<verb>`
# (SPEC nix:V47, nix:B51). Only the VERB... given are rewritten: the
# cavekit skills the home ships (nix/cloud-skills.nix). Paths such as
# `skills/spec/SKILL.md` and longer words such as `/specs` are left as
# they are.
#
# Usage: ck-refs.sh IN OUT VERB...

set -euo pipefail

if [ "$#" -lt 3 ]; then
    echo "usage: ck-refs.sh IN OUT VERB..." >&2
    exit 2
fi

in="$1"
out="$2"
shift 2
if [ ! -f "$in" ]; then
    echo "ck-refs: $in is not a file" >&2
    exit 1
fi

verbs="$(
    IFS='|'
    echo "$*"
)"
# One verb reference: not preceded by a word or path character, not
# followed by one. A match consumes its closing character, so a reference
# right after another one is caught by the next pass: the text is
# rewritten until it stops changing.
ref="(^|[^[:alnum:]_./:-])/(ck:)?($verbs)([^[:alnum:]_/-]|\$)"

before=""
after="$(cat "$in")"
while [ "$before" != "$after" ]; do
    before="$after"
    after="$(sed -E "s#$ref#\\1/ck-\\3\\4#g" <<<"$before")"
done
printf '%s\n' "$after" >"$out"
