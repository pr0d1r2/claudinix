#!/usr/bin/env bash
# What a Claude Code session cost, from its transcripts (SPEC scripts:T176,
# I.cmd `burn`, V61, V26).
#
# Reads `*.jsonl` transcripts, dedupes assistant rows by `message.id` (last
# wins) and prints 1 row per model: input, cache write (5m + 1h), cache
# read and output tokens, and $ from the price table below (cache read
# 0.1x, write 5m 1.25x, 1h 2x the input price). A model that is not in the
# table keeps its tokens and prints `?` for $: no price is guessed.
#
# Usage: burn.sh [--self | --pr N [--post] | --prices] [FILE | DIR...]
#   (none)   the newest session in the projects dir and its subagents
#   DIR      every transcript below it
#   --self   1 line `Burn: in=.. cw=.. cr=.. out=.. $x.xx (models)`; when
#            it cannot measure: `Burn: unmeasured (no-transcript|no-usage)`,
#            exit 0
#   --pr N   table of the PR's `Burn:` lines from OWNER | MEMBER comments
#   --post   with --pr: write the table as 1 `## Burn` comment
#   --prices the price table as JSON, {model-prefix: [input, output]}; reads nothing else
# Env:   CLAUDINIX_SCRIPTS  dir holding burn.jq (default: this script's dir)
#        CLAUDE_CONFIG_DIR  holds `projects/` (default: ~/.claude)
#
# List price in $ per million tokens: input, output. A model name matches
# by prefix (the longest wins), so a dated id finds its row. The one source
# of prices (`--prices`); docs/MODEL.md price block is filled from it (`claudinix-dev prices`, dev:T179).
PRICES=(
    "claude-opus-5-5 4 20"
    "claude-opus-4-6 5 25"
    "claude-sonnet-5-5 2 10"
    "claude-haiku-4-5 1 5"
)

set -euo pipefail

usage() {
    echo "usage: burn.sh [--self | --pr N [--post] | --prices] [FILE | DIR...]" >&2
    exit 2
}

self=0
show_prices=0
pr=
post=0
paths=()
while [ $# -gt 0 ]; do
    case "$1" in
    --self) self=1 ;;
    --post) post=1 ;;
    --prices) show_prices=1 ;;
    --pr)
        [ $# -ge 2 ] || usage
        pr="$2"
        shift
        ;;
    -*) usage ;;
    *) paths+=("$1") ;;
    esac
    shift
done
[ "$post" = 0 ] || [ -n "$pr" ] || usage
[ -z "$pr" ] || [ "$self" = 0 ] || usage
[ -z "$pr" ] || [[ "$pr" =~ ^[0-9]+$ ]] || usage

lib="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"
projects="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"

prices_json() {
    printf '%s\n' "${PRICES[@]}" |
        jq -Rn '[inputs | split(" ") | {(.[0]): [(.[1] | tonumber), (.[2] | tonumber)]}] | add'
}

[ "$show_prices" = 0 ] || {
    prices_json
    exit 0
}

# Run burn.jq in $1 mode over stdin rows.
burn_jq() {
    jq -sr --arg mode "$1" --argjson prices "$(prices_json)" -f "$lib/burn.jq"
}

if [ -n "$pr" ]; then
    table=$(gh pr view "$pr" --json comments | burn_jq pr)
    echo "$table"
    [ "$post" = 0 ] || printf '## Burn\n\n%s\n' "$table" | gh pr comment "$pr" --body-file -
    exit 0
fi

# The newest session of the projects dir, then its subagents.
newest_session() {
    [ -d "$projects" ] || return 0
    local newest='' file
    while IFS= read -r file; do
        if [ -z "$newest" ] || [ "$file" -nt "$newest" ]; then newest="$file"; fi
    done < <(find "$projects" -name '*.jsonl' -not -path '*/subagents/*')
    echo "$newest"
}

transcripts=()
if [ "${#paths[@]}" -gt 0 ]; then
    for path in "${paths[@]}"; do
        if [ -d "$path" ]; then
            while IFS= read -r file; do transcripts+=("$file"); done \
                < <(find "$path" -name '*.jsonl')
        elif [ -f "$path" ]; then
            transcripts+=("$path")
        fi
    done
else
    session=$(newest_session)
    if [ -n "$session" ]; then
        transcripts+=("$session")
        while IFS= read -r file; do transcripts+=("$file"); done \
            < <(find "${session%.jsonl}/subagents" -name '*.jsonl' 2>/dev/null || true)
    fi
fi

if [ "${#transcripts[@]}" -eq 0 ]; then
    if [ "$self" = 1 ]; then
        echo "Burn: unmeasured (no-transcript)"
        exit 0
    fi
    echo "burn: no transcript in ${paths[*]:-$projects}" >&2
    exit 1
fi

# The assistant rows with usage: burn.jq keeps no other, so the second jq slurps less.
rows() {
    jq -cR 'fromjson? | select(.type? == "assistant" and .message.usage? != null)' "${transcripts[@]}"
}

if [ "$self" = 1 ]; then
    rows | burn_jq self
else
    rows | burn_jq table
fi
