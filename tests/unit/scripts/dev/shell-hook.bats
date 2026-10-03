#!/usr/bin/env bats
# Unit tests for scripts/dev/shell-hook.sh (SPEC T1, T86, V17, V21, V32).

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/../../../.." && pwd)"
    SCRIPT="$ROOT/scripts/dev/shell-hook.sh"
    # The shim copied into the hooks dir for git older than 2.54 (V32).
    CLAUDINIX_LEGACY_HOOK="$ROOT/scripts/dev/legacy-hook.sh"
    export CLAUDINIX_LEGACY_HOOK
    BASH_BIN="$(command -v bash)"
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    HK_LOG="$BATS_TEST_TMPDIR/hk.log"
    mkdir -p "$STUB_BIN"
    ln -s "$(command -v git)" "$STUB_BIN/git"
    for tool in cat chmod cmp mv rm; do
        ln -s "$(command -v "$tool")" "$STUB_BIN/$tool"
    done
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

# An hk stub that chatters on stderr the way hk 1.58 `install` does.
stub_hk_chatty() {
    local rc="$1"
    # shellcheck disable=SC2016 # $* and $HK_LOG expand inside the stub, not here
    printf '#!%s\necho "$*" >>"$HK_LOG"\necho "hk Installed hk hook via git config" >&2\necho "hk stdout line"\nexit %s\n' "$BASH_BIN" "$rc" >"$STUB_BIN/hk"
    chmod +x "$STUB_BIN/hk"
}

@test "success is silence: hk install's own chatter is not shown (V31)" {
    stub_hk_chatty 0
    make_repo
    cd "$REPO"
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ "$(cat "$HK_LOG")" = "install" ]
}

@test "hk install failing: its output is shown with the warning" {
    stub_hk_chatty 4
    make_repo
    cd "$REPO"
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"hk Installed hk hook via git config"* ]]
    [[ "$output" == *"hk stdout line"* ]]
    [[ "$output" == *"hk install failed"* ]]
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

