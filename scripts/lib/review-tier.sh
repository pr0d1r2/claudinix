#!/usr/bin/env bash
# The review tier a pull request's diff sets (SPEC cloud:T183, cloud:V66),
# sourced by cloud-all.sh. Highest hit wins, and a path no class names is
# council, so a new kind of file never slips into the light tier:
# - light (V65, the security review): docs, specs and tests only, that is
#   `docs/**`, `tests/**` and any `*.md` outside `scripts/`;
# - light+correctness: `scripts/**` (its prompts and role files too),
#   `setup.sh`, `home/` code (its `*.md` are docs);
# - council (V51, every role): the permission list, the hooks
#   (`.claude/**`, the dev-shell hook scripts, `hk.pkl`), the launcher
#   lib, the consumer surface (`.claudinix.toml`, `nix-dev`), every
#   `AGENTS.md` and `CLAUDE.md` (they steer each session), anything else,
#   and more than 300 changed lines.

set -euo pipefail

review_tier_max_lines=300

# review_tier_rank PATH: 1 light, 2 light+correctness, 3 council.
review_tier_rank() {
    case "$1" in
    nix/cloud-permissions.json | .claude/* | hk.pkl | \
        scripts/dev/shell-hook.sh | scripts/dev/legacy-hook.sh | scripts/dev/session-start.sh | \
        scripts/lib/cloud-launch.sh | .claudinix.toml | scripts/nix-dev.sh | scripts/nix-dev.jq | \
        AGENTS.md | CLAUDE.md | */AGENTS.md | */CLAUDE.md)
        echo 3
        ;;
    scripts/* | setup.sh) echo 2 ;;
    home/*.md) echo 1 ;;
    home/*) echo 2 ;;
    docs/* | tests/* | *.md) echo 1 ;;
    *) echo 3 ;;
    esac
}

# review_tier: read "ADDITIONS<TAB>DELETIONS<TAB>PATH" lines (gh pr view
# --json files) and print "TIER<TAB>REASON", the reason being the first
# path of the highest class, or the changed-line count. No files is
# council. A line it cannot read prints nothing and returns 1: a tier is
# never guessed.
review_tier() {
    local add del path rank best=0 reason="" lines=0
    while IFS=$'\t' read -r add del path; do
        [ -n "$add$del$path" ] || continue
        [[ "$add" =~ ^[0-9]+$ && "$del" =~ ^[0-9]+$ && -n "$path" ]] || return 1
        lines=$((lines + add + del))
        rank="$(review_tier_rank "$path")"
        if [ "$rank" -gt "$best" ]; then
            best="$rank"
            reason="$path"
        fi
    done
    if [ "$best" -eq 0 ]; then
        best=3
        reason="no changed files"
    elif [ "$best" -lt 3 ] && [ "$lines" -gt "$review_tier_max_lines" ]; then
        best=3
        reason="$lines changed lines"
    fi
    case "$best" in
    1) printf 'light\t%s\n' "$reason" ;;
    2) printf 'light+correctness\t%s\n' "$reason" ;;
    *) printf 'council\t%s\n' "$reason" ;;
    esac
}

# review_tier_level TIER: 1 light, 2 light+correctness, 3 council, so a
# rise shows; an unknown tier returns 1.
review_tier_level() {
    case "$1" in
    light) echo 1 ;;
    light+correctness) echo 2 ;;
    council) echo 3 ;;
    *) return 1 ;;
    esac
}

# review_tier_roles TIER: the roles the tier reviews by, one per line; none
# for council, which is every role there is. An unknown tier returns 1.
review_tier_roles() {
    case "$1" in
    light) echo security ;;
    light+correctness) printf '%s\n' security correctness ;;
    council) ;;
    *) return 1 ;;
    esac
}
