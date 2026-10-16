#!/usr/bin/env bats
# Unit tests for scripts/guard/context-limits.sh (SPEC scripts:T150,
# .:C20): a .context-limits row raised or added, or the file deleted, on
# the branch, against its merge base with origin/main, fails the gate;
# there is no override (B81).

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/guard/context-limits.sh"
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_PREFIX
    unset CONTEXT_LIMITS_BASE
    REPO="$BATS_TEST_TMPDIR/repo"
    git init -q -b main "$REPO"
    cd "$REPO" || exit 1
    git config user.email t@example.invalid
    git config user.name t
    git config commit.gpgsign false
    printf '# ceilings\n\nSPEC.md          8700\nscripts/SPEC.md  4200\n\nscripts 10400\n' >.context-limits
    git add .context-limits
    git commit -q -m "chore: limits"
    # origin/main as a cloud session or CI sees it.
    git update-ref refs/remotes/origin/main HEAD
    git switch -q -c work
}

# limits ROW VALUE [MESSAGE]: set ROW's ceiling to VALUE (adding the row
# when missing) and commit it with MESSAGE.
limits() {
    if grep -q "^$1 " .context-limits; then
        sed "s|^$1 .*|$1 $2|" .context-limits >"$BATS_TEST_TMPDIR/limits"
        mv "$BATS_TEST_TMPDIR/limits" .context-limits
    else
        echo "$1 $2" >>.context-limits
    fi
    git add .context-limits
    git commit -q -m "${3:-chore: limits}"
}

@test "a branch that leaves the ceilings alone passes silently" {
    echo x >other
    git add other
    git commit -q -m "chore: other"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "lowering a ceiling passes" {
    limits scripts/SPEC.md 4000
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a comment change passes" {
    sed 's/# ceilings/# ceilings, measured/' .context-limits >"$BATS_TEST_TMPDIR/limits"
    mv "$BATS_TEST_TMPDIR/limits" .context-limits
    git add .context-limits
    git commit -q -m "docs: note"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "a raised file row fails and names the row and both values" {
    limits scripts/SPEC.md 4600
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"raises the .context-limits row scripts/SPEC.md from 4200 to 4600"* ]]
}

@test "a raised chain row fails" {
    limits scripts 11000
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"raises the .context-limits row scripts from 10400 to 11000"* ]]
}

@test "an added row fails (cloud:V51 reads it the same way)" {
    limits newnode/SPEC.md 900
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"adds the .context-limits row newnode/SPEC.md 900"* ]]
}

@test "every raise is reported, not only the first" {
    limits scripts/SPEC.md 4600
    limits scripts 11000
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"scripts/SPEC.md from 4200 to 4600"* ]]
    [[ "$output" == *"scripts from 10400 to 11000"* ]]
}

@test "a raise lowered again on the branch passes" {
    limits scripts/SPEC.md 4600
    limits scripts/SPEC.md 4200
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "an Owner-Override trailer is no override: the owner raises on the merge side (B81)" {
    limits scripts/SPEC.md 4600 "$(printf 'chore: raise\n\nWhy: measured 4000.\n\nOwner-Override: context-limits')"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"raises the .context-limits row scripts/SPEC.md from 4200 to 4600"* ]]
    [[ "$output" != *"Owner-Override"* ]]
}

@test "deleting .context-limits fails: the ceilings are gone (B81)" {
    git rm -q .context-limits
    git commit -q -m "chore: drop limits"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"deletes .context-limits"* ]]
}

@test "the base is measured at the merge base, so main moving on is not a raise" {
    git switch -q main
    limits scripts/SPEC.md 5000
    git update-ref refs/remotes/origin/main HEAD
    git switch -q work
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "CONTEXT_LIMITS_BASE picks another base" {
    limits scripts/SPEC.md 4600
    git update-ref refs/remotes/upstream/main HEAD
    CONTEXT_LIMITS_BASE=upstream/main run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "a missing base fails, naming it (.:V18, scripts:V26)" {
    CONTEXT_LIMITS_BASE=nope/main run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"nope/main"* ]]
    [[ "$output" == *"nothing was checked"* ]]
}

@test "a shallow clone fails with the fix (scripts:V29)" {
    limits scripts/SPEC.md 4100
    git clone -q --depth 1 "file://$REPO" "$BATS_TEST_TMPDIR/shallow"
    cd "$BATS_TEST_TMPDIR/shallow" || exit 1
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"git fetch --unshallow"* ]]
}

@test "outside a git work tree fails" {
    cd "$BATS_TEST_TMPDIR" || exit 1
    mkdir plain
    cd plain || exit 1
    GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" run bash "$SCRIPT"
    [ "$status" -eq 1 ]
}

@test "more than one argument is a usage error" {
    run bash "$SCRIPT" a b
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}
