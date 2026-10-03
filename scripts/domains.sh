#!/usr/bin/env bash
# The Allowed domains a cloud environment needs for given projects (SPEC
# scripts:T27, I.cmd `domains`, C6).
#
# The session proxy refuses every host not in the environment's allowed
# domains. This prints, one per line and each once:
#   1. the base list, `allowlist.txt` (the Nix hosts), in its order;
#   2. hosts each project's files name, one detector per ecosystem
#      under `domains/` (Cargo, Nix, git, npm, Python, Ruby, Go), sorted;
#   3. with --from-log, hosts a session's proxy refused;
#   4. each project's `network.extra_domains` from its .claudinix.toml
#      (scripts:T91, through config.sh), sorted in with 2.
# Plain output is paste-ready and also copied to the clipboard when a
# clipboard tool is there. --why tags each host with its source (`base`,
# the file that named it, `log`, or `config`). Reads files only, never
# the network. A bad .claudinix.toml exits 2 (scripts:V34).
#
# Usage: domains.sh [--why] [--from-log FILE]... [PROJECT_DIR...]
#        (default PROJECT_DIR: the current directory)
# Env:   CLAUDINIX_ALLOWLIST  base list (default: allowlist.txt beside
#                             scripts/)
#        CLAUDINIX_SCRIPTS    dir holding domains/ (default: this script's dir)
#        CLIPBOARD_TOOLS      tried in order (default: pbcopy wl-copy xclip)

set -euo pipefail

usage() {
    echo "usage: domains.sh [--why] [--from-log FILE]... [PROJECT_DIR...]" >&2
    exit 2
}

why=0
dirs=()
logs=()
while [ "$#" -gt 0 ]; do
    case "$1" in
    --why) why=1 ;;
    --from-log)
        [ "$#" -ge 2 ] || usage
        logs+=("$2")
        shift
        ;;
    -*) usage ;;
    *) dirs+=("$1") ;;
    esac
    shift
done
[ "${#dirs[@]}" -gt 0 ] || dirs=(.)

lib="${CLAUDINIX_SCRIPTS:-$(dirname "${BASH_SOURCE[0]}")}"
allowlist="${CLAUDINIX_ALLOWLIST:-$lib/../allowlist.txt}"
detectors=(cargo nix git npm python ruby go)
tab="$(printf '\t')"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if [ ! -r "$allowlist" ]; then
    echo "domains: cannot read the base list $allowlist -- nothing was checked" >&2
    exit 1
fi
while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [ -n "$line" ] || continue
    grep -qxF "$line" "$tmp/base" 2>/dev/null || echo "$line" >>"$tmp/base"
done <"$allowlist"
touch "$tmp/base"

# Each project reads its own .claudinix.toml (scripts:T97): a config a
# caller handed down (scripts:T96) is one project's, so it holds only
# when there is one project.
[ "${#dirs[@]}" -eq 1 ] || unset CLAUDINIX_CONFIG_JSON

: >"$tmp/found"
for dir in "${dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "domains: no directory $dir -- nothing was checked" >&2
        exit 1
    fi
    prefix=
    [ "$dir" = . ] || prefix="${dir%/}/"
    for detector in "${detectors[@]}"; do
        bash "$lib/domains/$detector.sh" "$dir" | while IFS="$tab" read -r host file; do
            printf '%s\t%s\n' "$host" "$prefix$file"
        done >>"$tmp/found"
    done
    # A bad file stops here: config.sh named the file and the key (V34).
    bash "$lib/config.sh" --dir "$dir" get network.extra_domains >"$tmp/extra" || exit "$?"
    while IFS= read -r host; do
        [ -z "$host" ] || printf '%s\tconfig\n' "$host"
    done <"$tmp/extra" >>"$tmp/found"
done
for log in "${logs[@]+"${logs[@]}"}"; do
    bash "$lib/domains/log.sh" "$log" >>"$tmp/found"
done

# Base hosts first; then each new host once, sorted, with the first
# source that named it (a stable sort keeps the detection order).
{
    while IFS= read -r host; do
        printf '%s\tbase\n' "$host"
    done <"$tmp/base"
    sort -s -t "$tab" -k1,1 -u "$tmp/found" | while IFS="$tab" read -r host file; do
        grep -qxF "$host" "$tmp/base" || printf '%s\t%s\n' "$host" "$file"
    done
} >"$tmp/out"

cut -f 1 "$tmp/out" >"$tmp/hosts"
if [ "$why" = 1 ]; then
    cat "$tmp/out"
else
    cat "$tmp/hosts"
fi

for tool in ${CLIPBOARD_TOOLS:-pbcopy wl-copy xclip}; do
    command -v "$tool" >/dev/null 2>&1 || continue
    case "${tool##*/}" in
    xclip) set -- -selection clipboard ;;
    *) set -- ;;
    esac
    # xclip stays behind as a daemon: let it hold no pipe of ours open.
    if "$tool" "$@" <"$tmp/hosts" >/dev/null 2>&1; then
        echo "domains: copied $(wc -l <"$tmp/hosts" | tr -d ' ') hosts to the clipboard (${tool##*/})" >&2
    fi
    break
done
