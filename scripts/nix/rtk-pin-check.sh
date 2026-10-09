#!/usr/bin/env bash
# `checks.<system>.rtk-pin`: our nixpkgs-lock rev equals the one in
# nix-rtk's own flake.lock (SPEC nix:T151, .:C14). nix-rtk follows our
# nixpkgs-lock, so rtk's store path is the one its CI pushed to cachix
# only while both revs agree; any other rev makes every cloud setup
# compile rtk. A nixpkgs-lock bump here must wait for nix-rtk's `cached`
# branch to reach the same rev, then move both together.
# OUT is created only when the revs agree.
#
# Usage: rtk-pin-check.sh OUR_REV RTK_LOCK OUT

set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "usage: rtk-pin-check.sh OUR_REV RTK_LOCK OUT" >&2
    exit 2
fi

theirs="$(jq -er '.nodes["nixpkgs-lock"].locked.rev' "$2" 2>/dev/null)" || {
    echo "rtk-pin-check: $2 locks no nixpkgs-lock rev -- cannot tell which rev nix-rtk's cache was built at" >&2
    exit 1
}

if [ "$1" != "$theirs" ]; then
    echo "rtk-pin-check: our nixpkgs-lock is $1 but nix-rtk's cache was built at $theirs -- a cloud setup would compile rtk; lock both at the same rev" >&2
    exit 1
fi

touch "$3"
