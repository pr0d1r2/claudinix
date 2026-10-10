#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/nix/ck-refs.sh (SPEC nix:V47, nix:B51): the
# references to cavekit's verbs in markdown file (`/ck:<verb>` from
# the plugin, bare `/<verb>`) become `/ck-<verb>`, for the verbs given only.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/nix/ck-refs.sh"
    FILE="$BATS_TEST_TMPDIR/FORMAT.md"
    OUT="$BATS_TEST_TMPDIR/out.md"
}

@test "plugin and bare verb references become /ck-<verb>" {
    echo "Use /spec new, then /ck:build or /check." >"$FILE"
    run bash "$SCRIPT" "$FILE" "$OUT" spec build check
    [ "$status" -eq 0 ]
    [ "$(cat "$OUT")" = 'Use /ck-spec new, then /ck-build or /ck-check.' ]
}

@test "verbs not given, paths and longer words are left alone" {
    echo "Not /grill, /specs, skills/spec/SKILL.md or /usr/bin/check." >"$FILE"
    run bash "$SCRIPT" "$FILE" "$OUT" spec check
    [ "$status" -eq 0 ]
    [ "$(cat "$OUT")" = 'Not /grill, /specs, skills/spec/SKILL.md or /usr/bin/check.' ]
}

@test "references in a row are all rewritten" {
    echo "Run /spec,/build,/check." >"$FILE"
    run bash "$SCRIPT" "$FILE" "$OUT" spec build check
    [ "$status" -eq 0 ]
    [ "$(cat "$OUT")" = 'Run /ck-spec,/ck-build,/ck-check.' ]
}

@test "a missing file is an error" {
    run bash "$SCRIPT" "$BATS_TEST_TMPDIR/none.md" "$OUT" spec
    [ "$status" -eq 1 ]
    [[ "$output" == *"none.md"* ]]
    [ ! -e "$OUT" ]
}

@test "no verbs is a usage error" {
    run bash "$SCRIPT" "$FILE" "$OUT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
}
