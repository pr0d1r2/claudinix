#!/usr/bin/env bats
# Unit tests for scripts/lib/spec-nodes.sh, the one reader of the root
# spec's §F table (SPEC .:V48, B61): cloud-launch.sh and the node-names
# guard both call it.

setup() {
    LIB="$BATS_TEST_DIRNAME/../../../../scripts/lib/spec-nodes.sh"
    SPEC="$BATS_TEST_TMPDIR/SPEC.md"
    # shellcheck source=/dev/null
    source "$LIB"
}

@test "spec_f_nodes prints the first column of every §F row" {
    printf '%s\n' '## §F FEDERATION' '' 'dir|owns|⊥owns|tokens' \
        'scripts|shell|-|-' 'docs|prose|-|-' >"$SPEC"
    run spec_f_nodes "$SPEC"
    [ "$status" -eq 0 ]
    [ "$output" = "scripts
docs" ]
}

@test "spec_f_nodes ends the table at its first blank line" {
    printf '%s\n' '## §F FEDERATION' '' 'dir|owns' 'scripts|shell' '' \
        'note: a-b|c' >"$SPEC"
    run spec_f_nodes "$SPEC"
    [ "$output" = scripts ]
}

@test "spec_f_nodes ignores rows of other sections" {
    printf '%s\n' '## §F FEDERATION' '' 'dir|owns' 'scripts|shell' '' \
        '## §T TASKS' 'id|status' 'T1|.' >"$SPEC"
    run spec_f_nodes "$SPEC"
    [ "$output" = scripts ]
}

@test "spec_f_nodes prints nothing for a header-only table or no §F" {
    printf '%s\n' '## §F FEDERATION' '' 'dir|owns' >"$SPEC"
    run spec_f_nodes "$SPEC"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    printf '%s\n' '## §G GOAL' 'x' >"$SPEC"
    run spec_f_nodes "$SPEC"
    [ -z "$output" ]
}

@test "spec_open_tasks prints the ids of open §T rows, without open questions, done rows or other sections" {
    printf '%s\n' '## §V INVARIANTS' 'T9|.|not a task|-' '' '## §T TASKS' '' 'id|status|task|cites' \
        'T1|.|build it|-' 'T2|x|done|-' 'T3|.|? decide first|-' 'T4|~|started|-' 'T5|.|build more|-' >"$SPEC"
    run spec_open_tasks "$SPEC"
    [ "$status" -eq 0 ]
    [ "$output" = "T1
T5" ]
}

@test "spec_open_tasks prints nothing for a spec without §T" {
    printf '%s\n' '## §G GOAL' 'T1|.|x|-' >"$SPEC"
    run spec_open_tasks "$SPEC"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
