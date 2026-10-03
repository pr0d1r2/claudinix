#!/usr/bin/env bats
# Unit tests for scripts/dev/session-start.sh (SPEC T76, C27, V17, V29, V21).

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/dev/session-start.sh"
    BASH_BIN="$(command -v bash)"
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    NIX_LOG="$BATS_TEST_TMPDIR/nix.log"
    mkdir -p "$STUB_BIN"
    ln -s "$(command -v git)" "$STUB_BIN/git"
    export NIX_LOG
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_PREFIX
    ORIGIN="$BATS_TEST_TMPDIR/origin"
    git init -q "$ORIGIN"
    git -C "$ORIGIN" config user.email t@example.invalid
    git -C "$ORIGIN" config user.name t
    git -C "$ORIGIN" config commit.gpgsign false
    git -C "$ORIGIN" commit -q --allow-empty -m "chore: one"
    git -C "$ORIGIN" commit -q --allow-empty -m "chore: two"
    REPO="$BATS_TEST_TMPDIR/repo"
}

# stub_nix RC: a nix that logs its arguments, chatters, and exits RC.
stub_nix() {
    # shellcheck disable=SC2016 # $* and $NIX_LOG expand inside the stub
    printf '#!%s\necho "$*" >>"$NIX_LOG"\necho "nix chatter"\necho "nix stderr chatter" >&2\nexit %s\n' "$BASH_BIN" "$1" >"$STUB_BIN/nix"
    chmod +x "$STUB_BIN/nix"
}

cloud() {
    run env PATH="$STUB_BIN" CLAUDE_CODE_REMOTE=true "$BASH_BIN" "$SCRIPT"
}

@test "shallow cloud clone: unshallowed, dev shell entered, silent (C27)" {
    stub_nix 0
    git clone -q --depth 1 "file://$ORIGIN" "$REPO"
    cd "$REPO"
    [ "$(git rev-parse --is-shallow-repository)" = true ]
    cloud
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ "$(git rev-parse --is-shallow-repository)" = false ]
    [ "$(cat "$NIX_LOG")" = "develop -c true" ]
}

@test "full clone: no fetch, dev shell entered, silent" {
    stub_nix 0
    git clone -q "file://$ORIGIN" "$REPO"
    cd "$REPO"
    rm -rf "$ORIGIN"
    cloud
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ "$(cat "$NIX_LOG")" = "develop -c true" ]
}

@test "unshallow failing: warns with the fix, still enters the shell, exits 0" {
    stub_nix 0
    git clone -q --depth 1 "file://$ORIGIN" "$REPO"
    cd "$REPO"
    rm -rf "$ORIGIN"
    cloud
    [ "$status" -eq 0 ]
    [[ "$output" == *"still shallow"* ]]
    [[ "$output" == *"git fetch --unshallow"* ]]
    [ "$(cat "$NIX_LOG")" = "develop -c true" ]
}

@test "nix develop failing: warns with its output, exits 0" {
    stub_nix 5
    git clone -q "file://$ORIGIN" "$REPO"
    cd "$REPO"
    cloud
    [ "$status" -eq 0 ]
    [[ "$output" == *"nix develop failed"* ]]
    [[ "$output" == *"nix stderr chatter"* ]]
    [[ "$output" == *"hooks"* ]]
}

@test "nix-dev on PATH: the dev shell is entered through it, silent (C6 403s)" {
    stub_nix 0
    # shellcheck disable=SC2016 # $* and $NIX_LOG expand inside the stub
    printf '#!%s\necho "nix-dev $*" >>"$NIX_LOG"\necho "nix-dev: tier 1" >&2\n' "$BASH_BIN" >"$STUB_BIN/nix-dev"
    chmod +x "$STUB_BIN/nix-dev"
    git clone -q "file://$ORIGIN" "$REPO"
    cd "$REPO"
    cloud
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ "$(cat "$NIX_LOG")" = "nix-dev -c true" ]
}

@test "nix-dev failing: warns with its output, exits 0" {
    stub_nix 0
    printf '#!%s\necho "nix-dev: tier 4 failed" >&2\nexit 1\n' "$BASH_BIN" >"$STUB_BIN/nix-dev"
    chmod +x "$STUB_BIN/nix-dev"
    git clone -q "file://$ORIGIN" "$REPO"
    cd "$REPO"
    cloud
    [ "$status" -eq 0 ]
    [[ "$output" == *"nix-dev -c true"* ]]
    [[ "$output" == *"tier 4 failed"* ]]
}

@test "nix missing: warns and exits 0" {
    git clone -q "file://$ORIGIN" "$REPO"
    cd "$REPO"
    cloud
    [ "$status" -eq 0 ]
    [[ "$output" == *"nix not on PATH"* ]]
}

@test "not a git repository: warns and exits 0, nix never runs" {
    stub_nix 0
    cd "$BATS_TEST_TMPDIR"
    run env PATH="$STUB_BIN" CLAUDE_CODE_REMOTE=true GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"not a git repository"* ]]
    [ ! -e "$NIX_LOG" ]
}

