# The target-project tools, run on this repo while developing them (SPEC
# I.cmd). From a target project, run the flake app instead:
#   nix run github:pr0d1r2/claudinix#<app>
# Each recipe is one plain command; the logic lives in bats-covered
# scripts (C15).

# Bare `just` lists the recipes instead of running the first one.
[private]
default:
    @just --list --unsorted

# List a flake's github inputs: cached, or uncached (nix-dev fetches those over git).
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

# Build one spec task (`Tn` or `node:Tn`) in a billed cloud session; `--dry-run` prints the command.
cloud *args:
    scripts/cloud-task.sh {{ args }}

# Rebase one claude/* pull request onto main in a billed cloud session; `--dry-run` prints the command.
rebase *args:
    scripts/cloud-rebase.sh {{ args }}

# Review one pull request as one role (`scripts/review/<role>.md`) in a billed, read-only cloud session.
review *args:
    scripts/cloud-review.sh {{ args }}

# Fix a pull request's review findings, one by one in separate commits, in a billed cloud session.
fixup *args:
    scripts/cloud-fixup.sh {{ args }}

# Build a task, wait for CI, review by every role, fix up, wait for CI, open the PR in Safari; `--dry-run` prints the plan.
all *args:
    scripts/cloud-all.sh {{ args }}

# Pin setup.sh to another Nix release: version and installer sha256 together.
bump-nix ver:
    scripts/bump-nix.sh {{ ver }}

# Cut a release (maintainer): `release record [REV]`, commit, `release publish SHA`.
release *args:
    scripts/release.sh {{ args }}
