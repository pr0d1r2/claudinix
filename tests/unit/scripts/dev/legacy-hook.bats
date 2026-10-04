#!/usr/bin/env bats
# Unit tests for scripts/dev/legacy-hook.sh (SPEC T86, V32, B9, V21).
#
# The script is copied into a hooks dir under an event's name and run by
# git. git >= 2.54 also runs the config-based hook, so the copy must stay
# out of the way there; an older git runs only the copy.

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/../../../.." && pwd)"
    SCRIPT="$ROOT/scripts/dev/legacy-hook.sh"
    GUARD="$ROOT/scripts/guard/commit-msg.sh"
    BASH_BIN="$(command -v bash)"
    REAL_GIT="$(command -v git)"
    # Every GIT_* var: a hook exports GIT_EXEC_PATH, and an older git's
    # exec dir first on PATH makes the shim run the gate again (B17).
    while IFS= read -r var; do
        unset "$var"
    done < <(compgen -e | grep '^GIT_' || true)
    unset CLAUDINIX_HOOK HK
    REPO="$BATS_TEST_TMPDIR/repo"
    HOOKS="$REPO/.git/hooks"
    GIT_BIN="$BATS_TEST_TMPDIR/git-bin"
    RAN="$BATS_TEST_TMPDIR/ran"
    export RAN
    git init -q "$REPO"
    git -C "$REPO" config user.email t@example.invalid
    git -C "$REPO" config user.name t
    git -C "$REPO" config commit.gpgsign false
    mkdir -p "$HOOKS" "$GIT_BIN"
    cd "$REPO" || exit 1
}

# install EVENT: copy the shim in the way shell-hook.sh does.
install() {
    cp "$SCRIPT" "$HOOKS/$1"
    chmod +x "$HOOKS/$1"
}

# git_reports VERSION: a git on PATH whose `--version` says VERSION and
# which is the real git for everything else.
git_reports() {
    # shellcheck disable=SC2016 # $1 and $@ expand inside the stub, not here
    printf '#!%s\nif [ "$1" = --version ]; then echo "git version %s"; exit 0; fi\nexec %s "$@"\n' \
        "$BASH_BIN" "$1" "$REAL_GIT" >"$GIT_BIN/git"
    chmod +x "$GIT_BIN/git"
}

# hook_command EVENT COMMAND: the config-based hook, as hk writes it.
hook_command() {
    git config --local "hook.hk-$1.command" "$2"
    git config --local "hook.hk-$1.event" "$1"
}

@test "git older than 2.54: runs the config hook's command with git's arguments" {
    git_reports 2.43.0
    install commit-msg
    # git appends its arguments to a config hook's command, as hk relies
    # on (`--from-hook` then the message file).
    # shellcheck disable=SC2016 # $RAN expands when the hook runs
    hook_command commit-msg 'printf "%s\n" >"$RAN"'
    run env PATH="$GIT_BIN:$PATH" "$HOOKS/commit-msg" .git/COMMIT_EDITMSG
    [ "$status" -eq 0 ]
    [ "$(cat "$RAN")" = .git/COMMIT_EDITMSG ]
}

@test "git older than 2.54: the hook's stdin reaches the command (pre-push refs)" {
    git_reports 2.50.1
    install pre-push
    # shellcheck disable=SC2016 # $RAN expands when the hook runs
    hook_command pre-push 'cat >"$RAN"; :'
    run env PATH="$GIT_BIN:$PATH" "$HOOKS/pre-push" origin url <<<"refs/heads/a 1 refs/heads/a 0"
    [ "$status" -eq 0 ]
    [ "$(cat "$RAN")" = "refs/heads/a 1 refs/heads/a 0" ]
}

@test "git older than 2.54: the command's refusal refuses the hook" {
    git_reports 2.43.0
    install pre-commit
    hook_command pre-commit 'exit 7'
    run env PATH="$GIT_BIN:$PATH" "$HOOKS/pre-commit"
    [ "$status" -eq 7 ]
}

