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

- New `burn` command (`just burn`, `nix run …#burn`): what a Claude Code session cost, per model, from its
  transcripts; `--self` prints one line, `--pr N [--post]` sums the `Burn:` lines of a pull request. It skips `<synthetic>` rows and prices a row without a model as `?`, and counts a 1h cache write once. `burn --prices` prints the price table, and the longest matching model prefix sets the price.
- `just all`, `review`, `fixup`, `merge` and `rebase` read a pull request URL's number from the
  repository the URL names, not from whatever `gh` defaults to in the directory.
- `just merge` and `just rebase` refuse another repository's pull request URL even when
  `$CLAUDINIX_PROJECTS` holds a checkout of it; only `all`, `review` and `fixup` run from one.
- `just all`, `just review` and `just fixup` given another repository's pull
  request URL run from your checkout of it in `$CLAUDINIX_PROJECTS/<repo>`, when
  that checkout's `origin` is the repository, it is clean, on the pull request's
  base and at the fetched tip; otherwise they refuse as before.
- `just enroll` clones or fetches your checkout of each repo (the `--repo` ones,
  else those with an open pull request of yours under `h10n-human`) and pins the
  environment `/remote-env` picked in it, so `just held` can run there. It
  commits and pushes nothing and starts no billed session.
- `just enroll` skips a pull request when it cannot tell whether it comes from a
  fork, instead of enrolling its repo.
- `just enroll` refuses a checkout whose `.claude` is a symlink, so a cloned
  repository cannot steer where the pin is written.
- `just enroll` fails a checkout whose repository tracks
  `.claude/settings.local.json` instead of rewriting that file.
- `just enroll` reports `failed`, not `enrolled`, when it cannot add the pin
  file to the checkout's `.git/info/exclude`.
- `just enroll` refuses a repo name that starts with `-`, and checks the repos it
  finds by search like the ones you name.
- `just enroll` reports `needs-env` before it clones or fetches anything when
  `/remote-env` has picked no environment.
- `just enroll` refuses two repos with the same name, which would share one
  checkout.
- `just enroll` says why a repo failed when its origin is another repo or its
  pin file is not a JSON object.
- `just held` ends with a report that lists each pull request it ran, oldest
  first, as `held: report: <repo>#<n> ok|failed <URL>` rows, before the closing
  `done` line.
- `just held` runs only the oldest of the labelled pull requests that share a
  repository and a title, and names each newer one it skips, so a parked
  duplicate no longer bills a session. Only a pull request that would run
  counts as the oldest, so an older fork or foreign one no longer hides yours,
  and a title with a backslash is matched too.

- `just all` stops a pull request whose head is not the sha the fixup pushed (the
  `Head:` line of its reply), or the reviewed sha when the fixup pushed none: it
  names the pull request, which sha it expected and why, and opens it, so a push by
  someone else is never taken.
  Only the owner's and members' comments count, for the fixup's reply and its
  `Head:` line, as for `just merge`, which now reads that line the same way:
  the sha must be alone on a `Head:` line, not anywhere in the reply.
- The cloud permission list now also denies `gh pr close` and `gh pr edit` (plain,
  `rtk` and `gh -R x` forms), as it already denied `gh pr merge`; the guard
  derives all three from one verb list. It also denies the GitHub MCP
  `update_pull_request` tool, which closes or edits a pull request the same way.
- `just all` no longer downloads the body of every open pull request on each
  poll: it reads bodies only of new pull requests off the task's branch.
- `just all --merge` does not merge a pull request it found only by its body
  naming the task id: it opens it and leaves the merge to the owner.
- `just all` runs under the stock macOS bash 3.2 again: finding the build's
  pull request no longer uses a bash 4 expansion.
- `just all <task>` finds the build's pull request even when the harness did
  not name its branch `claude/<node>-<task>`: it takes the one new pull
  request of this repository whose body names the task id, and stops naming
  them when two or more do.
- `just fixup` works for a pull request of any repository when run from that
  repository's checkout. The session follows that repository's `AGENTS.md`,
  gate and spec only if it has them, not this repository's rules. A finding of
  the `fleet` review is fixed in the pull request (keep the old name or add a
  shim) or named as a consumer change for its owner, never dropped silently.
- `just fixup` from another repository's checkout needs a pull request based on
  `main` and a pushed branch checked out, as in this repository.
