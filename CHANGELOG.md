# Changelog

All notable changes to this repository are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com).

## How to read this file

Your cloud environment's setup script is one line that names a git
commit SHA; moving to a newer SHA is how you take an update. Before you change the SHA in the
environment, read every entry between the SHA you run and the one you are
moving to. Each entry says what changes **inside the session VM**, because
that is what you are agreeing to run as root.

Until the first release, entries collect under **Unreleased**. When a commit
is pinned in an environment for the first time, it gets a heading with its
date and short SHA.

Changes to the gate, tests and docs that do not change what a session VM
does are summarised briefly; the git history has the detail.

## Unreleased

- **Renamed to claudinix** ("Claude in cloud on Nix") before the first
  public release. The repository is `pr0d1r2/claudinix`; settings use the
  `CLAUDINIX_` prefix; the `nix.conf` block is marked `claudinix`; files
  live in `/usr/local/lib/claudinix` and `~/.local/state/claudinix/`. The
  working name `nix-claude-code-cloud` stays in the git history.

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
- `setup.sh [SHA]` takes the full commit SHA it was fetched at. The
  environment's setup script is now one line, printed by
  `scripts/setup-line.sh`, that downloads `setup.sh` at that SHA and runs
  it. `setup-line.sh` refuses a commit whose CI run on `main` is not green
  unless you pass `--force`.
- **Opt-in:** with `--agent-home` (or `CLAUDINIX_AGENT_HOME=1`) `setup.sh`
  activates an agent home (home-manager, as root) before Claude starts:
  the owner's set rules, the cavekit skills `spec`, `build`, `check`,
  `backprop`, `caveman`, `FORMAT.md` and a claude-code configuration in
  `~/.claude`. This changes how Claude behaves. Without the flag, setup
  says it skipped the home and how to opt in. The home is built from this
  repository over `git+https` at the SHA (its inputs are fetched over
  `git+https` too, never as `github:` tarballs), falls back to the store
  path recorded in `cloud-home.storepath`, and if both fail warns loudly,
  leaves a marker file and still exits 0. Its closure leaves out man-db
  and systemd. Not yet run in a real cloud session.
- `setup.sh` installs `nix-dev` into `/usr/local/lib/claudinix` and links
  it onto the PATH: `nix develop` with input failover (cache, then
  `git+https` overrides for uncached `github:` inputs, then the locked
  `github:` inputs, then a nixos.org channel tarball), logging the tier it
  reached. It takes an installable (`nix-dev .#ci`), matches nixpkgs in any
  case, and warns when `jq` is missing. Fetched at the same SHA, all files
  or none; every download has a timeout; a failed fetch only warns.
- Owner-specific values (cache host, cache key, repository) sit in one
  fork config block at the top of `setup.sh`.
- `allowlist.txt` now holds only the Nix hosts and `github.com`. Hosts a
  target project needs (crates.io, PyPI, npm, ...) come from the `domains`
  command instead.
- `env-names.txt` offers an optional `BASH_DEFAULT_TIMEOUT_MS=600000`.

### Commands for target projects

Run from the project you will send to the cloud, as
`nix run github:pr0d1r2/claudinix#<app>`:

- `inputs`: lists the flake's `github:` inputs and whether a binary cache
  holds each (`cached`), or whether a session must fetch it from GitHub
  (`uncached`, with the fix: `nix-dev`, or `git+https` inputs).
- `domains`: prints the allowed domains the project needs, detected from
  its lock files, optionally from a session log's proxy refusals.
- `guide`: walks the browser setup steps from the terminal, copying each
  value to paste.
- `probe`: starts a cloud session that runs `probe.sh` on the project and
  prints its report. It refuses a project with no `origin` remote or an
  unpushed branch, and asks before starting a billed session (`--yes`
  skips the question).
- `guide` checks the project's inputs before the first session, tests the
  dev shell with `nix-dev`, and launches with `--model sonnet`.

### Repository

- The gate: an `hk.pkl` with shellcheck, shfmt, nixfmt, xenolith,
  actionlint, zizmor, typos, secret scanners, the spec tools (mth, itok,
  sherd) and hygiene checks on every commit, and the bats suite plus the
  `bats-mirror` and `tdd-order` guards on every push.
- CI runs the same gate and `nix flake check --all-systems`, fills the
  binary cache on `main` (dev shell, checks, the agent home and the
  source of every input it evaluates), uses the cache write token only on
  pushes to `main`, and
  verifies the push.
- The spec is federated with sherd into a root and three nodes (`scripts`,
  `nix`, `docs`), so separate agents can work on each in parallel.
- `just bump-nix <version>` rewrites the pinned Nix version and its sha256
  together.
- Docs: `README.md`, `LICENSE` (MIT), `AGENTS.md`, and under `docs/`:
  SETUP, CLI, CONSUMER, CACHE-CI, EXAMPLE, SESSION, FORKING, MODEL, FACTS,
  RUNBOOK, SECURITY, INTEGRATION, linter-coverage, LLM-DISCLAIMER,
  CONTRIBUTING, CODE_OF_CONDUCT, THIRD-PARTY-NOTICES.
