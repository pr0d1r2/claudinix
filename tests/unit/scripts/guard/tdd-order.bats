#!/usr/bin/env bats
# Unit tests for scripts/guard/tdd-order.sh (SPEC T19, C17, V21).

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/guard/tdd-order.sh"
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_PREFIX
    REPO="$BATS_TEST_TMPDIR/repo"
    git init -q "$REPO"
    cd "$REPO" || exit 1
    git config user.email t@example.invalid
    git config user.name t
    git config commit.gpgsign false
    git commit -q --allow-empty -m "chore: root"
}

commit_file() {
    mkdir -p "$(dirname "$1")"
    echo "$2" >>"$1"
    git add "$1"
    git commit -q -m "${3:-chore: $1}"
}

@test "test committed before script passes" {
    commit_file tests/unit/scripts/x/a.bats one
    commit_file scripts/x/a.sh one
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "root script after its test passes" {
    commit_file tests/unit/setup.bats one
    commit_file setup.sh one
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "script before its test fails and names the commit" {
    commit_file scripts/x/a.sh one
    bad="$(git rev-parse --short HEAD)"
    commit_file tests/unit/scripts/x/a.bats one
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$bad"* ]]
    [[ "$output" == *"scripts/x/a.sh"* ]]
}

@test "script and test in the same commit fails (no RED step)" {
    mkdir -p scripts/x tests/unit/scripts/x
    echo one >scripts/x/a.sh
    echo one >tests/unit/scripts/x/a.bats
    git add .
    git commit -q -m "feat: both at once"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"SAME commit"* ]]
}

@test "modifying a script whose test exists passes (REFACTOR)" {
    commit_file tests/unit/scripts/b.bats one
    commit_file scripts/b.sh one
    commit_file scripts/b.sh two
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "a rename with its test renamed first passes (-M)" {
    commit_file tests/unit/scripts/old.bats one
    mkdir -p scripts
    printf 'line %s\n' 1 2 3 4 5 6 7 8 >>scripts/old.sh
    git add scripts/old.sh
    git commit -q -m "feat: old"
    git mv tests/unit/scripts/old.bats tests/unit/scripts/new.bats
    git commit -q -m "test: rename"
    git mv scripts/old.sh scripts/new.sh
    git commit -q -m "refactor: rename"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "range argument limits the check" {
    commit_file scripts/x/old.sh one
    commit_file tests/unit/scripts/x/old.bats one
    base="$(git rev-parse HEAD)"
    commit_file tests/unit/scripts/x/new.bats one
    commit_file scripts/x/new.sh one
    run bash "$SCRIPT" "$base..HEAD"
    [ "$status" -eq 0 ]
}

@test "unresolvable range fails rather than passes" {
    run bash "$SCRIPT" "nope..HEAD"
    [ "$status" -eq 1 ]
    [[ "$output" == *"nothing was checked"* ]]
}

# clone_from ORIGIN DEST [GIT_CLONE_ARG...]: a fixture clone that can commit.
clone_from() {
    local origin="$1" dest="$2"
    shift 2
    git clone -q "$@" "file://$origin" "$dest"
    git -C "$dest" config user.email t@example.invalid
    git -C "$dest" config user.name t
    git -C "$dest" config commit.gpgsign false
}

@test "a shallow clone fails, says so and names the fix (B7, V29)" {
    commit_file tests/unit/scripts/x/a.bats one
    commit_file scripts/x/a.sh one
    clone_from "$REPO" "$BATS_TEST_TMPDIR/shallow" --depth 1
    cd "$BATS_TEST_TMPDIR/shallow"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"this clone is shallow"* ]]
    [[ "$output" == *"run: git fetch --unshallow"* ]]
    # It must not blame the graft commit for adding every script.
    [[ "$output" != *"commit the failing test first"* ]]
}

@test "no upstream: checks only merge-base HEAD origin/HEAD..HEAD (V29)" {
    # An old violation on the default branch is history, not this branch.
    commit_file scripts/x/old.sh one
    commit_file tests/unit/scripts/x/old.bats one
    clone_from "$REPO" "$BATS_TEST_TMPDIR/clone"
    cd "$BATS_TEST_TMPDIR/clone"
    git rev-parse --verify --quiet refs/remotes/origin/HEAD >/dev/null
    git switch -q --no-track -c feature
    commit_file tests/unit/scripts/x/new.bats one
    commit_file scripts/x/new.sh one
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "no upstream: a violation on the branch is still caught" {
    clone_from "$REPO" "$BATS_TEST_TMPDIR/clone"
    cd "$BATS_TEST_TMPDIR/clone"
    git switch -q --no-track -c feature
    commit_file scripts/x/new.sh one
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"scripts/x/new.sh"* ]]
}

@test "refusal prints a split recipe that needs no interactive rebase" {
    mkdir -p scripts/x tests/unit/scripts/x
    echo one >scripts/x/a.sh
    echo one >tests/unit/scripts/x/a.bats
    git add .
    git commit -q -m "feat: both at once"
    bad="$(git rev-parse --short HEAD)"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"git switch -c tdd-split $bad^"* ]]
    [[ "$output" == *"git restore --source=$bad --staged --worktree -- tests/unit/scripts/x/a.bats"* ]]
    [[ "$output" == *"git commit -C $bad"* ]]
    [[ "$output" != *"rebase -i"* ]]
}

@test "the split recipe, run as printed, satisfies the guard" {
    commit_file README one
    mkdir -p scripts/x tests/unit/scripts/x
    echo one >scripts/x/a.sh
    echo one >tests/unit/scripts/x/a.bats
    git add .
    git commit -q -m "feat: both at once"
    commit_file README two
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    recipe="$BATS_TEST_TMPDIR/recipe.sh"
    printf '%s\n' "$output" | sed -n 's/^    \(git .*\)$/\1/p' >"$recipe"
    [ -s "$recipe" ]
    run bash -e "$recipe"
    [ "$status" -eq 0 ]
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(cat README)" = "$(printf 'one\ntwo')" ]
}