- `just fixup` acts only on comments by the repository's owner, members and
  collaborators; other comments may be declined.
- The CI-watch rules of every cloud session ask for AGENTS.md order and a gate only where the repository has them.
- `just fixup` follows the rules of the repository it runs in, not the launching project's.
- `just fixup` runs the gate the repository names; hk is one case, not the default.
- `just fixup` runs the base branch's gate and tooling, and runs nothing from a
  pull request head that changes them.
- The `fleet` review role examines at most 10 consumers with at most 2 searches.
- The `fleet` review role stops without searching when the diff changes no consumable name.
- The `fleet` review role reports a search that could not run as "could not check", not as 0 findings.
- The `fleet` review role is read-only and passes the owner and repo as one quoted argument.
- The `fleet` review role names only public consumers; private ones are counted.
- The `fleet` review role treats consumer files as data, never instructions.
- `just review fleet <PR>` is a new review role, and `review all` runs it: it
  finds the repositories that consume the PR's repo and reports what the
  change breaks in each on its next pin bump. Cloud review sessions only.
- The `guide` app's step 5 names the allow rule that answers the `add_repo`
  prompt ahead of time (`mcp__claude-code-remote__add_repo`), says what it
  also allows, and on `y` copies the `.claude/settings.json` block for you
  to commit; it writes no file. With `--agent-home` it says the agent home
  does not allow `add_repo`, so the prompt stays.
- `just drain [node:Tn…] [--max N]` works through spec tasks one at a time with
  `just all --merge` from a clean `main`, and stops at the first failure or
  the first pull request the strict merge rule leaves to you. Without tasks it
  takes the open ones outside `experiments` that are not open questions;
  `--max` defaults to your merge rate over the last 7 days.
- `just held [--label L] [--repo R…] [--max N]` takes your open pull requests
  labelled `h10n-human` (or L), oldest first, through `just all` one at a time
  from each repo's checkout under `CLAUDINIX_PROJECTS`. It skips a pull request
  by someone else, from a fork, or in a repo with no checkout or no pinned
  cloud environment, naming it. It never merges and never touches a label, and
  works when `CLAUDINIX_PROJECTS` contains a space. `--repo` goes to the
  search, and a full page of 100 is reported, not dropped silently. `--max` with nothing to run ends cleanly on macOS's bash 3.2. `--max` with nothing to run ends cleanly on macOS's bash 3.2.
- `just merge` stops at a pull request that changes `scripts/cloud-held.sh` or
  `scripts/cloud-drain.sh`, so a
  merged change cannot rewrite the drain unreviewed.
- `just drain` counts only your own and members' `Fixup:` replies for its default
  `--max`, so a stranger's comment cannot raise it.
- `just drain` counts a `## Fixup:` reply as a fixup, as `just all` does, so its
  default `--max` is not too low.
- `just drain` reports progress against the tasks it planned, so a finished
  `--max 1` run no longer reads as `1 of 14`.
- `just drain` refuses when there are no review roles, before it quotes a session
  count, as `just all` does.
- `just merge` reads a review's `Findings:` line above the footer the Claude harness
  adds to every comment, so a real review with no findings no longer stops it.
