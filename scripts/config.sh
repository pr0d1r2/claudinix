#!/usr/bin/env bash
# The one reader of a project's `.claudinix.toml` (SPEC scripts:T90,
# scripts:V34, .:C28, I.file `.claudinix.toml`).
#
# The file is optional and sits at the project's root. Nix parses it
# (`builtins.fromTOML`), so the cloud VM needs no other TOML parser; the
# file's path reaches nix through the environment, never spliced into
# Nix code. config.jq checks the schema and merges the defaults, which
# are what the tools do without a file. Any problem -- an unknown table
# or key, a wrong type, a bad value (scripts:T95: an empty string, a
# cache.name that is not a cachix name, an extra domain that is not a
# bare hostname, an installable or branch prefix with a space, quote or
# control character), a `version` other than 1, a file that is not
# TOML -- exits 2 naming the key and the file as given (V26).
#
#   json           the effective config (defaults merged), as JSON
#   get TABLE.KEY  one value; a list prints one item per line
#   check          nothing; exit 0 when the file is valid or absent
#
# One nix eval per call, none without a file: a tool that needs several
# keys calls `json` once and reads it with jq. A tool that calls another
# tool passes that JSON on as CLAUDINIX_CONFIG_JSON (scripts:T96): one
# eval per run.
#
# Usage: config.sh [--dir DIR] get TABLE.KEY | json | check
#        file: at the root of DIR's git repo, else in DIR; without
#        --dir, CLAUDINIX_CONFIG, else at the root of the cwd's git
#        repo, else in the cwd
# Env:   CLAUDINIX_CONFIG_JSON  the effective config a caller already read
#                               (`json`'s output): used as it is, after the
#                               same checks; no file is read, no nix runs
#        CLAUDINIX_CONFIG       the file to read when no --dir is given
#        CLAUDINIX_SCRIPTS      dir holding config.jq (default: this script's dir)

set -euo pipefail

usage() {
    echo "usage: config.sh [--dir DIR] get TABLE.KEY | json | check" >&2
    exit 2
}

dir=
dir_given=0
while [ "$#" -gt 0 ]; do
    case "$1" in
    --dir)
        [ "$#" -ge 2 ] || usage
        dir="$2"
        dir_given=1
        shift 2
        ;;
    -*) usage ;;
    *) break ;;
    esac
done
[ "$#" -ge 1 ] || usage
cmd="$1"
shift
key=
case "$cmd" in
get)
    [ "$#" -eq 1 ] || usage
    key="$1"
    ;;
json | check) [ "$#" -eq 0 ] || usage ;;
*) usage ;;
esac

lib="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"

if ! command -v jq >/dev/null 2>&1; then
    echo "config: jq is not on PATH -- cannot read the config" >&2
    exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# check_and_print FILE PRESENT: config.jq on stdin, as the command asks.
check_and_print() {
    local rc=0
    jq -r --arg file "$1" --argjson present "$2" --arg key "$key" \
        -f "$lib/config.jq" >"$tmp/out" || rc=$?
    case "$rc" in
    0) ;;
    2) exit 2 ;;
    *)
        echo "config: jq could not check $1 (exit $rc)" >&2
        exit 1
        ;;
    esac
    [ "$cmd" = check ] || cat "$tmp/out"
}

# The config a calling tool already read (scripts:T96): checked like a
# file, never re-read, no nix.
if [ -n "${CLAUDINIX_CONFIG_JSON:-}" ]; then
    if ! jq -e 'type == "object"' <<<"$CLAUDINIX_CONFIG_JSON" >/dev/null 2>&1; then
        echo "config: CLAUDINIX_CONFIG_JSON is not a JSON object -- unset it to read .claudinix.toml" >&2
        exit 2
    fi
    check_and_print CLAUDINIX_CONFIG_JSON true <<<"$CLAUDINIX_CONFIG_JSON"
    exit 0
fi

# --dir D resolves as the no-flag case does from the cwd: D's git top,
# else D itself (scripts:T97). CLAUDINIX_CONFIG only stands in for the
# cwd's file, so it never crosses into another project's --dir.
if [ "$dir_given" = 1 ]; then
    if [ ! -d "$dir" ]; then
        echo "config: no directory $dir -- nothing was read" >&2
        exit 2
    fi
    root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)"
    file="${root:-${dir%/}}/.claudinix.toml"
elif [ -n "${CLAUDINIX_CONFIG:-}" ]; then
    file="$CLAUDINIX_CONFIG"
else
    root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    file="${root:-.}/.claudinix.toml"
fi

present=false
parsed='{}'
if [ -e "$file" ]; then
    present=true
    if ! command -v nix >/dev/null 2>&1; then
        echo "config: nix is not on PATH -- cannot read $file" >&2
        exit 1
    fi
    case "$file" in
    /*) abs="$file" ;;
    *) abs="$PWD/$file" ;;
    esac
    # shellcheck disable=SC2016 # Nix code: nix reads the variable, not bash
    if ! parsed="$(CLAUDINIX_CONFIG_FILE="$abs" nix eval --extra-experimental-features nix-command \
        --impure --json --expr 'builtins.fromTOML (builtins.readFile (builtins.getEnv "CLAUDINIX_CONFIG_FILE"))' \
        2>"$tmp/err")"; then
        reason="$(grep -E '^[[:space:]]*error:' "$tmp/err" | tail -n 1 || true)"
        reason="${reason#"${reason%%[![:space:]]*}"}"
        echo "config: $file: cannot be read as TOML (${reason:-nix eval failed})" >&2
        exit 2
    fi
fi

check_and_print "$file" "$present" <<<"$parsed"
