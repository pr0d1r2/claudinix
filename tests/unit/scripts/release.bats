#!/usr/bin/env bats
# Unit tests for scripts/release.sh (SPEC T75, C25, nix:V15, V20, V21).

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../scripts/release.sh"
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_PREFIX
    REPO="$BATS_TEST_TMPDIR/repo"
    git init -q "$REPO"
    cd "$REPO" || exit 1
    git config user.email t@example.invalid
    git config user.name t
    git config commit.gpgsign false
    printf '# t\n\n<!-- BEGIN setup-line -->\n<!-- END setup-line -->\n' >README.md
    git add README.md
    git commit -q -m "chore: root"
    SHA="$(git rev-parse HEAD)"
    BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$BIN"
    LOG="$BATS_TEST_TMPDIR/calls.log"
    export LOG
    export SETUP_LINE="$BIN/setup-line"
    export RECORD_STOREPATH="$BIN/record-storepath"
    export README_FILE="$REPO/README.md"
    export CLOUD_HOME_STOREPATH="$REPO/cloud-home.storepath"
    stub_setup_line 0
    stub_record 0
}

# stub_setup_line RC: logs its args; prints a line on 0, refuses otherwise.
stub_setup_line() {
    # shellcheck disable=SC2016 # expands inside the stub
    printf '#!/usr/bin/env bash\necho "setup-line $*" >>"$LOG"\nif [ %s = 0 ]; then echo "LINE-FOR-$1"; else echo "setup-line: CI on main for $1 is not green" >&2; exit %s; fi\n' "$1" "$1" >"$SETUP_LINE"
    chmod +x "$SETUP_LINE"
}

# stub_record RC: logs its args; writes the storepath file on 0.
stub_record() {
    # shellcheck disable=SC2016 # expands inside the stub
    printf '#!/usr/bin/env bash\necho "record $*" >>"$LOG"\nif [ %s = 0 ]; then echo /nix/store/abc-home >"$CLOUD_HOME_STOREPATH"; echo "record-storepath: recorded"; else echo "record-storepath: narinfo HTTP 404" >&2; exit %s; fi\n' "$1" "$1" >"$RECORD_STOREPATH"
    chmod +x "$RECORD_STOREPATH"
}

@test "green CI and cached home: records, regenerates the README, prints notes" {
    run bash "$SCRIPT" "$SHA"
    [ "$status" -eq 0 ]
    [ "$(cat cloud-home.storepath)" = /nix/store/abc-home ]
    grep -qF "raw.githubusercontent.com/pr0d1r2/claudinix/$SHA/setup.sh" README.md
    [[ "$output" == *"https://raw.githubusercontent.com/pr0d1r2/claudinix/$SHA/setup.sh"* ]]
    [[ "$output" == *'```sh'* ]]
}

@test "the README it writes passes the gate's block check" {
    run bash "$SCRIPT" "$SHA"
    [ "$status" -eq 0 ]
    run bash "$BATS_TEST_DIRNAME/../../../scripts/guard/readme-setup-line.sh"
    [ "$status" -eq 0 ]
}

@test "default REV is HEAD" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    grep -qx "setup-line $SHA" "$LOG"
}

@test "asks setup-line.sh about CI for the full SHA, without --force" {
    run bash "$SCRIPT" HEAD
    [ "$status" -eq 0 ]
    grep -qx "setup-line $SHA" "$LOG"
    [ "$(grep -c -- --force "$LOG")" = 0 ]
}

@test "records the agent home of the release commit, not the worktree" {
    run bash "$SCRIPT" "$SHA"
    [ "$status" -eq 0 ]
    grep -qx "record git+file://$REPO?rev=$SHA" "$LOG"
}

@test "CI not green: refuses, records nothing, README untouched" {
    stub_setup_line 1
    before="$(cat README.md)"
    run bash "$SCRIPT" "$SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not green"* ]]
    [[ "$output" == *"nothing was released"* ]]
    [ ! -e cloud-home.storepath ]
    [ "$(cat README.md)" = "$before" ]
    [ "$(grep -c '^record' "$LOG")" = 0 ]
}

@test "agent home not in the cache: refuses, README untouched" {
    stub_record 1
    before="$(cat README.md)"
    run bash "$SCRIPT" "$SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"narinfo"* ]]
    [[ "$output" == *"nothing was released"* ]]
    [ "$(cat README.md)" = "$before" ]
}

@test "never commits, tags or pushes; prints the commands instead" {
    commits="$(git rev-list --count HEAD)"
    run bash "$SCRIPT" "$SHA"
    [ "$status" -eq 0 ]
    [ "$(git rev-list --count HEAD)" = "$commits" ]
    [ -z "$(git tag)" ]
    [[ "$output" == *"git add cloud-home.storepath README.md"* ]]
    [[ "$output" == *"git commit"* ]]
    [[ "$output" == *"git push"* ]]
    [[ "$output" == *"gh release create"* ]]
}

@test "notes go to stdout, commands to stderr, so notes can be saved" {
    bash "$SCRIPT" "$SHA" >"$BATS_TEST_TMPDIR/notes.md" 2>"$BATS_TEST_TMPDIR/err"
    grep -qF "$SHA/setup.sh" "$BATS_TEST_TMPDIR/notes.md"
    [ "$(grep -c 'git push' "$BATS_TEST_TMPDIR/notes.md")" = 0 ]
    grep -q 'git push' "$BATS_TEST_TMPDIR/err"
}

@test "unresolvable REV fails before asking anything" {
    run bash "$SCRIPT" no-such-rev
    [ "$status" -eq 1 ]
    [ ! -e "$LOG" ]
}

@test "more than one argument is a usage error" {
    run bash "$SCRIPT" a b
    [ "$status" -eq 2 ]
}
