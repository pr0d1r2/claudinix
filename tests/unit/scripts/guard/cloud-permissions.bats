#!/usr/bin/env bats
# Unit tests for scripts/guard/cloud-permissions.sh (SPEC T101, C29, C27):
# the one rule list cloud sessions get is narrow, keeps the deny rules
# against pushing main, and never lands in the committed project
# settings that local sessions read.

setup() {
    REPO_ROOT="$BATS_TEST_DIRNAME/../../../.."
    SCRIPT="$REPO_ROOT/scripts/guard/cloud-permissions.sh"
    export PERMISSIONS_FILE="$BATS_TEST_TMPDIR/cloud-permissions.json"
    export SETTINGS_FILE="$BATS_TEST_TMPDIR/settings.json"
    echo '{"hooks":{}}' >"$SETTINGS_FILE"
}

# list ALLOW_JSON: write a rule list with ALLOW and the required denies.
list() {
    jq -n --argjson allow "$1" '{
        allow: $allow,
        deny: [
            "Bash(git push * main)",
            "Bash(git push * main *)",
            "Bash(git push *:main)",
            "Bash(git push *:main *)",
            "Bash(git push *refs/heads/main*)"
        ]
    }' >"$PERMISSIONS_FILE"
}

@test "a narrow list passes silently" {
    list '["Bash(nix develop -c hk *)", "Bash(bats *)", "Edit(/gate.log)"]'
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "the repo's own list and settings pass" {
    unset PERMISSIONS_FILE SETTINGS_FILE
    cd "$REPO_ROOT"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "the repo's own list allows the gate's commands" {
    run jq -r '.allow[]' "$REPO_ROOT/nix/cloud-permissions.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *'Bash(nix develop -c hk *)'* ]]
    [[ "$output" == *'Bash(nix-dev -c hk *)'* ]]
    [[ "$output" == *'Bash(bats *)'* ]]
    [[ "$output" == *'Bash(git commit *)'* ]]
}

@test "the repo's own list allows a lease push to claude/* and no plain force push (nix:T127)" {
    run jq -r '.allow[]' "$REPO_ROOT/nix/cloud-permissions.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *'Bash(git push --force-with-lease origin HEAD:claude/*)'* ]]
    [[ "$output" != *'--force '* ]]
    [[ "$output" != *' -f '* ]]
}

@test "the repo's own list lets fixup push a PR branch, and HEAD:main stays denied (nix:T133)" {
    run jq -r '.allow[]' "$REPO_ROOT/nix/cloud-permissions.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *'Bash(git push origin HEAD:*)'* ]]
    run jq -r '.deny[]' "$REPO_ROOT/nix/cloud-permissions.json"
    [[ "$output" == *'Bash(git push *:main)'* ]]
}

@test "the repo's own list denies a force refspec and a tag push through HEAD:* (nix:B23)" {
    for refspec in HEAD:+main HEAD:+claude/x HEAD:refs/heads/main HEAD:refs/tags/v1; do
        denied=0
        while IFS= read -r rule; do
            glob="${rule#Bash(}"
            glob="${glob%)}"
            # shellcheck disable=SC2053 # the rule is a glob on purpose
            [[ "git push origin $refspec" == $glob ]] && denied=1
        done < <(jq -r '.deny[]' "$REPO_ROOT/nix/cloud-permissions.json")
        [ "$denied" -eq 1 ] || {
            echo "not denied: $refspec"
            return 1
        }
    done
}

@test "the repo's own list lets rebase lease-push any PR branch; a lease push to main stays denied (nix:T144)" {
    run jq -r '.allow[]' "$REPO_ROOT/nix/cloud-permissions.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *'Bash(git push --force-with-lease origin HEAD:*)'* ]]
    denied=0
    while IFS= read -r rule; do
        glob="${rule#Bash(}"
        glob="${glob%)}"
        # shellcheck disable=SC2053 # the rule is a glob on purpose
        [[ "git push --force-with-lease origin HEAD:main" == $glob ]] && denied=1
    done < <(jq -r '.deny[]' "$REPO_ROOT/nix/cloud-permissions.json")
    [ "$denied" -eq 1 ]
}

@test "the repo's own list denies --delete, --force and --mirror after any push, and keeps the lease flag (nix:T147)" {
    for cmd in 'git push origin HEAD:x --delete' 'git push --force-with-lease origin HEAD:x --force' \
        'git push --force origin HEAD:x' 'git push --mirror origin' 'git push origin --delete x'; do
        denied=0
        while IFS= read -r rule; do
            glob="${rule#Bash(}"
            glob="${glob%)}"
            # shellcheck disable=SC2053 # the rule is a glob on purpose
            [[ "$cmd" == $glob ]] && denied=1
        done < <(jq -r '.deny[]' "$REPO_ROOT/nix/cloud-permissions.json")
        [ "$denied" -eq 1 ] || {
            echo "not denied: $cmd"
            return 1
        }
    done
    # the lease push the rebase session needs is not caught by the --force deny
    while IFS= read -r rule; do
        glob="${rule#Bash(}"
        glob="${glob%)}"
        # shellcheck disable=SC2053 # the rule is a glob on purpose
        [[ "git push --force-with-lease origin HEAD:feature/x" != $glob ]] || return 1
    done < <(jq -r '.deny[]' "$REPO_ROOT/nix/cloud-permissions.json")
}

@test "whole-tool rule Bash: refused and named" {
    list '["Bash(bats *)", "Bash"]'
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'"Bash"'* ]]
}

@test "Bash(*): refused" {
    list '["Bash(*)"]'
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'Bash(*)'* ]]
}

@test "a rule starting with a wildcard: refused" {
    list '["*"]'
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'"*"'* ]]
}

@test "a bare environment runner: refused, every form" {
    local rule
    for rule in 'Bash(nix develop *)' 'Bash(nix-dev *)' 'Bash(nix develop -c *)' 'Bash(nix-dev:*)'; do
        list "[\"$rule\"]"
        run bash "$SCRIPT"
        [ "$status" -eq 1 ]
        [[ "$output" == *"$rule"* ]]
    done
}

@test "every offending rule is reported, not only the first" {
    list '["Bash", "Bash(nix-dev *)"]'
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'"Bash"'* ]]
    [[ "$output" == *'Bash(nix-dev *)'* ]]
}

@test "a missing deny against pushing main: refused and named" {
    list '["Bash(bats *)"]'
    jq '.deny -= ["Bash(git push *:main)"]' "$PERMISSIONS_FILE" >"$PERMISSIONS_FILE.new"
    mv "$PERMISSIONS_FILE.new" "$PERMISSIONS_FILE"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'Bash(git push *:main)'* ]]
}

@test "not an {allow, deny} object of strings: refused" {
    echo '{"allow": "Bash(bats *)"}' >"$PERMISSIONS_FILE"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"allow"* ]]
}

@test "missing list: refused, nothing checked" {
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$PERMISSIONS_FILE"* ]]
}

@test "the committed project settings carry permissions: refused (local sessions read them)" {
    list '["Bash(bats *)"]'
    echo '{"permissions":{"allow":["Bash(bats *)"]},"hooks":{}}' >"$SETTINGS_FILE"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$SETTINGS_FILE"* ]]
    [[ "$output" == *"permissions"* ]]
}

@test "jq missing: fails, never passes" {
    list '["Bash(bats *)"]'
    run env PATH="$BATS_TEST_TMPDIR/nobin" "$(command -v bash)" "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"jq"* ]]
}
