#!/usr/bin/env bats
# Unit tests for scripts/lib/review-tier.sh: the review tier a pull
# request's diff sets (SPEC cloud:T183, cloud:V66), highest hit wins.

setup() {
    LIB="$BATS_TEST_DIRNAME/../../../../scripts/lib/review-tier.sh"
    # shellcheck source=/dev/null
    source "$LIB"
}

# files LINE...: the "ADDITIONS<TAB>DELETIONS<TAB>PATH" lines gh prints.
files() {
    printf '%s\n' "$@" | tr '|' '\t'
}

@test "docs, specs and tests only: light, named by the first path" {
    run review_tier <<<"$(files '3|1|docs/CLI.md' '2|0|cloud/SPEC.md' '5|5|tests/unit/x.bats' '1|0|README.md')"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf 'light\tdocs/CLI.md')" ]
}

@test "a script, setup.sh or home/ code: light+correctness, named by that path" {
    run review_tier <<<"$(files '1|0|docs/CLI.md' '4|2|scripts/burn.sh')"
    [ "$output" = "$(printf 'light+correctness\tscripts/burn.sh')" ]
    run review_tier <<<"$(files '1|0|setup.sh')"
    [ "$output" = "$(printf 'light+correctness\tsetup.sh')" ]
    run review_tier <<<"$(files '1|0|home/default.nix')"
    [ "$output" = "$(printf 'light+correctness\thome/default.nix')" ]
}

@test "home/ docs are docs; a script's own .md or prompt under scripts/ is code" {
    run review_tier <<<"$(files '1|0|home/SPEC.md')"
    [ "$output" = "$(printf 'light\thome/SPEC.md')" ]
    run review_tier <<<"$(files '1|0|scripts/review/security.md')"
    [ "$output" = "$(printf 'light+correctness\tscripts/review/security.md')" ]
    run review_tier <<<"$(files '1|0|scripts/cloud-fixup-prompt.txt')"
    [ "$output" = "$(printf 'light+correctness\tscripts/cloud-fixup-prompt.txt')" ]
}

@test "permissions, hooks, the launcher lib and the consumer surface: council" {
    local p
    for p in nix/cloud-permissions.json .claude/settings.json scripts/dev/shell-hook.sh \
        scripts/dev/legacy-hook.sh scripts/dev/session-start.sh hk.pkl \
        scripts/lib/cloud-launch.sh .claudinix.toml scripts/nix-dev.sh scripts/nix-dev.jq; do
        run review_tier <<<"$(files '1|0|docs/CLI.md' "1|0|$p")"
        [ "$output" = "$(printf 'council\t%s' "$p")" ]
    done
}

@test "any other path is council: safe default (V66)" {
    run review_tier <<<"$(files '1|0|docs/CLI.md' '1|0|.context-limits')"
    [ "$output" = "$(printf 'council\t.context-limits')" ]
    run review_tier <<<"$(files '1|0|.github/workflows/ci.yml')"
    [ "$output" = "$(printf 'council\t.github/workflows/ci.yml')" ]
}

@test "more than 300 changed lines is council, named by the count; 300 is not" {
    run review_tier <<<"$(files '200|101|docs/CLI.md')"
    [ "$output" = "$(printf 'council\t301 changed lines')" ]
    run review_tier <<<"$(files '200|100|docs/CLI.md')"
    [ "$output" = "$(printf 'light\tdocs/CLI.md')" ]
}

@test "a council path names itself even past 300 lines" {
    run review_tier <<<"$(files '400|0|docs/CLI.md' '1|0|hk.pkl')"
    [ "$output" = "$(printf 'council\thk.pkl')" ]
}

@test "no changed files is council, never light" {
    run review_tier </dev/null
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf 'council\tno changed files')" ]
}

@test "a line it cannot read fails: no tier, never a default" {
    run review_tier <<<"$(files 'x|0|docs/CLI.md')"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "review_tier_roles: light is security, light+correctness adds correctness, council is every role" {
    run review_tier_roles light
    [ "$output" = security ]
    run review_tier_roles light+correctness
    [ "$output" = "$(printf 'security\ncorrectness')" ]
    run review_tier_roles council
    [ -z "$output" ]
    [ "$status" -eq 0 ]
    run review_tier_roles bogus
    [ "$status" -eq 1 ]
}
