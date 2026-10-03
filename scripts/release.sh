#!/usr/bin/env bash
# Cut a release in two phases (SPEC C25, V33, T87, B10). The released SHA
# must hold cloud-home.storepath for its OWN agent home (nix:V15 tier 2),
# so the path is recorded and committed first, and the line pins THAT
# commit. The activation derivation does not read the file (V20), so the
# commit that adds it has the same agent home as the commit it recorded.
#
#   record [REV]   CI on main is green for REV (setup-line.sh, never
#                  --force), every eval-time input source and REV's agent
#                  home are in the cache (verify-cachix.sh --sources), then
#                  cloud-home.storepath is written (record-storepath.sh).
#                  Prints the commit and push for it; wait for CI on that
#                  commit, then publish it.
#   publish REV    REV's tree holds cloud-home.storepath, it equals the
#                  agent home evaluated AT REV, CI is green for REV and its
#                  sources and agent home are cached. Then the README block
#                  is regenerated for REV, release notes go to stdout and
#                  the commands that publish them to stderr.
#
# This script never commits, tags or pushes.
#
# Usage: scripts/release.sh record [REV]        (default: HEAD)
#        scripts/release.sh publish REV >notes.md
# Env:   SETUP_LINE, VERIFY_CACHIX, RECORD_STOREPATH, README_GUARD   the tools
#        README_FILE                                                passed through

set -euo pipefail

usage() {
    echo "usage: release.sh record [REV] | release.sh publish REV" >&2
    exit 2
}

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
setup_line="${SETUP_LINE:-$here/setup-line.sh}"
verify="${VERIFY_CACHIX:-$here/ci/verify-cachix.sh}"
record="${RECORD_STOREPATH:-$here/nix/record-storepath.sh}"
guard="${README_GUARD:-$here/guard/readme-setup-line.sh}"
readme="${README_FILE:-README.md}"
attr=homeConfigurations.cloud.activationPackage

[ "$#" -ge 1 ] || usage
phase="$1"
shift
case "$phase" in
record) [ "$#" -le 1 ] || usage ;;
publish) [ "$#" = 1 ] || usage ;;
*) usage ;;
esac
rev="${1:-HEAD}"

if ! sha="$(git rev-parse --verify --quiet "$rev^{commit}")"; then
    echo "release: cannot resolve $rev to a commit -- nothing was done" >&2
    exit 1
fi
short="${sha:0:12}"
# REV's tree, not the worktree: the line pins the commit.
top="$(git rev-parse --show-toplevel)"
flake="git+file://$top?rev=$sha"
# publish reads the file from the commit's tree, so record writes it there.
storepath="$top/cloud-home.storepath"

# gates WHAT: CI green for $sha, then every input source and the agent
# home cached (V33). WHAT ends each refusal ("nothing was recorded").
gates() {
    if ! "$setup_line" "$sha" >/dev/null; then
        echo "release: setup-line.sh refused $sha (see above) -- $1" >&2
        exit 1
    fi
    if ! "$verify" --sources "$flake" "$flake#$attr"; then
        echo "release: an input source or the agent home of $sha is not in the cache (see above) -- $1" >&2
        exit 1
    fi
}

if [ "$phase" = record ]; then
    gates "nothing was recorded"
    if ! CLOUD_HOME_STOREPATH="$storepath" "$record" "$flake" >&2; then
        echo "release: the agent home of $sha is not recorded (see above) -- nothing was recorded" >&2
        exit 1
    fi
    if [ "$(git show "$sha:cloud-home.storepath" 2>/dev/null || true)" = "$(cat "$storepath")" ]; then
        echo "release: $short already records its own agent home. Publish it directly:" >&2
        echo "    scripts/release.sh publish $sha >notes.md" >&2
        exit 0
    fi
    {
        echo "release: recorded the agent home of $short in cloud-home.storepath. Nothing was committed or pushed. Review, then run:"
        echo "    git add cloud-home.storepath"
        echo "    git commit -m \"chore(release): record the agent home of $short\" -m \"Why: the released SHA must hold cloud-home.storepath for its own agent home (V33, B10).\" -m \"Refs: §T.87, §V.33, §C.25\""
        echo "    git push"
        echo "release: wait until CI on main is green for that commit, then run:"
        echo "    scripts/release.sh publish \$(git rev-parse HEAD) >notes.md"
    } >&2
    exit 0
fi

# publish: the file in REV's tree, not in the worktree.
if ! recorded="$(git show "$sha:cloud-home.storepath" 2>/dev/null)" || [ -z "$recorded" ]; then
    echo "release: $short has no cloud-home.storepath, so its line would 404 at tier 2 (B10) -- run scripts/release.sh record $short, commit it, and publish that commit; nothing was published" >&2
    exit 1
fi
if ! home="$(nix eval --raw "$flake#$attr.outPath")"; then
    echo "release: could not evaluate the agent home of $short -- nothing was published" >&2
    exit 1
fi
if [ "$recorded" != "$home" ]; then
    echo "release: $short records $recorded but its agent home is $home -- run scripts/release.sh record $short and commit it; nothing was published" >&2
    exit 1
fi
gates "nothing was published"

if ! README_FILE="$readme" "$guard" --write "$sha"; then
    echo "release: $readme was not written (see above) -- fix the markers, then rerun; nothing was published" >&2
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
    echo "    git add $readme"
    echo "    git commit -m \"chore(release): publish $short\" -m \"Why: CI green, sources and agent home cached, cloud-home.storepath recorded for $short (C25, V33).\" -m \"Refs: §C.25, §V.33, §T.87\""
    echo "    git push"
    echo "    git tag -a claudinix-$short $sha -m \"claudinix $short\""
    echo "    git push origin claudinix-$short"
    echo "    gh release create claudinix-$short --verify-tag --title \"claudinix $short\" --notes-file notes.md"
    echo "release: notes.md is this script's stdout: scripts/release.sh publish $sha >notes.md"
} >&2
