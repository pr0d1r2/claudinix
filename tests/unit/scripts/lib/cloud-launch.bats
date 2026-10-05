#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/lib/cloud-launch.sh, the launch rules that
# cloud-task.sh, cloud-rebase.sh and cloud-review.sh share (SPEC
# scripts:I.cmd, scripts:B19). claude and script are stubs; git is real,
# in a throwaway repository.

setup() {
    REPO="$BATS_TEST_DIRNAME/../../../.."
    LIB="$REPO/scripts/lib/cloud-launch.sh"
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_EXEC_PATH
    export STATE="$BATS_TEST_TMPDIR/state"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    mkdir -p "$STATE" "$STUBS"
    # claude: records its prompt and model.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'printf "%s" "$2" >"$STATE/claude.prompt"' \
        'printf "%s" "$4" >"$STATE/claude.model"' >"$STUBS/claude"
    # script: BSD form, as on macOS.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        '[ "$1" != --version ] || exit 1' \
        'while [ "$1" != /dev/null ]; do shift; done; shift; exec "$@"' >"$STUBS/script"
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"
    # shellcheck source=/dev/null
    source "$LIB"
}

# repo_with_upstream: a clone of a bare repository, one commit pushed.
repo_with_upstream() {
    git init -q --bare "$BATS_TEST_TMPDIR/origin.git"
    git clone -q "$BATS_TEST_TMPDIR/origin.git" "$BATS_TEST_TMPDIR/work" 2>/dev/null
    cd "$BATS_TEST_TMPDIR/work" || return 1
    git config user.email t@t
    git config user.name t
    git checkout -q -b main
    git commit -q --allow-empty -m one
    git push -q -u origin main 2>/dev/null
}

@test "cloud_fill replaces every key and keeps the value as written" {
    # shellcheck disable=SC2016 # the literal text, not an expansion
    local value='x & "y" $z'
    prompt='a @K@ b @K@'
    cloud_fill @K@ "$value"
    [ "$prompt" = "a $value b $value" ]
}

@test "cloud_fill does not fill a placeholder spelled in its own value" {
    prompt='@A@ @B@'
    cloud_fill @A@ '@B@'
    [ "$prompt" = '@B@ @B@' ]
}

@test "cloud_require_remote: a missing remote says to push the project first" {
    repo_with_upstream
    run cloud_require_remote review origin
    [ "$status" -eq 0 ]
    run cloud_require_remote review nowhere
    [ "$status" -eq 1 ]
    [ "$output" = "review: no remote nowhere -- push the project to GitHub first" ]
}

@test "cloud_require_pushed_branch: pushed and equal passes, the branch is named" {
    repo_with_upstream
    current=
    cloud_require_pushed_branch cloud origin
    [ "$current" = main ]
}

@test "cloud_require_pushed_branch: detached, no upstream, behind each refuse" {
    repo_with_upstream
    git checkout -q -b local
    run cloud_require_pushed_branch cloud origin
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud: branch local is not pushed (no upstream) -- push it first: git push -u origin local"* ]]
    git checkout -q main
    git commit -q --allow-empty -m two
    run cloud_require_pushed_branch cloud origin
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud: branch main is not up to date with origin/main"* ]]
    git checkout -q --detach
    run cloud_require_pushed_branch cloud origin
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud: HEAD is detached"* ]]
}

@test "cloud_resolve_model: --model wins, else config.sh says it" {
    model=opus
    cloud_resolve_model "$REPO/scripts"
    [ "$model" = opus ]
    model=
    cd "$BATS_TEST_TMPDIR" || return 1
    cloud_resolve_model "$REPO/scripts"
    [ "$model" = sonnet ]
}

@test "cloud_confirm: y starts, anything else says not started" {
    run cloud_confirm review 'Start? ' <<<"y"
    [ "$status" -eq 0 ]
    run cloud_confirm review 'Start? ' <<<""
    [ "$status" -eq 1 ]
    [[ "$output" == *"Start? "* ]]
    [[ "$output" == *"review: not started"* ]]
}

@test "cloud_launch hands claude the prompt and model through script" {
    cloud_launch 'do it & more' opus
    [ "$(cat "$STATE/claude.prompt")" = 'do it & more' ]
    [ "$(cat "$STATE/claude.model")" = opus ]
}

@test "cloud_launch passes claude's failure on" {
    printf '%s\n' '#!/usr/bin/env bash' 'exit 3' >"$STUBS/claude"
    run cloud_launch p m
    [ "$status" -ne 0 ]
}

@test "the heading constants are the ones the review and fixup prompts tell the session to use" {
    # shellcheck source=/dev/null
    source "$LIB"
    grep -qF "\"$CLOUD_REVIEW_HEADING @ROLE@\"" "$REPO/scripts/cloud-review-prompt.txt"
    grep -qF "\"$CLOUD_FIXUP_HEADING\"" "$REPO/scripts/cloud-fixup-prompt.txt"
}

@test "cloud_roles lists the role files of a directory, by name, and skips what is not a file" {
    # shellcheck source=/dev/null
    source "$LIB"
    mkdir -p "$BATS_TEST_TMPDIR/review/dir.md"
    : >"$BATS_TEST_TMPDIR/review/beta.md"
    : >"$BATS_TEST_TMPDIR/review/alpha.md"
    : >"$BATS_TEST_TMPDIR/review/notes.txt"
    run cloud_roles "$BATS_TEST_TMPDIR/review"
    [ "$status" -eq 0 ]
    [ "$output" = "alpha
beta" ]
}

@test "cloud_roles prints nothing for a directory without role files" {
    # shellcheck source=/dev/null
    source "$LIB"
    mkdir -p "$BATS_TEST_TMPDIR/empty"
    run cloud_roles "$BATS_TEST_TMPDIR/empty"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
