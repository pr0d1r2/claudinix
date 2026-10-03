# The target-project tools, run on this repo while developing them (SPEC
# I.cmd). From a target project, run the flake app instead:
#   nix run github:pr0d1r2/claudinix#<app>
# Each recipe is one plain command; the logic lives in bats-covered
# scripts (C15).

# List a flake's github inputs: cached, or attach to the session.
inputs *args:
    scripts/inputs.sh {{ args }}

# Print the allowed domains a cloud environment needs for projects.
domains *args:
    scripts/domains.sh {{ args }}

# Walk the setup steps; `just guide update` for the update flow.
guide *args:
    scripts/guide.sh {{ args }}

# Start a cloud session that probes this project; print its report.
probe *args:
    scripts/probe-launch.sh {{ args }}

# Pin setup.sh to another Nix release: version and installer sha256 together.
bump-nix ver:
    scripts/bump-nix.sh {{ ver }}
