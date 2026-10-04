#!/usr/bin/env bash
# The dev shell's job counts follow the measured vCPUs (SPEC T52, C18).
#
# docs/FACTS.md records the cloud VM's vCPU count; nix/dev-shell.nix sets
# HK_JOBS and BATS_NUMBER_OF_PARALLEL_JOBS from it. A count that drifted
# from the measurement, or a measurement that went missing, fails.
#
# Usage: jobs-match-vcpus.sh
# Env:   FACTS_FILE (default docs/FACTS.md), DEV_SHELL_FILE (default nix/dev-shell.nix)

set -euo pipefail

facts="${FACTS_FILE:-docs/FACTS.md}"
dev_shell="${DEV_SHELL_FILE:-nix/dev-shell.nix}"

vcpus="$(sed -nE 's/^\| ([0-9]+) vCPUs.*/\1/p' "$facts" | head -n 1)"
if [ -z "$vcpus" ]; then
    echo "jobs-match-vcpus: no '<N> vCPUs' row in $facts -- nothing to compare the job counts to" >&2
    exit 1
fi

status=0
for variable in HK_JOBS BATS_NUMBER_OF_PARALLEL_JOBS; do
    jobs="$(sed -nE "s/^[[:space:]]*$variable = \"([0-9]+)\";.*/\1/p" "$dev_shell" | head -n 1)"
    if [ "$jobs" != "$vcpus" ]; then
        echo "jobs-match-vcpus: $variable is '${jobs:-unset}' in $dev_shell, the measured vCPUs are $vcpus" >&2
        status=1
    fi
done
exit "$status"
