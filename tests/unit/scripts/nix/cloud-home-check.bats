#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/nix/cloud-home-check.sh (SPEC nix:T16, nix:V14,
# C12): the agent home's activation package carries the cavekit skills,
# FORMAT.md and the set rules under home-files/.claude.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/nix/cloud-home-check.sh"
    PKG="$BATS_TEST_TMPDIR/activation"
    OUT="$BATS_TEST_TMPDIR/out"
    CLAUDE="$PKG/home-files/.claude"
}

# A complete home: every required file, as the store links them.
full_home() {
    local skill
    for skill in spec build check backprop caveman; do
        mkdir -p "$CLAUDE/skills/$skill"
        echo "# $skill" >"$CLAUDE/skills/$skill/SKILL.md"
    done
    echo "# format" >"$CLAUDE/FORMAT.md"
    mkdir -p "$CLAUDE/rules/set"
    echo "# set" >"$CLAUDE/rules/set/generic.md"
}

@test "complete home: passes and writes OUT" {
    full_home
    run bash "$SCRIPT" "$PKG" "$OUT"
    [ "$status" -eq 0 ]
    [ -e "$OUT" ]
}

@test "missing skill: fails, names it, writes no OUT" {
    full_home
    rm "$CLAUDE/skills/backprop/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/backprop/SKILL.md"* ]]
    [ ! -e "$OUT" ]
}

@test "missing FORMAT.md: fails and names it" {
    full_home
    rm "$CLAUDE/FORMAT.md"
    run bash "$SCRIPT" "$PKG" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"FORMAT.md"* ]]
}

@test "every missing file is reported, not only the first" {
    full_home
    rm "$CLAUDE/skills/spec/SKILL.md" "$CLAUDE/skills/caveman/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/spec/SKILL.md"* ]]
    [[ "$output" == *"skills/caveman/SKILL.md"* ]]
}

@test "empty skill file counts as missing" {
    full_home
    : >"$CLAUDE/skills/build/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/build/SKILL.md"* ]]
}

@test "dangling link counts as missing" {
    full_home
    rm "$CLAUDE/skills/check/SKILL.md"
    ln -s "$BATS_TEST_TMPDIR/nowhere" "$CLAUDE/skills/check/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/check/SKILL.md"* ]]
}

@test "set rules dir without any rule: fails" {
    full_home
    rm "$CLAUDE/rules/set/generic.md"
    run bash "$SCRIPT" "$PKG" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"rules/set"* ]]
}

@test "not an activation package: fails, nothing checked" {
    mkdir -p "$PKG"
    run bash "$SCRIPT" "$PKG" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"home-files"* ]]
    [ ! -e "$OUT" ]
}

@test "missing arguments is a usage error" {
    run bash "$SCRIPT" "$PKG"
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
}