@test "a hook wrapped under an older env prefix is rewrapped, not wrapped twice (T71)" {
    stub_hk
    make_repo
    cd "$REPO"
    # shellcheck disable=SC2016 # ${HK:-1} is literal hook text, not expanded here
    git config --local hook.hk-pre-push.command 'test "${HK:-1}" = "0" || OLD_HOOK=1 nix develop -c hk run pre-push --from-hook'
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    # shellcheck disable=SC2016 # ${HK:-1} is literal hook text, not expanded here
    [ "$(git config --local hook.hk-pre-push.command)" = 'test "${HK:-1}" = "0" || CLAUDINIX_HOOK=1 nix develop -c hk run pre-push --from-hook' ]
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

@test "nix-dev on PATH: hooks enter the dev shell through it (cloud 403s)" {
    stub_hk_installer
    printf '#!/bin/sh\nexit 0\n' >"$STUB_BIN/nix-dev"
    chmod +x "$STUB_BIN/nix-dev"
    make_repo
    cd "$REPO"
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    for e in pre-commit pre-push commit-msg; do
        # shellcheck disable=SC2016 # ${HK:-1} is literal hook text, not expanded here
        [ "$(git config --local "hook.hk-$e.command")" = 'test "${HK:-1}" = "0" || CLAUDINIX_HOOK=1 nix-dev -c hk run '"$e"' --from-hook' ]
    done
}

@test "a nix develop wrap is rewrapped to nix-dev once it appears, and back, never nested" {
    stub_hk
    make_repo
    cd "$REPO"
    # shellcheck disable=SC2016 # ${HK:-1} is literal hook text, not expanded here
    git config --local hook.hk-pre-push.command 'test "${HK:-1}" = "0" || CLAUDINIX_HOOK=1 nix develop -c hk run pre-push --from-hook'
    printf '#!/bin/sh\nexit 0\n' >"$STUB_BIN/nix-dev"
    chmod +x "$STUB_BIN/nix-dev"
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    # shellcheck disable=SC2016 # ${HK:-1} is literal hook text, not expanded here
    [ "$(git config --local hook.hk-pre-push.command)" = 'test "${HK:-1}" = "0" || CLAUDINIX_HOOK=1 nix-dev -c hk run pre-push --from-hook' ]
    rm "$STUB_BIN/nix-dev"
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    # shellcheck disable=SC2016 # ${HK:-1} is literal hook text, not expanded here
    [ "$(git config --local hook.hk-pre-push.command)" = 'test "${HK:-1}" = "0" || CLAUDINIX_HOOK=1 nix develop -c hk run pre-push --from-hook' ]
}

# hooks_dir: where git looks for script hooks in the fixture repo.
hooks_dir() {
    (cd "$REPO" && cd "$(git rev-parse --git-path hooks)" && pwd)
}

@test "writes the old-git shim for every hk event, executable, silently (V32)" {
    stub_hk_installer
    make_repo
    cd "$REPO"
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    for e in pre-commit pre-push commit-msg; do
        [ -x "$(hooks_dir)/$e" ]
        cmp -s "$CLAUDINIX_LEGACY_HOOK" "$(hooks_dir)/$e"
    done
}

@test "the shim honours core.hooksPath" {
    stub_hk_installer
    make_repo
    cd "$REPO"
    git config --local core.hooksPath my-hooks
    mkdir -p my-hooks
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    for e in pre-commit pre-push commit-msg; do
        cmp -s "$CLAUDINIX_LEGACY_HOOK" "$REPO/my-hooks/$e"
    done
    [ ! -e "$REPO/.git/hooks/pre-commit" ]
}

@test "a hook that is not claudinix's is never overwritten: warns instead" {
    stub_hk_installer
    make_repo
    cd "$REPO"
    printf '#!/bin/sh\necho mine\n' >"$REPO/.git/hooks/pre-push"
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(cat "$REPO/.git/hooks/pre-push")" = "$(printf '#!/bin/sh\necho mine\n')" ]
    [[ "$output" == *"pre-push"* ]]
    [[ "$output" == *"left alone"* ]]
    cmp -s "$CLAUDINIX_LEGACY_HOOK" "$REPO/.git/hooks/pre-commit"
}

@test "an outdated claudinix shim is refreshed, a current one left as is" {
    stub_hk_installer
    make_repo
    cd "$REPO"
    printf '#!/usr/bin/env bash\n# claudinix-legacy-hook: an older copy\n' >"$REPO/.git/hooks/commit-msg"
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    cmp -s "$CLAUDINIX_LEGACY_HOOK" "$REPO/.git/hooks/commit-msg"
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    cmp -s "$CLAUDINIX_LEGACY_HOOK" "$REPO/.git/hooks/commit-msg"
}

@test "hk's own script shim (written under old git) is replaced: it skips the dev shell" {
    stub_hk_installer
    make_repo
    cd "$REPO"
    # shellcheck disable=SC2016 # literal hook text, as hk 1.58 writes it
    printf '#!/bin/sh\ntest "${HK:-1}" = "0" || exec hk run pre-commit --from-hook "$@"\n' >"$REPO/.git/hooks/pre-commit"
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    cmp -s "$CLAUDINIX_LEGACY_HOOK" "$REPO/.git/hooks/pre-commit"
}

@test "shim template missing: warns, keeps the config hooks, exits 0" {
    stub_hk_installer
    make_repo
    cd "$REPO"
    run env PATH="$STUB_BIN" CLAUDINIX_LEGACY_HOOK="$BATS_TEST_TMPDIR/none.sh" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"2.54"* ]]
    [ ! -e "$REPO/.git/hooks/pre-commit" ]
    git config --local hook.hk-pre-commit.command >/dev/null
}

@test "installed commit-msg shim refuses a bad message under a git older than 2.54 (B9)" {
    stub_hk_installer
    make_repo
    cd "$REPO"
    run env PATH="$STUB_BIN" "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    # The real hook enters the dev shell; here the gate's own commit-msg
    # guard stands in for `hk run commit-msg`.
    # shellcheck disable=SC2016 # ${HK:-1} expands when the hook runs
    git config --local hook.hk-commit-msg.command 'test "${HK:-1}" = "0" || bash '"$ROOT/scripts/guard/commit-msg.sh"
    old="$BATS_TEST_TMPDIR/old-git"
    mkdir -p "$old"
    # shellcheck disable=SC2016 # $1 and $@ expand inside the stub, not here
    printf '#!%s\nif [ "$1" = --version ]; then echo "git version 2.43.0"; exit 0; fi\nexec %s "$@"\n' \
        "$BASH_BIN" "$(command -v git)" >"$old/git"
    chmod +x "$old/git"
    printf 'bad message no type\n' >"$BATS_TEST_TMPDIR/msg"
    run env PATH="$old:$PATH" "$REPO/.git/hooks/commit-msg" "$BATS_TEST_TMPDIR/msg"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Conventional Commits"* ]]
}
