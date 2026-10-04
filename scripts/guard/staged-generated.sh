#!/usr/bin/env bash
# Generated files are checked as staged, not as the worktree has them
# (dev:T123, dev:V39, B18).
#
# pre-commit's fix steps rewrite README badges and the INTEGRATION step
# table in the worktree only, so a commit staging hk.pkl alone used to pass
# with stale output. This copies the index to a snapshot
# (`git checkout-index`) and runs `claudinix-dev badges --check` and
# `steps --check` on it: what fails here is what the commit would carry.
#
# Usage: staged-generated.sh
# Env:   CLAUDINIX_DEV (default claudinix-dev)

set -euo pipefail

tool="${CLAUDINIX_DEV:-claudinix-dev}"
snapshot="$(mktemp -d)"
trap 'rm -rf "$snapshot"' EXIT
git checkout-index --all --prefix="$snapshot/"

status=0
for verb in badges steps; do
    if ! "$tool" "$verb" --check --root "$snapshot"; then
        echo "staged-generated: the staged files fail \`claudinix-dev $verb --check\` -- run \`claudinix-dev $verb --write\`, then \`git add\` what it rewrote" >&2
        status=1
    fi
done
exit "$status"
