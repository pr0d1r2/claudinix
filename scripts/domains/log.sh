#!/usr/bin/env bash
# `domains --from-log` (SPEC scripts:T27, I.cmd `domains`): the hosts a
# cloud session's proxy refused, read from a saved session log.
#
# Two shapes name a host: `Host not in allowlist: <host>`, and a
# `CONNECT tunnel failed, response 403` line that carries the URL. A 403
# line without a URL names nothing, so it adds nothing.
#
# Usage: log.sh LOG_FILE   -> `host<TAB>log` lines

set -euo pipefail

log="${1:?usage: log.sh LOG_FILE}"
hosts="$(dirname "${BASH_SOURCE[0]}")/hosts.sh"

if [ ! -r "$log" ]; then
    echo "domains: cannot read log $log -- nothing was read" >&2
    exit 1
fi

{
    grep -oE 'Host not in allowlist: [A-Za-z0-9.-]+' "$log" |
        sed -E 's#^.*: #https://#' || true
    grep -F 'CONNECT tunnel failed, response 403' "$log" || true
} | bash "$hosts" log