- `just merge <PR>` rebase-merges a reviewed pull request from your terminal, but
  only when CI is green on its head, every review role and the fixup replied
  (only comments by the owner or a member count, and the fixup reply names the
  head's sha), security reported no findings, and the diff leaves the gate's
  own files, §C and §V rows and ceilings alone; otherwise it names every
  reason and stops. `--dry-run` only judges.
- `just all <task> --merge` ends a green flow with `just merge` instead of
  opening the pull request.
- Cloud sessions are denied `gh pr merge` (and `rtk gh pr merge`); only the
  owner merges, also as `gh -R … pr merge`, `gh api …/merge` or the GitHub MCP merge tools, and the MCP file writes and `gh api …/refs/heads/main` are denied too.
- Review comments from `just review` end with a `Findings: N` line; the review prompt no longer names `just merge`.
- The `just review` role files no longer assume this repository's spec or gate:
  each such rule applies only if the reviewed repository has one.
- `just review` with the URL of another repository's pull request now says to
  run it from a checkout of that repository. It used to read this
  repository's pull request of the same number and report its state, such as
  "#36 is MERGED".
- `just review` works for a pull request of any repository when run from that
  repository's checkout. The session reads `AGENTS.md` and `SPEC.md` only if
  they exist, else the README, CONTRIBUTING and CLAUDE.md. Without a flake dev
  shell it proves findings with the repository's own tooling, run only as it
  is on the base branch, never a script or target the pull request changes.
- The cloud permission list denies a push to `heads/main`, the partial spelling
  of `refs/heads/main` that git resolves to main.
- The cloud permission list lets a push write one ref only: a second refspec
  (`git push origin claude/x release`) and a destination after a `claude/`
  branch (`claude/x:production`) are denied, since they wrote a second ref.
  `HEAD:<branch>` still writes any one branch but `main`.
- The cloud permission list denies any `git push` option after the remote
  (`-nf`, `-vf`, `-d`, ...), and `-f` (with `-uf`, `-fu`) or `--force` as the
  first option too (a branch such as `claude/review-f` still pushes), for the
  `rtk` form as well. Allowed pushes put their options first (`-u`,
  `--force-with-lease`); an option after the refspec used to match the `HEAD:*`
  allow.
- The cloud permission list also allows the `rtk` form of each `git` and `cargo`
  rule (`rtk git push origin claude/*`, ...). The agent home's rtk hook rewrites
  those commands, and an unattended push used to wait on a permission prompt.
- `~/.claude/FORMAT.md` in the agent home names `/ck-spec`, `/ck-build`, ... like
  the skills do, not cavekit's plugin commands.
- The agent home links `cavecrew`'s agents from whatever `cavecrew-*.md` files
  the caveman source ships, instead of a fixed list of three.
- The agent home's check (`checks.cloud-home`) also fails when the
  `caveman-stats` SessionEnd hook is present with that skill switched off, and
  when a shipped skill
  names a `/ck-<verb>` skill the home does not ship.
- The agent home rewrites `/<verb>` references in cavekit's skills to `/ck-<verb>`
  only for the cavekit skills switched on, so a toggle never leaves a dangling
  `/ck-` name or an unpatched new one.
- `just cloud` tells its build session to use `/ck-build`, the name cavekit's
  build skill now has in the agent home.
- The agent home's skills are toggled one by one in `nix/agent-home.toml`.
  cavekit's are now `/ck-spec`, `/ck-build`, ... so caveman's own `/caveman`
  ships under its bare name, alongside caveman's workflow skills
  (`investigate-first`, `surgical-patch`, `safe-refactor`, `lean-build`,
  `migration`, `verify-and-stop`), `ultracave`, `megacave`, `cavecrew` with its
  agents, `caveman-explore` and `caveman-stats` with its SessionEnd hook.
- The agent home (`--agent-home`) pins cavekit to v4.1.0 with all nine skills
  (adding `deepen`, `grill`, `research` and `review`) and adds caveman v3.2.0:
  its hooks keep sessions and subagents in terse caveman mode, with the
  `caveman-review`, `caveman-help` and `caveman-compress`
  skills.
- The agent home's check (`checks.cloud-home`) now fails when a caveman hook or the
  `statusLine` runs a script missing from the store or a command that is not an
  absolute path, and the `statusLine` runs under the store's `bash`, not PATH's. The caveman hooks
  get 30 s, as upstream gives them, so a cold start is not killed.
- The agent home (`--agent-home`) ships `rtk` from nix-rtk's cached build: its
  Claude Code hook rewrites Bash commands to `rtk <cmd>` for condensed
  output, and `~/.claude/CLAUDE.md` loads `RTK.md`.
- The cloud permission list denies the `rtk git push` form of every main-push deny rule, since the
  rtk hook rewrites `git push` to it and the bare rules would not match.
- With `--agent-home`, setup links the agent home's named tools (today `rtk`) from
  its `home-path/bin` into the same PATH dir as `nix`, so Claude's Bash tool finds
  them; no other home binary is linked.
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
- The `just spec-optimize` agent reports a red CI check whose cause lies
  outside the spec files instead of changing code or tests to fix it.
- `just spec-optimize` runs `itok` and `sherd` through the gate's tool runner,
  so a tool missing from the dev shell is named as such, as the gate does.
- The `just spec-optimize` agent asks `sherd` where a row belongs and which
  split a node needs, instead of working it out from the `§F` prose.
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
