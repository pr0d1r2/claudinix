#!/usr/bin/env bats
# Unit tests for scripts/dev/shell-hook.sh (SPEC T1, V17, V21).

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/dev/shell-hook.sh"
    BASH_BIN="$(command -v bash)"
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    HK_LOG="$BATS_TEST_TMPDIR/hk.log"
    mkdir -p "$STUB_BIN"
    ln -s "$(command -v git)" "$STUB_BIN/git"
    export HK_LOG
    # The suite itself runs inside a wrapped git hook, which sets this; left
    # set, every test would see the script's in-a-hook early exit.
    unset CLAUDINIX_HOOK
    # The suite also runs from git hooks, which export GIT_DIR and friends;
    # left set, every fixture repo would resolve to this one (V21).
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_PREFIX
}

stub_hk() {
    local rc="${1:-0}"
    # shellcheck disable=SC2016 # $* and $HK_LOG expand inside the stub, not here
    printf '#!%s\necho "$*" >>"$HK_LOG"\nexit %s\n' "$BASH_BIN" "$rc" >"$STUB_BIN/hk"
    chmod +x "$STUB_BIN/hk"
}

make_repo() {
    REPO="$BATS_TEST_TMPDIR/repo"
    git init -q "$REPO"
}

@test "outside a git repository: warns, exits 0, never calls hk" {
    stub_hk
    cd "$BATS_TEST_TMPDIR"
    run env PATH="$STUB_BIN" GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"not a git repository"* ]]
    [ ! -e "$HK_LOG" ]
}

@test "hk missing from PATH: warns and exits 0" {
    make_repo
    cd "$REPO"
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"hk not on PATH"* ]]
}

@test "inside a git repository: runs hk install" {
    stub_hk
    make_repo
    cd "$REPO"
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(cat "$HK_LOG")" = "install" ]
}

@test "idempotent: a second shell entry installs again and still exits 0" {
    stub_hk
    make_repo
    cd "$REPO"
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(grep -c '^install$' "$HK_LOG")" -eq 2 ]
}

@test "hk install failing: warns but never breaks the dev shell" {
    stub_hk 3
    make_repo
    cd "$REPO"
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"hk install failed"* ]]
}

# An hk stub whose `install` writes config-based hooks the way hk 1.58 does.
stub_hk_installer() {
    # shellcheck disable=SC2016 # the hook commands are literal text for git config
    cat >"$STUB_BIN/hk" <<STUB
#!$BASH_BIN
echo "\$*" >>"\$HK_LOG"
for e in pre-commit pre-push commit-msg; do
    git config --local "hook.hk-\$e.command" 'test "\${HK:-1}" = "0" || hk run '"\$e"' --from-hook'
done
STUB
    chmod +x "$STUB_BIN/hk"
}

@test "wraps every hk hook so it enters the dev shell, keeping the HK=0 escape (V17)" {
    stub_hk_installer
    make_repo
    cd "$REPO"
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    for e in pre-commit pre-push commit-msg; do
        # shellcheck disable=SC2016 # ${HK:-1} is literal hook text, not expanded here
        [ "$(git config --local "hook.hk-$e.command")" = 'test "${HK:-1}" = "0" || CLAUDINIX_HOOK=1 nix develop -c hk run '"$e"' --from-hook' ]
    done
}

@test "a second shell entry does not wrap twice" {
    stub_hk_installer
    make_repo
    cd "$REPO"
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(git config --local hook.hk-pre-push.command | grep -o 'nix develop' | wc -l | tr -d ' ')" = 1 ]
}

@test "inside a hook the shell hook does nothing (no reinstall, no noise)" {
    stub_hk_installer
    make_repo
    cd "$REPO"
    run env PATH="$STUB_BIN" CLAUDINIX_HOOK=1 "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -e "$HK_LOG" ]
}

@test "config locked by a concurrent writer: warns, exits 0, never corrupts" {
    stub_hk_installer
    make_repo
    cd "$REPO"
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    : >"$REPO/.git/config.lock"
    git config --local hook.hk-pre-push.command 'unwrapped' 2>/dev/null || true
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"could not"* || "$output" == *"hook"* ]]
    rm -f "$REPO/.git/config.lock"
    git config --local --get-regexp '^hook\.hk-' >/dev/null
}