@test "git older than 2.54: a bad message file is refused by the commit-msg gate (B9)" {
    git_reports 2.43.0
    install commit-msg
    # shellcheck disable=SC2016 # ${HK:-1} expands when the hook runs
    hook_command commit-msg 'test "${HK:-1}" = "0" || bash '"$GUARD"
    printf 'bad message no type\n' >"$BATS_TEST_TMPDIR/msg"
    run env PATH="$GIT_BIN:$PATH" "$HOOKS/commit-msg" "$BATS_TEST_TMPDIR/msg"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Conventional Commits"* ]]
}

@test "HK=0 in the hook command still skips the gate under old git" {
    git_reports 2.43.0
    install pre-commit
    # shellcheck disable=SC2016 # ${HK:-1} expands when the hook runs
    hook_command pre-commit 'test "${HK:-1}" = "0" || exit 7'
    run env PATH="$GIT_BIN:$PATH" HK=0 "$HOOKS/pre-commit"
    [ "$status" -eq 0 ]
}

@test "git 2.54 or newer: does nothing, the config hook already ran" {
    for v in 2.54.0 2.60.1 3.0.0 "2.54.0.windows.1"; do
        git_reports "$v"
        install pre-commit
        hook_command pre-commit 'exit 7'
        run env PATH="$GIT_BIN:$PATH" "$HOOKS/pre-commit"
        [ "$status" -eq 0 ]
    done
}

@test "Apple's git version string is read (2.50.1 (Apple Git-155))" {
    git_reports "2.50.1 (Apple Git-155)"
    install pre-commit
    hook_command pre-commit 'exit 7'
    run env PATH="$GIT_BIN:$PATH" "$HOOKS/pre-commit"
    [ "$status" -eq 7 ]
}

@test "no config hook for the event under old git: refuses and names the fix" {
    git_reports 2.43.0
    install pre-commit
    run env PATH="$GIT_BIN:$PATH" "$HOOKS/pre-commit"
    [ "$status" -eq 1 ]
    [[ "$output" == *"hook.hk-pre-commit.command"* ]]
    [[ "$output" == *"nix develop -c true"* ]]
}

@test "an unreadable git version refuses rather than passes" {
    git_reports garbage
    install pre-commit
    hook_command pre-commit 'exit 0'
    run env PATH="$GIT_BIN:$PATH" "$HOOKS/pre-commit"
    [ "$status" -eq 1 ]
    [[ "$output" == *"git version"* ]]
}

# commit_with GIT MESSAGE: a real commit by the given git binary, the
# commit-msg gate wired as hk wires it plus the shim, counting each run.
commit_with() {
    install commit-msg
    # shellcheck disable=SC2016 # ${HK:-1} and $RAN expand when the hook runs
    hook_command commit-msg 'echo x >>"$RAN"; test "${HK:-1}" = "0" || bash '"$GUARD"
    run "$1" commit -q --allow-empty -m "$2"
}

@test "real git >= 2.54 on PATH: the gate runs once, not twice" {
    "$REAL_GIT" --version | grep -Eq 'git version (2\.(5[4-9]|[6-9][0-9])|[3-9])' ||
        skip "the PATH git is older than 2.54"
    commit_with "$REAL_GIT" "bad message no type"
    [ "$status" -ne 0 ]
    [ "$(wc -l <"$RAN" | tr -d ' ')" = 1 ]
}

@test "real git older than 2.54: a bad message is refused, a good one passes (B9)" {
    old=""
    for g in /usr/bin/git /usr/local/bin/git; do
        [ -x "$g" ] || continue
        if ! "$g" --version | grep -Eq 'git version (2\.(5[4-9]|[6-9][0-9])|[3-9])'; then
            old="$g"
            break
        fi
    done
    [ -n "$old" ] || skip "no git older than 2.54 on this machine"
    commit_with "$old" "bad message no type"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Conventional Commits"* ]]
    [ "$(git rev-list --all --count)" = 0 ]
    printf 'fix: a good one\n\nWhy: test\nRefs: §T.86\n' >"$BATS_TEST_TMPDIR/good"
    run "$old" commit -q --allow-empty -F "$BATS_TEST_TMPDIR/good"
    [ "$status" -eq 0 ]
    [ "$(git rev-list --all --count)" = 1 ]
}
