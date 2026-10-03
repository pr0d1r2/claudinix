# The target-project tools, run on this repo while developing them (SPEC
# I.cmd). From a target project, run the flake app instead:
#   nix run github:pr0d1r2/nix-claude-code-cloud#<app>
# Each recipe is one plain command; the logic lives in bats-covered
# scripts (C15).

# List a flake's github inputs: cached, or attach to the session.
inputs *args:
    scripts/inputs.sh {{ args }}

# Print the allowed domains a cloud environment needs for projects.
domains *args:
    scripts/domains.sh {{ args }}

# Start a cloud session that probes this project; print its report.
probe *args:
    scripts/probe-launch.sh {{ args }}
