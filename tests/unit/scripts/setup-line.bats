#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/setup-line.sh (SPEC T24, V20, C19): print the
# one-line UI setup script pinned to a commit's full SHA.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../scripts/setup-line.sh"
    # A fixture repo of its own; the caller's git env must not leak in.
    while read -r var; do unset "$var"; done < <(env | sed -n 's/^\(GIT_[A-Z_]*\)=.*/\1/p')
    REPO="$BATS_TEST_TMPDIR/repo"
    git init -q "$REPO"
    git -C "$REPO" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m first
    FIRST="$(git -C "$REPO" rev-parse HEAD)"
    git -C "$REPO" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m second
    HEAD_SHA="$(git -C "$REPO" rev-parse HEAD)"
    cd "$REPO" || exit 1
}

line_for() {
    # shellcheck disable=SC2016 # the line is printed, expanded later by the UI shell
    printf 'd=$(mktemp -d) && curl -fsSL https://raw.githubusercontent.com/pr0d1r2/nix-claude-code-cloud/%s/setup.sh -o "$d/setup.sh" && bash "$d/setup.sh" %s' "$1" "$1"
}

@test "default: the line for HEAD, full SHA in both places" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$output" = "$(line_for "$HEAD_SHA")" ]
}

@test "a revision argument resolves to its full SHA" {
    run bash "$SCRIPT" HEAD~1
    [ "$status" -eq 0 ]
    [ "$output" = "$(line_for "$FIRST")" ]
}

@test "exactly one line" {
    run bash "$SCRIPT"
    [ "${#lines[@]}" -eq 1 ]
}

@test "unknown revision: fails, prints no line" {
    run bash "$SCRIPT" no-such-rev
    [ "$status" -eq 1 ]
    [[ "$output" != *"curl"* ]]
}

@test "outside a git repository: fails, prints no line" {
    mkdir "$BATS_TEST_TMPDIR/plain"
    cd "$BATS_TEST_TMPDIR/plain" || exit 1
    GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" != *"curl"* ]]
}

@test "more than one argument is a usage error" {
    run bash "$SCRIPT" a b
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
}
