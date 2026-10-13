#!/usr/bin/env bats
# Unit tests for scripts/guard/node-names.sh (SPEC V48, B57): no §F node
# name has a hyphen, because sherd reads a cite's node name only after its
# last hyphen and `agent-home:C33` resolved as `home:C33`.

setup() {
    REPO_ROOT="$BATS_TEST_DIRNAME/../../../.."
    SCRIPT="$REPO_ROOT/scripts/guard/node-names.sh"
    SPEC="$BATS_TEST_TMPDIR/SPEC.md"
}

# spec NODE...: a root spec whose §F lists NODE..., followed by another
# table whose first column has a hyphen, which must be ignored (every case
# below proves rows outside §F are not node names).
spec() {
    {
        printf '# SPEC\n\n## §G GOAL\n\ngoal\n\n## §F FEDERATION\n\ndir|owns|⊥owns|tokens\n'
        for node in "$@"; do
            printf '%s|owns %s|-|-\n' "$node" "$node"
        done
        printf '\n## §T TASKS\n\nid|status|task|cites\nT1|.|see-also row|-\nno-hyphen-check|.|x|-\n'
    } >"$SPEC"
}

@test "node names without a hyphen pass silently" {
    spec scripts nix home
    run bash "$SCRIPT" "$SPEC"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a hyphenated node name fails and names it (V48)" {
    spec scripts agent-home nix
    run bash "$SCRIPT" "$SPEC"
    [ "$status" -eq 1 ]
    [ "${#lines[@]}" -eq 1 ]
    [[ "${lines[0]}" == "node-names: §F node \"agent-home\" in $SPEC has a hyphen"* ]]
}

@test "every hyphenated node is reported, not only the first" {
    spec agent-home dev-tools
    run bash "$SCRIPT" "$SPEC"
    [ "$status" -eq 1 ]
    [[ "$output" == *'agent-home'* ]]
    [[ "$output" == *'dev-tools'* ]]
}

@test "a spec with no §F table: fails, nothing was checked" {
    printf '# SPEC\n\n## §G GOAL\n\ngoal\n' >"$SPEC"
    run bash "$SCRIPT" "$SPEC"
    [ "$status" -eq 1 ]
    [[ "$output" == *'§F'* ]]
}

@test "a §F table with a header and no rows: fails, nothing was checked (B61)" {
    spec
    run bash "$SCRIPT" "$SPEC"
    [ "$status" -eq 1 ]
    [[ "$output" == *'§F'* ]]
}

@test "a pipe line after a blank line in §F is prose, not a node row (B61)" {
    printf '## §F FEDERATION\n\ndir|owns\nscripts|owns\n\nnote: see a-b|c\n' >"$SPEC"
    run bash "$SCRIPT" "$SPEC"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "missing spec: fails, nothing was checked" {
    run bash "$SCRIPT" "$BATS_TEST_TMPDIR/nope.md"
    [ "$status" -eq 1 ]
}

@test "the repo's own root spec passes" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
