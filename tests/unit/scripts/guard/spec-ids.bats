#!/usr/bin/env bats
# Unit tests for scripts/guard/spec-ids.sh (SPEC scripts:T173, B91): an id
# (T V B C) defined in a SPEC*.md at the merge base stays defined in one at
# HEAD, and an id an ARCHIVED pointer names exists in that node's archive.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/guard/spec-ids.sh"
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_PREFIX
    unset SPEC_IDS_BASE
    REPO="$BATS_TEST_TMPDIR/repo"
    git init -q -b main "$REPO"
    cd "$REPO" || exit 1
    git config user.email t@example.invalid
    git config user.name t
    git config commit.gpgsign false
    mkdir node
    cat >node/SPEC.md <<'SPEC'
## §T TASKS

id|status|task|cites
T1|.|one|-
T2|x|ARCHIVED to SPEC-ARCHIVE.md|-

## §V

V1: inv

## §B

id|date|cause|fix
B1|d|c|f
B2|d|c|f
B3|d|c|f
B9|d|c|f

B1-B3, B9: ARCHIVED to SPEC-ARCHIVE.md `## §B BUGS`

## §C

- C1: con
SPEC
    cat >node/SPEC-ARCHIVE.md <<'SPEC'
## §T TASKS

T2|x|old|-

## §B BUGS

id|date|cause|fix
B1|d|c|f
B2|d|c|f
B3|d|c|f
B9|d|c|f
SPEC
    git add .
    git commit -q -m "chore: specs"
    git update-ref refs/remotes/origin/main HEAD
    git switch -q -c work
}

# edit FILE SED-ARGS...: apply the sed arguments to FILE and commit it.
edit() {
    sed "${@:2}" "$1" >"$BATS_TEST_TMPDIR/edit"
    cat "$BATS_TEST_TMPDIR/edit" >"$1"
    git add "$1"
    git commit -q -m "chore: edit"
}

@test "an unchanged branch passes silently" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a row added on the branch passes" {
    edit node/SPEC.md 's/^T1|.*/&\nT3|.|three|-/'
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "a vanished task id fails and names it (B91)" {
    edit node/SPEC.md '/^T1|/d'
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'T1'* ]]
    [[ "$output" == *'node/SPEC.md'* ]]
}

@test "a vanished invariant, bug and constraint id are each named" {
    edit node/SPEC.md -e '/^V1:/d' -e '/^- C1:/d'
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'V1'* ]]
    [[ "$output" == *'C1'* ]]
}

@test "an id moved to another node's spec passes" {
    mkdir other
    printf 'T1|.|one|-\n' >other/SPEC.md
    git add other
    git commit -q -m "chore: other"
    edit node/SPEC.md '/^T1|/d'
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "a row replaced by an ARCHIVED row passes while the archive has it" {
    edit node/SPEC.md 's/^T1|.*/T1|x|ARCHIVED to SPEC-ARCHIVE.md|-/'
    printf 'T1|x|one|-\n' >>node/SPEC-ARCHIVE.md
    git add node/SPEC-ARCHIVE.md
    git commit -q -m "chore: archive"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "an ARCHIVED row whose archive lacks the id fails, naming it" {
    edit node/SPEC.md 's/^T1|.*/T1|x|ARCHIVED to SPEC-ARCHIVE.md|-/'
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'T1'* ]]
    [[ "$output" == *'node/SPEC-ARCHIVE.md'* ]]
}

@test "a bug row dropped from the archive fails though the pointer range stays (B91)" {
    edit node/SPEC-ARCHIVE.md '/^B2|/d'
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'B2'* ]]
    [[ "$output" != *'B1'* ]]
}

@test "a pointer range that covers a vanished base row passes while the archive has it" {
    printf 'B4|d|c|f\n' >>node/SPEC-ARCHIVE.md
    printf 'B4|d|c|f\n' >>node/SPEC.md
    git add node
    git commit -q -m "chore: b4"
    git update-ref refs/remotes/origin/main HEAD
    edit node/SPEC.md -e '/^B4|/d' -e 's/^B1-B3, B9:/B1-B4, B9:/'
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "the base is the merge base, so rows added upstream later do not count" {
    git switch -q main
    printf 'T7|.|seven|-\n' >>node/SPEC.md
    git add node
    git commit -q -m "chore: upstream"
    git update-ref refs/remotes/origin/main HEAD
    git switch -q work
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "the base is an argument" {
    edit node/SPEC.md '/^T1|/d'
    run bash "$SCRIPT" refs/remotes/origin/main
    [ "$status" -eq 1 ]
}

@test "an unresolvable base fails: nothing was checked" {
    run bash "$SCRIPT" no-such-ref
    [ "$status" -eq 1 ]
    [[ "$output" == *'no-such-ref'* ]]
}

@test "too many arguments is a usage error" {
    run bash "$SCRIPT" a b
    [ "$status" -eq 2 ]
}

@test "the repo's own specs pass against their own history" {
    cd "$BATS_TEST_DIRNAME/../../../.."
    run bash "$SCRIPT" HEAD
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a pointer in a node with no archive fails, naming the id (B95)" {
    git rm -q node/SPEC-ARCHIVE.md
    git commit -q -m "chore: drop archive"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'T2 is archived by a pointer in node/SPEC.md'* ]]
}

@test "a pointer to an archive that defines no ids fails, naming the id (B95)" {
    : >node/SPEC-ARCHIVE.md
    git add node/SPEC-ARCHIVE.md
    git commit -q -m "chore: empty archive"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'T2 is archived by a pointer in node/SPEC.md'* ]]
}
