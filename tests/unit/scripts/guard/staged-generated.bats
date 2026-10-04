#!/usr/bin/env bats
# Unit tests for scripts/guard/staged-generated.sh (dev:T123, dev:V39, B18).

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/guard/staged-generated.sh"
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_PREFIX
    REPO="$BATS_TEST_TMPDIR/repo"
    git init -q "$REPO"
    cd "$REPO" || exit 1
    # A stand-in claudinix-dev: `<verb> --check --root DIR` passes when
    # DIR/<verb>.out reads "fresh", and logs every call.
    BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$BIN"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    cat >"$BIN/claudinix-dev" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CALLS"
[ "$(cat "$4/$1.out" 2>/dev/null)" = fresh ]
FAKE
    chmod +x "$BIN/claudinix-dev"
    export PATH="$BIN:$PATH"
}

# stage VERB CONTENT: stage VERB's output with CONTENT.
stage() {
    printf '%s\n' "$2" >"$1.out"
    git add "$1.out"
}

@test "outputs fresh in the index but stale in the worktree: passes" {
    stage badges fresh
    stage steps fresh
    printf 'stale\n' >badges.out
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "an output fresh in the worktree but stale in the index fails (B18)" {
    stage badges fresh
    stage steps stale
    printf 'fresh\n' >steps.out
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"claudinix-dev steps --write"* ]]
    [[ "$output" == *"git add"* ]]
    [[ "$output" != *"badges --write"* ]]
}

@test "checks badges and steps, each on the index snapshot" {
    stage badges fresh
    stage steps fresh
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    run cat "$CALLS"
    [ "${#lines[@]}" -eq 2 ]
    [[ "${lines[0]}" == "badges --check --root "* ]]
    [[ "${lines[1]}" == "steps --check --root "* ]]
    [[ "${lines[0]}" != *" --root $REPO" ]]
}

@test "both outputs stale in the index: fails naming both" {
    stage badges stale
    stage steps stale
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"badges --write"* ]]
    [[ "$output" == *"steps --write"* ]]
}

@test "the snapshot is removed afterwards" {
    stage badges fresh
    stage steps fresh
    export TMPDIR="$BATS_TEST_TMPDIR/tmp"
    mkdir -p "$TMPDIR"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$(ls -A "$TMPDIR")" ]
}

@test "claudinix-dev missing: fails, never passes unchecked" {
    stage badges fresh
    stage steps fresh
    CLAUDINIX_DEV=claudinix-dev-not-installed run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"claudinix-dev-not-installed"* ]]
}
