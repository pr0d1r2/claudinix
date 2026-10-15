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

# list ALLOW_JSON: write a rule list with ALLOW and the repo's own denies.
list() {
    jq -n --argjson allow "$1" --slurpfile repo "$REPO_ROOT/nix/cloud-permissions.json" \
        '{allow: $allow, deny: $repo[0].deny}' >"$PERMISSIONS_FILE"
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

@test "a main-push deny without its rtk twin: refused and named (.:V44)" {
    list '["Bash(bats *)"]'
    jq '.deny -= ["Bash(rtk git push *:main)"]' "$PERMISSIONS_FILE" >"$PERMISSIONS_FILE.new"
    mv "$PERMISSIONS_FILE.new" "$PERMISSIONS_FILE"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'Bash(rtk git push *:main)'* ]]
}

@test "a git allow without its rtk twin: refused and named (.:V44)" {
    list '["Bash(git push origin claude/*)"]'
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'Bash(rtk git push origin claude/*)'* ]]
}

@test "a cargo allow without its rtk twin: refused and named (.:V44)" {
    list '["Bash(cargo test *)"]'
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'Bash(rtk cargo test *)'* ]]
}

@test "git and cargo allows with their rtk twins pass (.:V44)" {
    list '["Bash(git push origin claude/*)", "Bash(rtk git push origin claude/*)", "Bash(cargo test *)", "Bash(rtk cargo test *)"]'
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a command rtk leaves alone needs no twin (.:V44)" {
    list '["Bash(nix-dev -c cargo test *)", "Bash(hk check *)", "Bash(claudinix-dev *)"]'
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a twin missing either way, in allow or deny: refused and named (.:V44, B53)" {
    # KEY|RULE ADDED ALONE|RULE THE GUARD MUST NAME
    while IFS='|' read -r key rule missing; do
        list '["Bash(bats *)"]'
        jq --arg key "$key" --arg rule "$rule" '.[$key] += [$rule]' "$PERMISSIONS_FILE" >"$PERMISSIONS_FILE.new"
        mv "$PERMISSIONS_FILE.new" "$PERMISSIONS_FILE"
        run bash "$SCRIPT"
        [ "$status" -eq 1 ] || {
            echo "passed without its twin: $key $rule"
            return 1
        }
        [[ "$output" == *"$missing"* ]] || {
            echo "did not name $missing: $output"
            return 1
        }
    done <<'TABLE'
allow|Bash(rtk git diff *)|Bash(git diff *)
allow|Bash(git push -u origin claude/*)|Bash(rtk git push -u origin claude/*)
deny|Bash(git reset *)|Bash(rtk git reset *)
deny|Bash(rtk git reset *)|Bash(git reset *)
deny|Bash(cargo publish *)|Bash(rtk cargo publish *)
TABLE
}

# The deny rules are judged with bash globs, an approximation of Claude
# Code's matcher; the rules themselves are plain strings with one `*`
# wildcard, which both read alike.
denied_by_repo_list() {
    local cmd="$1" rule glob
    while IFS= read -r rule; do
        glob="${rule#Bash(}"
        glob="${glob%)}"
        # shellcheck disable=SC2053 # the rule is a glob on purpose
        [[ "$cmd" == $glob ]] && return 0
    done < <(jq -r '.deny[]' "$REPO_ROOT/nix/cloud-permissions.json")
    return 1
}

@test "the repo's own list denies -f before and after the refspec (nix:B54)" {
    for cmd in 'git push origin HEAD:claude/x -f' 'git push -f origin HEAD:claude/x' \
        'rtk git push origin HEAD:claude/x -f' 'rtk git push -f origin HEAD:claude/x'; do
        denied_by_repo_list "$cmd" || {
            echo "not denied: $cmd"
            return 1
        }
    done
}

@test "the repo's own list denies -f bundled with -u (B56)" {
    for cmd in 'git push origin HEAD:claude/x -uf' 'git push origin HEAD:claude/x -fu' \
        'git push -uf origin HEAD:claude/x' 'rtk git push -fu origin HEAD:claude/x' \
        'rtk git push origin HEAD:claude/x -uf'; do
        denied_by_repo_list "$cmd" || {
            echo "not denied: $cmd"
            return 1
        }
    done
}

@test "the repo's own list denies any option after the remote (home:V49, home:B58)" {
    for cmd in 'git push origin HEAD:claude/x -nf' 'git push origin HEAD:claude/x -vf' \
        'git push origin claude/x -d' 'git push origin HEAD:claude/x -fd' \
        'git push -u origin claude/x -f' 'git push --force-with-lease origin HEAD:claude/x -f' \
        'git push origin HEAD:claude/x -o ci.skip' 'rtk git push origin HEAD:claude/x -nf' \
        'rtk git push origin claude/x -d'; do
        denied_by_repo_list "$cmd" || {
            echo "not denied: $cmd"
            return 1
        }
    done
}

@test "the repo's own list still lets options come before the remote (home:V49)" {
    for cmd in 'git push -u origin claude/x' 'git push --force-with-lease origin HEAD:feature/x' \
        'git push origin HEAD:claude/fix-thing' 'git push origin claude/x' \
        'rtk git push -u origin claude/x' 'rtk git push --force-with-lease origin HEAD:feature/x'; do
        ! denied_by_repo_list "$cmd" || {
            echo "wrongly denied: $cmd"
            return 1
        }
    done
}

@test "dropping the deny for options after the remote is refused (home:V49)" {
    list '["Bash(bats *)"]'
    jq '.deny -= ["Bash(git push * -*)", "Bash(rtk git push * -*)"]' "$PERMISSIONS_FILE" >"$PERMISSIONS_FILE.new"
    mv "$PERMISSIONS_FILE.new" "$PERMISSIONS_FILE"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'Bash(git push * -*)'* ]]
}

@test "dropping only the rtk twin of the option deny is refused (home:V49)" {
    list '["Bash(bats *)"]'
    jq '.deny -= ["Bash(rtk git push * -*)"]' "$PERMISSIONS_FILE" >"$PERMISSIONS_FILE.new"
    mv "$PERMISSIONS_FILE.new" "$PERMISSIONS_FILE"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'Bash(rtk git push * -*)'* ]]
}

@test "the repo's own list denies a push that writes a second ref (home:V50, home:B59)" {
    for cmd in 'git push origin claude/x:production' 'git push -u origin claude/x:release' \
        'git push origin claude/x release' 'git push -u origin claude/x release' \
        'git push origin HEAD:claude/x release' 'git push origin HEAD:claude/x HEAD:release' \
        'git push --force-with-lease origin HEAD:claude/x HEAD:release' \
        'rtk git push origin claude/x:production' 'rtk git push origin HEAD:claude/x release'; do
        denied_by_repo_list "$cmd" || {
            echo "not denied: $cmd"
            return 1
        }
    done
}

@test "the repo's own list denies a partial ref that names main (home:B60)" {
    for cmd in 'git push origin HEAD:heads/main' 'git push --force-with-lease origin HEAD:heads/main' \
        'rtk git push origin HEAD:heads/main'; do
        denied_by_repo_list "$cmd" || {
            echo "not denied: $cmd"
            return 1
        }
    done
}

@test "the repo's own list still lets a push write its one ref (home:V50)" {
    for cmd in 'git push origin claude/x' 'git push -u origin claude/x' \
        'git push origin HEAD:claude/x' 'git push origin HEAD:feature/x' \
        'git push --force-with-lease origin HEAD:feature/x' 'rtk git push origin HEAD:claude/x'; do
        ! denied_by_repo_list "$cmd" || {
            echo "wrongly denied: $cmd"
            return 1
        }
    done
}

@test "dropping a one-ref deny is refused (home:V50)" {
    for rule in 'Bash(git push origin * *)' 'Bash(git push * origin * *)' 'Bash(git push * claude/*:*)'; do
        list '["Bash(bats *)"]'
        jq --arg rule "$rule" '.deny -= [$rule, "Bash(rtk " + $rule[5:]]' "$PERMISSIONS_FILE" >"$PERMISSIONS_FILE.new"
        mv "$PERMISSIONS_FILE.new" "$PERMISSIONS_FILE"
        run bash "$SCRIPT"
        [ "$status" -eq 1 ] || {
            echo "passed without: $rule"
            return 1
        }
        [[ "$output" == *"$rule"* ]]
    done
}

@test "the repo's own list does not deny a branch that merely ends in -f (B55)" {
    for cmd in 'git push origin claude/review-f' 'rtk git push origin claude/review-f' \
        'git push -u origin claude/x-f'; do
        ! denied_by_repo_list "$cmd" || {
            echo "wrongly denied: $cmd"
            return 1
        }
    done
}

@test "dropping a required deny is refused: -f, --force, --delete, --mirror (nix:B54)" {
    for rule in 'Bash(git push * -f)' 'Bash(git push -f *)' 'Bash(git push *--force)' \
        'Bash(git push *--delete*)' 'Bash(git push *--mirror*)'; do
        list '["Bash(bats *)"]'
        jq --arg rule "$rule" '.deny -= [$rule, "Bash(rtk git push" + $rule[13:]]' "$PERMISSIONS_FILE" >"$PERMISSIONS_FILE.new"
        mv "$PERMISSIONS_FILE.new" "$PERMISSIONS_FILE"
        run bash "$SCRIPT"
        [ "$status" -eq 1 ] || {
            echo "passed without: $rule"
            return 1
        }
        [[ "$output" == *"$rule"* ]] || {
            echo "did not name $rule: $output"
            return 1
        }
    done
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

@test "the repo's own list denies gh pr merge, bare and as rtk rewrites it (.:C29)" {
    for cmd in 'gh pr merge 8 --rebase' 'rtk gh pr merge 8 --rebase'; do
        denied_by_repo_list "$cmd" || {
            echo "not denied: $cmd"
            return 1
        }
    done
}

@test "dropping the gh pr merge deny is refused; a gh rule needs its rtk twin (.:C29, .:V44)" {
    list '["Bash(bats *)"]'
    jq '.deny -= ["Bash(gh pr merge *)", "Bash(rtk gh pr merge *)"]' "$PERMISSIONS_FILE" >"$PERMISSIONS_FILE.new"
    mv "$PERMISSIONS_FILE.new" "$PERMISSIONS_FILE"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'Bash(gh pr merge *)'* ]]
    list '["Bash(gh pr view *)"]'
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'Bash(rtk gh pr view *)'* ]]
}

@test "the repo's own list denies every other way to merge: gh -R, gh api, rtk twins (.:C29, cloud:B71)" {
    for cmd in 'gh -R o/r pr merge 8' 'gh --repo o/r pr merge 8 --rebase' 'rtk gh -R o/r pr merge 8' \
        'gh api -X PUT repos/o/r/pulls/8/merge' 'rtk gh api repos/o/r/pulls/8/merge -X PUT'; do
        denied_by_repo_list "$cmd" || {
            echo "not denied: $cmd"
            return 1
        }
    done
    for tool in mcp__github__merge_pull_request mcp__github__enable_pr_auto_merge; do
        jq -e --arg t "$tool" '.deny | index($t)' "$REPO_ROOT/nix/cloud-permissions.json" >/dev/null
    done
}

@test "dropping an MCP merge deny is refused (.:C29, cloud:B71)" {
    list '["Bash(bats *)"]'
    jq '.deny -= ["mcp__github__merge_pull_request"]' "$PERMISSIONS_FILE" >"$PERMISSIONS_FILE.new"
    mv "$PERMISSIONS_FILE.new" "$PERMISSIONS_FILE"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'mcp__github__merge_pull_request'* ]]
}
