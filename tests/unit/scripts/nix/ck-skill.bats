#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/nix/ck-skill.sh (SPEC nix:T154, nix:V47): a
# cavekit skill is copied under the name `ck-<name>`, its frontmatter
# `name:` follows, and its references to cavekit's verbs (`/ck:<verb>`
# from the plugin, bare `/<verb>`) become `/ck-<verb>`, so caveman's own
# `caveman` skill can keep the bare name. Paths such as
# `skills/spec/SKILL.md` and other words are left as they are.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/nix/ck-skill.sh"
    SRC="$BATS_TEST_TMPDIR/src/spec"
    OUT="$BATS_TEST_TMPDIR/out"
    mkdir -p "$SRC/refs"
    cat >"$SRC/SKILL.md" <<'EOF'
---
name: spec
description: Create SPEC.md. Loaded by /build and /ck:check.
---
Run /ck:review, then /build T1 (see skills/spec/SKILL.md).
Not a verb: /specs, /usr/bin/check, the /reviewer, path/build.
/spec at a line start; /grill, /research and /deepen too.
EOF
    echo "See /backprop and /caveman." >"$SRC/refs/notes.md"
}

@test "frontmatter name becomes ck-<name>" {
    run bash "$SCRIPT" "$SRC" spec "$OUT"
    [ "$status" -eq 0 ]
    grep -qx 'name: ck-spec' "$OUT/SKILL.md"
    run ! grep -qx 'name: spec' "$OUT/SKILL.md"
}

@test "plugin and bare verb references become /ck-<verb>" {
    run bash "$SCRIPT" "$SRC" spec "$OUT"
    [ "$status" -eq 0 ]
    grep -qF 'Loaded by /ck-build and /ck-check.' "$OUT/SKILL.md"
    grep -qF 'Run /ck-review, then /ck-build T1' "$OUT/SKILL.md"
    grep -qF '/ck-spec at a line start; /ck-grill, /ck-research and /ck-deepen too.' "$OUT/SKILL.md"
    run ! grep -qF '/ck:' "$OUT/SKILL.md"
}

@test "paths and other words are left alone" {
    run bash "$SCRIPT" "$SRC" spec "$OUT"
    [ "$status" -eq 0 ]
    grep -qF '(see skills/spec/SKILL.md)' "$OUT/SKILL.md"
    grep -qF 'Not a verb: /specs, /usr/bin/check, the /reviewer, path/build.' "$OUT/SKILL.md"
}

@test "every markdown file in the skill is patched, the tree is kept" {
    run bash "$SCRIPT" "$SRC" spec "$OUT"
    [ "$status" -eq 0 ]
    grep -qxF 'See /ck-backprop and /ck-caveman.' "$OUT/refs/notes.md"
}

@test "a skill whose name: is not its directory name: fails" {
    run bash "$SCRIPT" "$SRC" build "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"name: spec"* ]]
    [ ! -e "$OUT" ]
}

@test "a skill without SKILL.md: fails" {
    rm "$SRC/SKILL.md"
    run bash "$SCRIPT" "$SRC" spec "$OUT"
    [ "$status" -eq 1 ]
    [ ! -e "$OUT" ]
}

@test "missing arguments is a usage error" {
    run bash "$SCRIPT" "$SRC" spec
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
}
