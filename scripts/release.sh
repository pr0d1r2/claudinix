#!/usr/bin/env bash
# Cut a release: the maintainer's one command (SPEC C25, T75).
#
#   1. CI on main is green for REV: setup-line.sh (without --force)
#      refuses otherwise, and that refusal stops the release.
#   2. REV's agent home is in the cache: record-storepath.sh writes
#      cloud-home.storepath only after a 200 narinfo (nix:V15, V22).
#   3. The README block is regenerated for REV (readme-setup-line.sh),
#      the same text the gate checks.
#   4. Release notes go to stdout; the git and gh commands that publish
#      them go to stderr. This script never commits, tags or pushes.
#
# Usage: scripts/release.sh [REV]   (default: HEAD)
#        scripts/release.sh REV >notes.md   keeps the notes in a file
# Env:   SETUP_LINE, RECORD_STOREPATH, README_GUARD   the three tools
#        README_FILE, CLOUD_HOME_STOREPATH            passed through

set -euo pipefail

if [ "$#" -gt 1 ]; then
    echo "usage: release.sh [REV]" >&2
    exit 2
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
setup_line="${SETUP_LINE:-$here/setup-line.sh}"
record="${RECORD_STOREPATH:-$here/nix/record-storepath.sh}"
guard="${README_GUARD:-$here/guard/readme-setup-line.sh}"
readme="${README_FILE:-README.md}"
rev="${1:-HEAD}"

if ! sha="$(git rev-parse --verify --quiet "$rev^{commit}")"; then
    echo "release: cannot resolve $rev to a commit -- nothing was released" >&2
    exit 1
fi
short="${sha:0:12}"

if ! "$setup_line" "$sha" >/dev/null; then
    echo "release: setup-line.sh refused $sha (see above) -- nothing was released" >&2
    exit 1
fi

# The release commit's agent home, not the worktree's: the line pins it.
top="$(git rev-parse --show-toplevel)"
if ! "$record" "git+file://$top?rev=$sha" >&2; then
    echo "release: the agent home of $sha is not recorded (see above) -- nothing was released" >&2
    exit 1
fi

if ! README_FILE="$readme" "$guard" --write "$sha"; then
    echo "release: cloud-home.storepath was written but $readme was not -- fix the markers, then rerun" >&2
    exit 1
fi

# The notes are the README block, so the two can never disagree.
echo "## claudinix $short"
echo
echo "Paste this line into the claude.ai environment's setup script:"
echo
awk '
    /^<!-- END setup-line -->$/ { skip = 0 }
    skip { print }
    /^<!-- BEGIN setup-line -->$/ { skip = 1 }
' "$readme"

{
    echo
    echo "release: $short is ready. Nothing was committed, tagged or pushed. Review, then run:"
    echo "    git add cloud-home.storepath $readme"
    echo "    git commit -m \"chore(release): publish $short\" -m \"Why: CI green and the agent home cached for $short (C25).\" -m \"Refs: §C.25, §T.75\""
    echo "    git push"
    echo "    git tag -a claudinix-$short $sha -m \"claudinix $short\""
    echo "    git push origin claudinix-$short"
    echo "    gh release create claudinix-$short --verify-tag --title \"claudinix $short\" --notes-file notes.md"
    echo "release: notes.md is this script's stdout: scripts/release.sh $rev >notes.md"
} >&2
