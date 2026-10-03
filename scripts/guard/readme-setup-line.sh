#!/usr/bin/env bash
# The README's paste line is generated, never hand-written (SPEC C25, T75).
#
# Between `<!-- BEGIN setup-line -->` and `<!-- END setup-line -->` the
# README holds the exact line `scripts/setup-line.sh --force <SHA>`
# prints for the release SHA, and one sentence naming that SHA. The
# check reads the SHA from the block and regenerates it offline: CI was
# judged when the release was cut (release.sh), so no gh call here.
# Before the first release the block holds one placeholder sentence.
#
# Usage: readme-setup-line.sh               check the block
#        readme-setup-line.sh --write SHA   (re)write the block for SHA
# Env:   README_FILE (default README.md)

set -euo pipefail

usage() {
    echo "usage: readme-setup-line.sh [--write SHA]" >&2
    exit 2
}

readme="${README_FILE:-README.md}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
begin='<!-- BEGIN setup-line -->'
end='<!-- END setup-line -->'

# block SHA: the lines between the markers, as release SHA should have them.
block() {
    local line
    # A command that cannot exist, so setup-line.sh never asks GitHub; with
    # --force it prints the line anyway (its warning goes to /dev/null).
    line="$(GH_BIN=claudinix-no-gh-offline "$here/../setup-line.sh" --force "$1" 2>/dev/null)"
    printf '%s\n' '```sh' "$line" '```' ''
    # shellcheck disable=SC2016 # literal Markdown backticks, not a command
    printf 'The line pins claudinix to release `%s`: CI was green for that commit and its agent home was in the cache when it was published.\n' "$1"
}

has_markers() {
    [ -f "$readme" ] &&
        [ "$(grep -cxF "$begin" "$readme")" = 1 ] &&
        [ "$(grep -cxF "$end" "$readme")" = 1 ]
}

if [ "$#" -gt 0 ]; then
    [ "$1" = --write ] && [ "$#" = 2 ] || usage
    sha="$2"
    [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || usage
    if ! has_markers; then
        echo "readme-setup-line: $readme needs exactly one '$begin' and one '$end' line -- nothing written" >&2
        exit 1
    fi
    new="$(block "$sha")"
    tmp="$readme.tmp.$$"
    awk -v begin="$begin" -v end="$end" -v new="$new" '
        $0 == begin { print; print new; skip = 1; next }
        $0 == end { skip = 0 }
        !skip { print }
    ' "$readme" >"$tmp"
    mv "$tmp" "$readme"
    exit 0
fi

if ! has_markers; then
    echo "readme-setup-line: $readme needs exactly one '$begin' and one '$end' line around the release's paste line (C25)" >&2
    exit 1
fi

current="$(awk -v begin="$begin" -v end="$end" '
    $0 == end { skip = 0 }
    skip { print }
    $0 == begin { skip = 1 }
' "$readme")"
# Before the first release the block holds this sentence and nothing else.
# shellcheck disable=SC2016 # literal Markdown backticks, not a command
placeholder='No release yet: the maintainer publishes the line with `scripts/release.sh record`, then `scripts/release.sh publish`.'
if [ "$current" = "$placeholder" ]; then
    exit 0
fi
# shellcheck disable=SC2016 # literal Markdown backticks, not a command
sha="$(printf '%s\n' "$current" | grep -oE '`[0-9a-f]{40}`' | head -n 1 | tr -d '`' || true)"
if [ -z "$sha" ]; then
    echo "readme-setup-line: the setup-line block in $readme names no release SHA -- cut a release: scripts/release.sh record, commit, then scripts/release.sh publish" >&2
    exit 1
fi

if [ "$current" != "$(block "$sha")" ]; then
    echo "readme-setup-line: the setup-line block in $readme is not what setup-line.sh prints for $sha -- regenerate it: scripts/guard/readme-setup-line.sh --write $sha" >&2
    exit 1
fi
