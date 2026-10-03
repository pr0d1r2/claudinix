#!/usr/bin/env bash
# The URL-to-host step every `domains` detector shares (SPEC scripts:T27).
#
# Reads text on stdin and prints `host<TAB>TAG` for every URL in it, in
# the order found: `scheme://[user@]host[:port]/...` (scheme prefixes such
# as `git+https` or `sparse+https` included) and scp-like git remotes
# (`git@host:owner/repo`). Hosts are lowercased; a name without a dot
# (localhost) is not a host the proxy could allow.
#
# Usage: hosts.sh TAG <TEXT

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "usage: hosts.sh TAG <TEXT" >&2
    exit 2
fi

tag="$1"
text="$(cat)"

{
    grep -oE '[A-Za-z][A-Za-z0-9+.-]*://[^/[:space:]"'\''<>?#]+' <<<"$text" |
        sed -E 's#^[^:]*://##; s#^.*@##; s#:[0-9]*$##' || true
    grep -v '://' <<<"$text" |
        grep -oE '[A-Za-z0-9._-]+@[A-Za-z0-9.-]+\.[A-Za-z]+:' |
        sed -E 's#^.*@##; s#:$##' || true
} | tr '[:upper:]' '[:lower:]' | while IFS= read -r host; do
    case "$host" in
    *.*) printf '%s\t%s\n' "$host" "$tag" ;;
    esac
done
