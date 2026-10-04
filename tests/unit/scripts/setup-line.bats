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
    # `gh auth status` exits GH_AUTH_RC (default GH_RC); other calls print
    # GH_ERR, when set, on stderr.
    # `gh api` (short SHA lookup, scripts:V37) prints GH_API_OUT and exits
    # GH_API_RC (default 0).
    printf '%s\n' '#!/usr/bin/env bash' 'echo "gh $*" >>"$GH_LOG"' \
        '[ "$1" != auth ] || exit "${GH_AUTH_RC:-$GH_RC}"' \
        '[ "$1" != api ] || { printf "%s\n" "${GH_API_OUT:-}"; exit "${GH_API_RC:-0}"; }' \
        '[ -z "${GH_ERR:-}" ] || echo "$GH_ERR" >&2' \
        'printf "%s\n" "$GH_JSON"' 'exit "$GH_RC"' >"$STUBS/gh"
    chmod +x "$STUBS/gh"
    export PATH="$STUBS:$PATH"
    cd "$REPO" || exit 1
}

line_for() {
    # shellcheck disable=SC2016 # the line is printed, expanded later by the UI shell
    printf 'd=$(mktemp -d) && curl -fsSL https://raw.githubusercontent.com/pr0d1r2/claudinix/%s/setup.sh -o "$d/setup.sh" && bash "$d/setup.sh" %s' "$1" "$1"
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
    grep -qx "gh run list --repo pr0d1r2/claudinix --commit $FIRST --branch main --workflow ci.yml --json conclusion,status" "$GH_LOG"
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

@test "a full SHA outside any clone is used as is; CI decides (guide app)" {
    mkdir "$BATS_TEST_TMPDIR/plain"
    cd "$BATS_TEST_TMPDIR/plain" || exit 1
    sha=0123456789abcdef0123456789abcdef01234567
    GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" run bash "$SCRIPT" "$sha"
    [ "$status" -eq 0 ]
    [ "$output" = "$(line_for "$sha")" ]
    grep -q -- "--commit $sha " "$GH_LOG"
    GH_JSON='[]' GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" run bash "$SCRIPT" "$sha"
    [ "$status" -eq 1 ]
}

@test "a short SHA outside any clone still fails to resolve" {
    mkdir "$BATS_TEST_TMPDIR/plain"
    cd "$BATS_TEST_TMPDIR/plain" || exit 1
    GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" run bash "$SCRIPT" 0123456
    [ "$status" -eq 1 ]
    [[ "$output" != *"curl"* ]]
}

@test "--force with more than one revision is still a usage error" {
    run bash "$SCRIPT" --force a b
    [ "$status" -eq 2 ]
}

# .:C24: the agent home is opt-in; --agent-home asks setup.sh for it.

@test "--agent-home appends --agent-home to the line (.:C24)" {
    run bash "$SCRIPT" --agent-home
    [ "$status" -eq 0 ]
    [ "$output" = "$(line_for "$HEAD_SHA") --agent-home" ]
    run bash "$SCRIPT" HEAD~1 --agent-home
    [ "$status" -eq 0 ]
    [ "$output" = "$(line_for "$FIRST") --agent-home" ]
}

@test "without --agent-home the line asks for no agent home (.:C24)" {
    run bash "$SCRIPT"
    [[ "$output" != *"--agent-home"* ]]
}

@test "--agent-home with --force still warns and prints the opt-in line (.:C24)" {
    GH_JSON='[]' run --separate-stderr bash "$SCRIPT" --force --agent-home
    [ "$status" -eq 0 ]
    [ "$output" = "$(line_for "$HEAD_SHA") --agent-home" ]
    [[ "$stderr" == *"no CI run"* ]]
}

# scripts:T81 (review R3-21): tell why gh could not answer.

@test "gh not signed in: says so and how to sign in, not a 404" {
    GH_AUTH_RC=1 run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not signed in"* ]]
    [[ "$output" == *"gh auth login"* ]]
    [[ "$output" != *"404"* ]]
    [[ "$output" != *"curl"* ]]
}

@test "gh answers 404: names the repo and workflow, not the sign-in" {
    GH_AUTH_RC=0 GH_RC=1 GH_ERR='HTTP 404: Not Found (https://api.github.com/repos/pr0d1r2/claudinix/actions/workflows/ci.yml/runs)' \
        run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"404"* ]]
    [[ "$output" == *"pr0d1r2/claudinix"* ]]
    [[ "$output" == *"ci.yml"* ]]
    [[ "$output" != *"signed in"* ]]
    [[ "$output" != *"curl"* ]]
}

@test "gh fails another way: shows its own error line" {
    GH_AUTH_RC=0 GH_RC=1 GH_ERR='error connecting to api.github.com' run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"error connecting to api.github.com"* ]]
    [[ "$output" != *"signed in"* ]]
}

# scripts:V37, T113: a short SHA is a claudinix commit, so GitHub resolves
# it; local git may be the target project's repo.

FULL=0123456789abcdef0123456789abcdef01234567

@test "a short SHA outside any clone resolves on GitHub to the full SHA (V37)" {
    mkdir "$BATS_TEST_TMPDIR/plain"
    cd "$BATS_TEST_TMPDIR/plain" || exit 1
    GH_API_OUT="$FULL" GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" run bash "$SCRIPT" 0123456
    [ "$status" -eq 0 ]
    [ "$output" = "$(line_for "$FULL")" ]
    grep -q "^gh api repos/pr0d1r2/claudinix/commits/0123456" "$GH_LOG"
    grep -q -- "--commit $FULL " "$GH_LOG"
}

@test "a short SHA inside a clone still asks GitHub, not local git (V37)" {
    short="${HEAD_SHA:0:7}"
    GH_API_OUT="$FULL" run bash "$SCRIPT" "$short"
    [ "$status" -eq 0 ]
    [ "$output" = "$(line_for "$FULL")" ]
}

@test "a 39-hex SHA is short too; 40 hex needs no lookup (V37)" {
    GH_API_OUT="$FULL" run bash "$SCRIPT" "${FULL:0:39}"
    [ "$status" -eq 0 ]
    [ "$output" = "$(line_for "$FULL")" ]
    : >"$GH_LOG"
    run bash "$SCRIPT" "$FULL"
    run ! grep -q "^gh api" "$GH_LOG"
}

@test "GitHub cannot resolve a short SHA: exit 1 naming it, no line (V37, V26)" {
    GH_API_RC=1 run bash "$SCRIPT" abcdef1
    [ "$status" -eq 1 ]
    [[ "$output" == *"abcdef1"* ]]
    [[ "$output" == *"pr0d1r2/claudinix"* ]]
    [[ "$output" != *"curl"* ]]
}

@test "GitHub answers something that is not a full SHA: exit 1 naming it (V37)" {
    GH_API_OUT='not-a-sha' run bash "$SCRIPT" abcdef1
    [ "$status" -eq 1 ]
    [[ "$output" == *"abcdef1"* ]]
    [[ "$output" != *"curl"* ]]
}

@test "gh missing for a short SHA: exit 1 naming it and gh (V37)" {
    GH_BIN="$BATS_TEST_TMPDIR/no-such-gh" run bash "$SCRIPT" abcdef1
    [ "$status" -eq 1 ]
    [[ "$output" == *"abcdef1"* ]]
    [[ "$output" == *"no-such-gh"* ]]
    [[ "$output" != *"curl"* ]]
}
