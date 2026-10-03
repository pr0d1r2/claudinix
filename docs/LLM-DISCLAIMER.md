# Built by an LLM, in the open

This repository (code, spec, tests and prose) is written by
[Claude Code](https://claude.com/claude-code) running Anthropic's Claude
models. Most commits carry a `Co-Authored-By: Claude` trailer. The current
ratio is whatever these two commands say, which is why it is not written
down here:

```sh
git log --format=%B | grep -c 'Co-Authored-By: Claude'
git rev-list --count HEAD
```

A human owns every decision, reviews the diffs, and is accountable for what
ships. "The model wrote it" explains where code came from. It never moves
the responsibility.

## Why this matters more here than usual

The main product of this repository is a setup script that a Claude Code
cloud environment runs **as root**, before Claude starts, on every fresh
session VM. It installs or configures Nix, points Nix at a binary cache,
and activates a home-manager configuration that decides which tools and
skills the agent has.

A model writes plausible code, and plausible is not correct. A script with
that much power deserves more than trust in its author. You should not run
it because a model was confident about it, and you should not run it
because a human approved it either. Check it.

## What to check before you trust the setup script

In the order it matters:

1. **Read the script you will run, at the commit you will run.** The setup
   line in the cloud environment pins a git commit SHA. Read `setup.sh` at
   that exact SHA, not at the tip of `main`.
2. **Check what it downloads and how it checks it.** The Nix installer is
   pinned to one version and one sha256, and the script refuses to run an
   installer whose hash does not match. Confirm the pin, and confirm the
   refusal path in the script and its bats tests.
3. **Check which binary caches Nix will trust.** The script adds
   `pr0d1r2.cachix.org` and its public key next to `cache.nixos.org`.
   Anything in those caches can land in your session's `/nix/store`. If
   you do not trust that cache, fork the repository and change the config
   block at the top of `setup.sh`.
4. **Know that `accept-flake-config = true` is on.** It lets any cloned
   repository's `flake.nix` `nixConfig` apply. Use this environment only
   with repositories whose owners you trust.
5. **Check that no secret is involved.** The cache is read-only and public,
   so no token is needed. Nothing in this repository, and nothing it asks
   you to paste into the environment dialog, should be a secret value.
6. **Does the gate run for you?** `nix develop`, then `hk check --all`. If a
   claim in this repository is false, that is where it shows first.

## How the work is kept honest

- [`SPEC.md`](../SPEC.md) is written before the code, and every commit
  cites it. Facts about cloud sessions in it are dated measurements from
  real probe sessions, not assumptions.
- Every defect found goes into the spec's `§B` table with the invariant
  that now catches it. The record is meant to be unflattering: `B1` is an
  assumption about the default network allowlist that turned out wrong.
- The gate is [hk](https://github.com/jdx/hk), installed as git hooks when
  you enter the dev shell, and the same definition runs in CI. Every shell
  script has a bats test that was committed, failing, before the script.

## Deeper

[`AGENTS.md`](../AGENTS.md) is the working guide for agents,
[`INTEGRATION.md`](INTEGRATION.md) explains the gate, and
[`SPEC.md`](../SPEC.md) is the law and the backlog.
