#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/nix/ck-refs.sh (SPEC nix:V47, nix:B51): the
# references to cavekit's verbs in one markdown file (`/ck:<verb>` from
# the plugin, bare `/<verb>`) become `/ck-<verb>`, for the verbs given only.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/nix/ck-refs.sh"
    FILE="$BATS_TEST_TMPDIR/FORMAT.md"
}

@test "plugin and bare verb references become /ck-<verb>" {
    echo "Use /spec new, then /ck:build or /check." >"$FILE"
    run bash "$SCRIPT" "$FILE" spec build check
    [ "$status" -eq 0 ]
    grep -qxF 'Use /ck-spec new, then /ck-build or /ck-check.' "$FILE"
}

@test "verbs not given, paths and longer words are left alone" {
    echo "Not /grill, /specs, skills/spec/SKILL.md or /usr/bin/check." >"$FILE"
    run bash "$SCRIPT" "$FILE" spec check
    [ "$status" -eq 0 ]
    grep -qxF 'Not /grill, /specs, skills/spec/SKILL.md or /usr/bin/check.' "$FILE"
}

@test "references in a row are all rewritten" {
    echo "Run /spec,/build,/check." >"$FILE"
    run bash "$SCRIPT" "$FILE" spec build check
    [ "$status" -eq 0 ]
    grep -qxF 'Run /ck-spec,/ck-build,/ck-check.' "$FILE"
}

@test "a missing file is an error" {
    run bash "$SCRIPT" "$BATS_TEST_TMPDIR/none.md" spec
    [ "$status" -eq 1 ]
    [[ "$output" == *"none.md"* ]]
}

@test "no verbs is a usage error" {
    run bash "$SCRIPT" "$FILE"
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
}
