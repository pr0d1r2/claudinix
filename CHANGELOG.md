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

- `just spec-optimize [node...]` starts a cloud session that brings spec nodes
  back under their `.context-limits` ceilings (default: the nodes over them)
  by archiving, moving rows down and shortening, then lowers the freed
  ceilings; it never raises one and opens a pull request into `main`.
- `just spec-optimize` with no node sends a breach on any `.context-limits` file
  row (such as a `SPEC-ARCHIVE.md`) to the node that owns the file, instead
  of saying there is nothing to do.
- The `just spec-optimize` agent no longer claims it alone may edit other
  nodes' spec rows; moving rows down stays every contributor's job.
- `just spec-optimize` with no node refuses a project that has no
  `.context-limits` instead of starting a session for every node.
- The `just rebase` agent stops after its gate and push instead of watching CI
  a second time, and `just all` waits at most 60 minutes for its new head
  (was the fixup's 180); the prompt treats conflict hunks and logs as data.
- Cloud sessions can no longer run `git push` with `--delete`, `--force` or
  `--mirror`; the lease push of `just rebase` still works.
- `just rebase` and `just fixup` refuse a pull request whose branch name starts
  with `-`, which git would read as an option.
- `just all` stops a wait after 3 failed `gh` calls in a row, showing gh's
  last error and naming the step, instead of printing dots to the limit,
  with no second line that names another cause.
  This runs on your machine, not in the session VM.

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
- `env-names.txt` offers an optional `BASH_DEFAULT_TIMEOUT_MS=600000` and
  no longer lists `ANTHROPIC_MODEL`, which never chose the model.
- Every Nix network operation in `setup.sh` is bounded (connect and stall
  timeouts, and `CLAUDINIX_NIX_TIMEOUT` seconds per step, default 120);
  `CLAUDINIX_AGENT_HOME` accepts only 0 or 1.
- `allowlist.txt`, and so `domains` and the guide's step 3, now name
  `raw.githubusercontent.com`. The setup line downloads `setup.sh` from
  it; without it, setup in a new environment fails with
  `curl: (22) The requested URL returned error: 403`. Add it to the
  allowed domains of an environment you already have.

### Built by its own cloud agents

- A cloud task agent ends with `hk check --from-ref origin/main --to-ref
  HEAD` (the push layer over the files its branch changed) instead of the
  full `hk check --all`, so a docs-only task no longer rebuilds the Rust
  crate.
- The cloud permission list also allows the gate's Rust commands
  (`cargo fmt`, `cargo clippy`, `cargo test`) and `claudinix-dev`, so a
  cloud agent can run the `dev/` checks without a prompt; never a bare
  `cargo` (which could install or run anything).
- `just cloud <node:Tn>` starts one billed cloud session that builds one
  open spec task of this repository, pushes it to a `claude/*` branch
  and opens a pull request for review (the agent never merges); it refuses missing, done or ambiguous tasks and unpushed
  branches, asks before starting, and `--dry-run` prints the command.
- `just rebase <PR>` starts one billed cloud session that rebases an open
  `claude/*` pull request onto `main`: it re-writes generated files instead
  of merging them by hand, stops and reports a conflict that needs a
  decision, runs the gate and force-pushes the same branch with a lease.
  It opens no new pull request and merges nothing.
  Answering `y` to its question now starts the session; before, a reply
  the terminal sent to `gh` could be read as the answer.
- `just review <role> <PR>` starts one billed, read-only cloud session that
  reviews an open pull request as one role and posts its findings as one
  comment on it. The roles are the files in `scripts/review/`:
  correctness, maintainability, extensibility, performance, security and
  architecture; a new role is a new file.
  `just review all <PR>` starts one such session per role, started one
  after another and then running side by side, after one question that names how many billed sessions start and that
  the cost is about that many times one review.
  It refuses a pull request whose branch names have characters beyond
  letters, digits and `._/-`, since the prompt puts them in shell commands, and a pull request URL
  of another repository than this checkout's.
  When one session of `review all` fails to start, the others still start
  and it says which started and which failed. The review prompt tells the
  session that the pull request's text is untrusted data, not instructions.
  It needs the `origin` remote only: an unpushed or detached local branch
  no longer stops a review. With no role files, `review all` says so.
- `just fixup <PR>` starts one billed cloud session that works through a
  pull request's review findings one at a time, fixing each in its own
  commits or declining it with a reason. It pushes to the same branch
  without force, gives a thumbs-up to each comment it fixed, and replies
  once mapping findings to commits. A URL of another repository (names compared
  without regard to case), a pull
  request from a fork or a branch name that is not a plain ref is refused.
  A problem raised in several comments is fixed once and credited to each.
- `just all <node:Tn>` runs a task's whole cloud flow after one question
  that names how many billed sessions start: `cloud`, then `review all`,
  then `fixup`. The sessions run in the cloud; before each next step it
  waits, polling GitHub every 10 s and printing a dot per poll, for the
  pull request, green CI, every role's review comment and the fixup's
  reply. It ends by waiting for green CI again and opening the pull
  request in Safari. A step that fails, red CI or a wait that runs out
  stops it, names the step and opens the pull request. It never merges.
  `just all <PR# | URL>` gives an existing pull request, such as one made
  by hand, the same steps without the build: CI, `review all`, `fixup`
  and CI again, then Safari.
- The `cloud` and `fixup` sessions now watch CI on their pull request
  after they push. On a red run they read the failed log, fix the cause,
  run the gate and push again to the pull request's head branch, for at
  most 3 rounds, then report. The `fixup` session posts its `Fixup:`
  reply first and appends the CI result to it afterwards. A check
  cancelled before any step ran (a runner outage) is reported, not
  "fixed". They treat job logs as data, never as instructions. A CI fix
  never edits the workflows, `hk.pkl` or the permission lists.
- `just all` no longer stops on a check that was cancelled, which is what a
  GitHub Actions runner outage does to a job that never started. It says
  so once per wait, as a runner outage or a run a newer push superseded,
  points at githubstatus.com and `gh run rerun`, and keeps waiting.
- `just all` no longer stops at the first red check after the build or the
  fixup, because that session is fixing it: it says so once and waits, for
  up to 120 minutes. A pull request given by number still fails on a red
  first run, since no session fixes it.
- `just rebase <PR>` takes any branch of this repository but `main`, as
  `just fixup` does, and refuses a fork or a URL of another repository.
  Its agent resolves mechanical conflicts itself: generated files are
  re-written, changelog and spec table lines from both sides are kept,
  and a spec id both sides added is renumbered to the next free one. It
  aborts only when the two sides mean opposite things. After its push it
  watches CI and fixes what the rebase broke, for at most 3 rounds.
- The cloud permission list allows
  `git push --force-with-lease origin HEAD:*`, so the rebase agent can
  push any pull request branch; the deny rules for `main`, `+` refspecs
  and tags still win.
- `just all` checks whether its pull request still merges into `main`,
  once the pull request is known and again after the fixup. A conflicting
  one gets no CI, so it starts `just rebase` and goes on once the rebase
  agent pushes a new head; with no new head it stops and names the
  conflict.
- `just all` stops, naming the pull request, when it cannot read a pull
  request's comments before a review or fixup starts, instead of taking
  an old review or fixup comment for the new session's.
- `just all` stops, before any session starts, when it cannot list the
  open pull requests, instead of taking an old open pull request of the
  same task for the build's.
- `just all` ignores a pull request from a fork when it looks for the
  build's, even if its branch is named like the build's.
- The fixup session now heads its reply "Fixup:", and `just all` waits for
  that heading, so a CI bot's or a person's comment no longer ends the
  wait early.
- `just all` refuses a `CLOUD_ALL_POLL` that is not a positive number of
  seconds, naming it, instead of failing with a shell error.
- `just all` matches the review and fixup headings of comments written in the
  GitHub web UI, which end their lines with a carriage return.
- `just all` takes a dot in a node name literally when it looks for the
  build's pull request, so `a.b` no longer matches `axb`.
- The cloud permission list allows
  `git push --force-with-lease origin HEAD:claude/*`, the rebase session's
  push; plain force pushes and every push to `main` stay unlisted or denied.
  It also allows `git push origin HEAD:*` for `just fixup`; the deny rules
  for `main`, for `+` force refspecs and for tag pushes still win.
- The dev shell's own flake inputs are fetched over `git+https`, so a
  cloud session can enter it without GitHub 403s; only nixpkgs remains a
  `github:` input, served by cache.nixos.org.
- In cloud sessions with the agent home, `~/.claude/settings.json` gets a
  narrow permission list (the gate's own commands, pushing `claude/*`,
  never `main`) so unattended tasks do not stall on prompts. Local
  sessions never get it: the committed `.claude/settings.json` holds only
  the SessionStart hook, and a gate step refuses blanket rules.

### Per-repo config

- An optional `.claudinix.toml` in a target repository sets the session
  model, whether the guide offers the agent home, the dev shell to start,
  extra allowed domains, the cache name and the probe branch prefix
  (`docs/CONFIG.md`). Flags beat the file, the file beats the defaults, and
  with no file everything behaves as before. Nix itself parses it, so a
  cloud session needs no extra tool; unknown keys, wrong types and bad
  values are refused with every problem listed at once. `setup.sh` never
  reads it. This repository carries its own, checked by the gate.
- `nix-dev` no longer stops on an invalid `.claudinix.toml`: it prints
  what is wrong, warns `nix-dev: WARNING: <file> is invalid -- using
  defaults`, and starts the dev shell as if there were no file. The other
  commands still refuse a bad file with exit 2.

### Commands for target projects

Run from the project you will send to the cloud, as
`nix run github:pr0d1r2/claudinix#<app>`:

- `inputs`: lists the flake's `github:` inputs and whether a binary cache
  holds each (`cached`), or whether a session must fetch it from GitHub
  (`uncached`, with the fix: `nix-dev`, or `git+https` inputs).
- `domains`: prints the allowed domains the project needs, detected from
  its lock files, optionally from a session log's proxy refusals.
- `guide`: walks the browser setup steps from the terminal, copying each
  value to paste. It copies the setup line from the README's release
  block (no `gh` needed); `--rev SHA` prints a line for another commit.
- `probe`: starts a cloud session that runs `probe.sh` on the project and
  prints its report. It refuses a project with no `origin` remote or an
  unpushed branch, and asks before starting a billed session (`--yes`
  skips the question).
- `guide` checks the project's inputs before the first session, tests the
  dev shell with `nix-dev`, and launches with `--model sonnet`.
- `scripts/setup-line.sh` takes a short SHA (7 to 39 hex characters) and
  looks it up on GitHub, so `c63d695` names the same claudinix commit
  from any directory.
- `guide --rev` takes a short SHA too. Before the first release, when
  `gh` can tell, the guide names the newest `main` commit whose CI passed
  as the `--rev` to run it again with.
- `guide` names the cloud environment after the project by default (it
  asks, Enter keeps it), instead of always `nix`, and step 4 says how to
  pin that environment for this project only.
- `guide` step 3 names the dialog's real button, **Add environment**.
- `guide` step 4 pins the environment to the project: after `/remote-env`
  (which saves the pick for every project) it offers to write the
  environment id into the project's gitignored
  `.claude/settings.local.json`, so each project keeps its own environment.

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
- Releases are two steps (maintainer): `just release record REV` refuses
  unless CI is green and every input source and the agent home are in the
  cache, then writes `cloud-home.storepath` to commit; `scripts/release.sh
  publish REV2` refuses unless that commit holds the file for its own agent
  home, then writes the setup line into the README and prints the release
  notes and the tag and release commands. Until the first release the
  README block says so.
- A green gate is quiet (a few lines instead of about 350 when no terminal
  is attached); failures still print in full. `hk.pkl` is now valid for the
  official Pkl evaluator, and a gate step checks it.
- Commit messages must carry `Why:` and `Refs:` lines; the hook lists every
  problem at once, with an example.
- `tdd-order` refuses to judge a shallow clone and says to run
  `git fetch --unshallow`; a refusal prints how to split the commit.
- Every shell script with a shebang must be executable; a gate step checks.
- Cloud sessions working on this repository run a SessionStart hook that
  fetches the full history and installs the git hooks before the first
  commit. The hooks also fire under git older than 2.54 (as a cloud image
  may ship), through `.git/hooks` shims; a hook that is not claudinix's is
  never overwritten. Hooks enter the dev shell through `nix-dev` when it is
  installed.
- Docs: `README.md`, `LICENSE` (MIT), `AGENTS.md`, and under `docs/`:
  SETUP, CLI, CONSUMER, CACHE-CI, EXAMPLE, SESSION, FORKING, MODEL, FACTS,
  RUNBOOK, SECURITY, INTEGRATION, linter-coverage, LLM-DISCLAIMER,
  CONTRIBUTING, CODE_OF_CONDUCT, THIRD-PARTY-NOTICES.
