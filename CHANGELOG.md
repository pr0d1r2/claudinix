# Changelog

All notable changes to this repository are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com).

## How to read this file

Your cloud environment runs a copy of `setup.sh`. Once the one-line setup
script lands (`SPEC.md` T24), that line names a git commit SHA, and moving to
a newer SHA is how you take an update. Before you change the SHA in the
environment, read every entry between the SHA you run and the one you are
moving to. Each entry says what changes **inside the session VM**, because
that is what you are agreeing to run as root.

Until the first release, entries collect under **Unreleased**. When a commit
is pinned in an environment for the first time, it gets a heading with its
date and short SHA.

Changes to the gate, tests and docs that do not change what a session VM
does are summarised briefly; the git history has the detail.

## Unreleased

### Session VM

- `setup.sh`, imported from the owner's private seed: configures Nix with
  flakes, `accept-flake-config = true` and the read-only
  `pr0d1r2.cachix.org` substituter, and links `nix` into `/usr/local/bin`
  so the Bash tool finds it without sourcing a profile.
- `setup.sh` uses the image's own Nix when it is at least 2.34
  (`NIX_MIN_VERSION`), and installs the pinned, hash-checked Nix 2.35.2
  only below that.
- `setup.sh` writes its `nix.conf` settings as a block between BEGIN and
  END markers and replaces the whole block on every run. Earlier copies of
  the seed appended once and never updated an existing block.
- `allowlist.txt` lists the allowed domains for the environment;
  `env-names.txt` lists its environment variables (names only for
  secrets).
- `probe.sh` reports a session's facts and Nix health, one line per
  check.

### Repository

- The gate: an `hk.pkl` with shellcheck, shfmt, nixfmt, xenolith,
  actionlint, zizmor, typos, secret scanners, the spec tools (mth, itok,
  sherd) and hygiene checks on every commit, and the bats suite plus the
  `bats-mirror` and `tdd-order` guards on every push.
- CI runs the same gate and `nix flake check --all-systems`, fills the
  binary cache on `main`, and verifies the push.
- Docs: `AGENTS.md`, `docs/INTEGRATION.md`, `docs/LLM-DISCLAIMER.md`,
  `docs/linter-coverage.md`, `docs/FACTS.md`, `docs/RUNBOOK.md`,
  `docs/SECURITY.md`.
