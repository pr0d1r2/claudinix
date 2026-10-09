#!/usr/bin/env bash
# `checks.<system>.rtk-pin`: the inputs nix-rtk follows from us
# (nixpkgs-lock, rtk-src) are locked at the revs in nix-rtk's own
# flake.lock (SPEC nix:T151, B44, .:C14). Only then is rtk's store path
# the one its CI pushed to cachix; any other rev makes every cloud setup
# compile rtk. Bump both inputs here together with nix-rtk's `cached`
# branch. Each input is found through its lock's root node, so a renamed
# node (`nixpkgs-lock_2`) still counts. OUT is created only when every
# rev agrees.
#
# Usage: rtk-pin-check.sh OUR_LOCK RTK_LOCK OUT

set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "usage: rtk-pin-check.sh OUR_LOCK RTK_LOCK OUT" >&2
    exit 2
fi

# rev LOCK INPUT: the rev LOCK pins for the root input INPUT.
rev() {
    jq -er --arg i "$2" '.nodes[.nodes[.root].inputs[$i]].locked.rev' "$1" 2>/dev/null
}

status=0
for input in nixpkgs-lock rtk-src; do
    if ! ours="$(rev "$1" "$input")"; then
        echo "rtk-pin-check: $1 locks no $input rev" >&2
        status=1
        continue
    fi
    if ! theirs="$(rev "$2" "$input")"; then
        echo "rtk-pin-check: $2 locks no $input rev -- cannot tell what nix-rtk's cache was built at" >&2
        status=1
        continue
    fi
    if [ "$ours" != "$theirs" ]; then
        echo "rtk-pin-check: our $input is $ours but nix-rtk's cache was built at $theirs -- a cloud setup would compile rtk; lock both at the same rev" >&2
        status=1
    fi
done

if [ "$status" -eq 0 ]; then
    touch "$3"
fi
exit "$status"
