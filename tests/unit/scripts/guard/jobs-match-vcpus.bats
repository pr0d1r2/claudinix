#!/usr/bin/env bats
# Unit tests for scripts/guard/jobs-match-vcpus.sh (SPEC T52).

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/guard/jobs-match-vcpus.sh"
    export FACTS_FILE="$BATS_TEST_TMPDIR/FACTS.md"
    export DEV_SHELL_FILE="$BATS_TEST_TMPDIR/dev-shell.nix"
}

write_facts() {
    printf '| %s | 2026-10-03 | probe 6 |\n' "$1" >"$FACTS_FILE"
}

write_shell() {
    printf 'BATS_NUMBER_OF_PARALLEL_JOBS = "%s";\nHK_JOBS = "%s";\n' "$1" "$2" >"$DEV_SHELL_FILE"
}

@test "both job counts equal the measured vCPUs: passes" {
    write_facts "4 vCPUs, 15 GB RAM, no swap."
    write_shell 4 4
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "HK_JOBS differs from the vCPUs: fails naming HK_JOBS" {
    write_facts "4 vCPUs, 15 GB RAM, no swap."
    write_shell 4 2
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"HK_JOBS"* ]]
}

@test "bats jobs differ from the vCPUs: fails naming the bats variable" {
    write_facts "4 vCPUs, 15 GB RAM, no swap."
    write_shell 8 4
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"BATS_NUMBER_OF_PARALLEL_JOBS"* ]]
}

@test "no vCPU row in FACTS: fails rather than passing unchecked" {
    write_facts "16 GB RAM."
    write_shell 4 4
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"vCPU"* ]]
}

@test "a job count missing from the dev shell: fails" {
    write_facts "4 vCPUs, 15 GB RAM, no swap."
    printf 'HK_JOBS = "4";\n' >"$DEV_SHELL_FILE"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"BATS_NUMBER_OF_PARALLEL_JOBS"* ]]
}