@test "outside a cloud session: does nothing (direnv covers local work)" {
    stub_nix 0
    git clone -q --depth 1 "file://$ORIGIN" "$REPO"
    cd "$REPO"
    run env -u CLAUDE_CODE_REMOTE PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -e "$NIX_LOG" ]
    [ "$(git rev-parse --is-shallow-repository)" = true ]
}

@test "the repo's SessionStart hook runs this script by \$CLAUDE_PROJECT_DIR (C27)" {
    settings="$BATS_TEST_DIRNAME/../../../../.claude/settings.json"
    # A relative path breaks when the session starts in a subdirectory;
    # the hooks docs anchor project scripts on $CLAUDE_PROJECT_DIR.
    run jq -r '.hooks.SessionStart[].hooks[] | "\(.type) \(.timeout) \(.command)"' "$settings"
    [ "$status" -eq 0 ]
    # shellcheck disable=SC2016 # the literal command text, expanded by Claude Code
    [ "$output" = 'command 600 bash "$CLAUDE_PROJECT_DIR/scripts/dev/session-start.sh"' ]
}

# The opt-in fallback route for the cloud permissions (.:T101): the
# SessionStart hook writes nix/cloud-permissions.json into the gitignored
# .claude/settings.local.json.

# with_jq: jq, and the coreutils a file write needs, on the stub PATH.
with_jq() {
    local tool
    for tool in jq mkdir mv; do
        ln -s "$(command -v "$tool")" "$STUB_BIN/$tool"
    done
}

cloud_permissions() {
    run env PATH="$STUB_BIN" CLAUDE_CODE_REMOTE=true CLAUDINIX_SESSION_PERMISSIONS=1 "$BASH_BIN" "$SCRIPT"
}

list() {
    echo "$BATS_TEST_DIRNAME/../../../../nix/cloud-permissions.json"
}

@test "permissions fallback is off by default: no settings.local.json (.:T101)" {
    stub_nix 0
    with_jq
    git clone -q "file://$ORIGIN" "$REPO"
    cd "$REPO"
    cloud
    [ "$status" -eq 0 ]
    [ ! -e "$REPO/.claude/settings.local.json" ]
}

@test "permissions fallback on in cloud: writes exactly the list, silent" {
    stub_nix 0
    with_jq
    git clone -q "file://$ORIGIN" "$REPO"
    cd "$REPO"
    cloud_permissions
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run jq -e --slurpfile want "$(list)" '.permissions == $want[0]' "$REPO/.claude/settings.local.json"
    [ "$status" -eq 0 ]
}

@test "permissions fallback never runs outside a cloud session" {
    stub_nix 0
    with_jq
    git clone -q "file://$ORIGIN" "$REPO"
    cd "$REPO"
    run env -u CLAUDE_CODE_REMOTE PATH="$STUB_BIN" CLAUDINIX_SESSION_PERMISSIONS=1 "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [ ! -e "$REPO/.claude/settings.local.json" ]
}

@test "permissions fallback merges: keeps keys and rules it did not write, no duplicates" {
    stub_nix 0
    with_jq
    git clone -q "file://$ORIGIN" "$REPO"
    mkdir -p "$REPO/.claude"
    echo '{"env":{"A":"1"},"permissions":{"allow":["Bash(ls)","Bash(bats *)"],"ask":["Bash(rm *)"]}}' >"$REPO/.claude/settings.local.json"
    cd "$REPO"
    cloud_permissions
    [ "$status" -eq 0 ]
    cloud_permissions
    [ "$status" -eq 0 ]
    run jq -e --slurpfile want "$(list)" '
        .env == {"A": "1"}
        and .permissions.ask == ["Bash(rm *)"]
        and (.permissions.allow | index("Bash(ls)")) != null
        and (($want[0].allow - .permissions.allow) == [])
        and (($want[0].deny - .permissions.deny) == [])
        and (.permissions.allow | length == (unique | length))
        and (.permissions.deny | length == (unique | length))
    ' "$REPO/.claude/settings.local.json"
    [ "$status" -eq 0 ]
}

@test "permissions fallback: an unreadable local file is left alone, warns, exits 0" {
    stub_nix 0
    with_jq
    git clone -q "file://$ORIGIN" "$REPO"
    mkdir -p "$REPO/.claude"
    echo 'not json' >"$REPO/.claude/settings.local.json"
    cd "$REPO"
    cloud_permissions
    [ "$status" -eq 0 ]
    [[ "$output" == *"settings.local.json"* ]]
    [ "$(cat "$REPO/.claude/settings.local.json")" = "not json" ]
}

@test "permissions fallback without jq: warns, still enters the shell, exits 0" {
    stub_nix 0
    git clone -q "file://$ORIGIN" "$REPO"
    cd "$REPO"
    cloud_permissions
    [ "$status" -eq 0 ]
    [[ "$output" == *"jq"* ]]
    [ ! -e "$REPO/.claude/settings.local.json" ]
    [ "$(cat "$NIX_LOG")" = "develop -c true" ]
}

@test "the fallback's file is gitignored in this repo (never committed)" {
    cd "$BATS_TEST_DIRNAME/../../../.."
    run git check-ignore -q .claude/settings.local.json
    [ "$status" -eq 0 ]
}
