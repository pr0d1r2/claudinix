#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/setup-line.sh (SPEC T24, T69, V20, C19): print
# the one-line UI setup script pinned to a commit's full SHA, only for a
# commit whose CI run on the default branch is green. `gh` is a stub that
# logs its args and prints GH_JSON (exit GH_RC); nothing leaves the test.

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
    STUBS="$BATS_TEST_TMPDIR/stubs"
    export GH_LOG="$BATS_TEST_TMPDIR/gh.log"
    export GH_JSON='[{"conclusion":"success","status":"completed"}]'
    export GH_RC=0
    mkdir -p "$STUBS"
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' 'echo "gh $*" >>"$GH_LOG"' \
        'printf "%s\n" "$GH_JSON"' 'exit "$GH_RC"' >"$STUBS/gh"
    chmod +x "$STUBS/gh"
    export PATH="$STUBS:$PATH"
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

@test "asks CI about that exact commit on the default branch (T69)" {
    run bash "$SCRIPT" HEAD~1
    [ "$status" -eq 0 ]
    grep -qx "gh run list --repo pr0d1r2/nix-claude-code-cloud --commit $FIRST --branch main --workflow ci.yml --json conclusion,status" "$GH_LOG"
}

@test "CI run failed: refuses, says why, prints no line (T69)" {
    GH_JSON='[{"conclusion":"failure","status":"completed"}]' run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not green"* ]]
    [[ "$output" == *"--force"* ]]
    [[ "$output" != *"curl"* ]]
}

@test "CI run still in progress: refuses (T69)" {
    GH_JSON='[{"conclusion":"","status":"in_progress"}]' run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"in_progress"* ]]
    [[ "$output" != *"curl"* ]]
}

@test "no CI run on the default branch for the commit: refuses (T69)" {
    GH_JSON='[]' run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"no CI run"* ]]
    [[ "$output" != *"curl"* ]]
}

@test "the newest run decides: an older green run does not count (T69)" {
    GH_JSON='[{"conclusion":"failure","status":"completed"},{"conclusion":"success","status":"completed"}]' run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" != *"curl"* ]]
}

@test "gh fails: cannot check, so refuses (T69)" {
    GH_RC=1 run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"could not ask"* ]]
    [[ "$output" != *"curl"* ]]
}

@test "gh missing: cannot check, so refuses (T69)" {
    GH_BIN="$BATS_TEST_TMPDIR/no-such-gh" run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"could not ask"* ]]
    [[ "$output" != *"curl"* ]]
}

@test "--force prints the line anyway, with a warning (T69)" {
    GH_JSON='[{"conclusion":"failure","status":"completed"}]' run --separate-stderr bash "$SCRIPT" --force
    [ "$status" -eq 0 ]
    [ "$output" = "$(line_for "$HEAD_SHA")" ]
    [[ "$stderr" == *"not green"* ]]
    GH_RC=1 run --separate-stderr bash "$SCRIPT" --force HEAD~1
    [ "$status" -eq 0 ]
    [ "$output" = "$(line_for "$FIRST")" ]
}

@test "--force with more than one revision is still a usage error" {
    run bash "$SCRIPT" --force a b
    [ "$status" -eq 2 ]
}
