#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/nix/rtk-twins-check.sh (SPEC .:V44, B53): the
# pinned rtk's own hook says which cloud permission rules it rewrites, and
# each rewritten rule needs its `rtk ` twin in the same list. A stub rtk
# rewrites git and cargo commands, like rtk 0.51 does, unless told not to.

setup() {
    REPO_ROOT="$BATS_TEST_DIRNAME/../../../.."
    SCRIPT="$REPO_ROOT/scripts/nix/rtk-twins-check.sh"
    PERMS="$BATS_TEST_TMPDIR/perms.json"
    OUT="$BATS_TEST_TMPDIR/out"
    RTK="$BATS_TEST_TMPDIR/rtk"
    # STUB_REWRITES: the commands the stub rewrites (a regex); STUB_EXIT:
    # its exit status.
    export STUB_REWRITES='^(git|cargo) '
    export STUB_EXIT=0
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        '[ "$*" = "hook claude" ] || exit 9' \
        'jq -c --arg re "$STUB_REWRITES" '"'"'.tool_input.command | select(test($re)) | {hookSpecificOutput: {hookEventName: "PreToolUse", updatedInput: {command: ("rtk " + .)}}}'"'"'' \
        'exit "$STUB_EXIT"' >"$RTK"
    chmod +x "$RTK"
}

# perms ALLOW_JSON DENY_JSON: write the permission list.
perms() {
    jq -n --argjson allow "$1" --argjson deny "$2" '{allow: $allow, deny: $deny}' >"$PERMS"
}

@test "every rewritten rule has its twin: passes and writes OUT" {
    perms '["Bash(git push origin claude/*)", "Bash(rtk git push origin claude/*)", "Bash(hk check *)"]' \
        '["Bash(git push * main)", "Bash(rtk git push * main)"]'
    run bash "$SCRIPT" "$RTK" "$PERMS" "$OUT"
    [ "$status" -eq 0 ]
    [ -e "$OUT" ]
}

@test "a rewritten allow without its twin: fails, names the twin, writes no OUT" {
    perms '["Bash(git push origin claude/*)"]' '[]'
    run bash "$SCRIPT" "$RTK" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'Bash(rtk git push origin claude/*)'* ]]
    [ ! -e "$OUT" ]
}

@test "a rewritten deny without its twin: fails and names the twin" {
    perms '[]' '["Bash(git push *--mirror*)"]'
    run bash "$SCRIPT" "$RTK" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'Bash(rtk git push *--mirror*)'* ]]
}

@test "a tool the guard does not know, once rtk rewrites it: fails (B53)" {
    perms '["Bash(gh pr view *)"]' '[]'
    STUB_REWRITES="^(git|cargo|gh) " run bash "$SCRIPT" "$RTK" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'Bash(rtk gh pr view *)'* ]]
    [[ "$output" == *'scripts/guard/cloud-permissions.sh'* ]]
}

@test "a rule rtk leaves alone needs no twin" {
    perms '["Bash(hk check *)", "Bash(nix-dev -c cargo test *)"]' '[]'
    run bash "$SCRIPT" "$RTK" "$PERMS" "$OUT"
    [ "$status" -eq 0 ]
    [ -e "$OUT" ]
}

@test "an rtk that rewrites not even git status: fails, nothing was checked" {
    perms '["Bash(hk check *)"]' '[]'
    STUB_REWRITES="^$" run bash "$SCRIPT" "$RTK" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'git status'* ]]
    [ ! -e "$OUT" ]
}

@test "an rtk hook that fails: fails, never passes" {
    perms '["Bash(hk check *)"]' '[]'
    STUB_EXIT=3 run bash "$SCRIPT" "$RTK" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [ ! -e "$OUT" ]
}

@test "the repo's own list passes against an rtk that rewrites git and cargo" {
    run bash "$SCRIPT" "$RTK" "$REPO_ROOT/nix/cloud-permissions.json" "$OUT"
    [ "$status" -eq 0 ]
    [ -e "$OUT" ]
}

@test "wrong number of arguments: usage, exit 2" {
    run bash "$SCRIPT" "$RTK" "$PERMS"
    [ "$status" -eq 2 ]
    [[ "$output" == *usage* ]]
}
