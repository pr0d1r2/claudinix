# AGENTS.md

This repository sets up Nix and an agent home (home-manager) in a Claude
Code cloud session before Claude starts. You are a contributor here, and
probably also a session it prepared.

## Spec workflow here

`SPEC.md` is the law and the backlog. It is caveman-encoded
(`→` leads to, `∴` therefore, `∀` for all, `!` must, `⊥` never). Read it
before you change anything. These rules override the cavekit skill
defaults.

- One `§T` task at a time. Its `cites` column names the invariants (`§V`)
  and interfaces (`§I`) you must keep.
- Commits are Conventional Commits (`feat(scope): ...`), never `T<n>: ...`.
  The body needs a `Why:` line and a `Refs:` line, which `commit-msg`
  checks:

  ```
  fix(setup): refuse a bad installer hash

  Why: a mismatched hash would run an unverified installer.
  Refs: §T.73, `scripts:T79`, `.:C15`
  ```

- One topic per commit. A spec change is never in a code commit.
- Test first, in separate commits: RED (`test:`, a failing bats file),
  GREEN (`feat:`/`fix:`), then REFACTOR (`refactor:`, tests unchanged).
  `tdd-order` and `bats-mirror` check this.
- The status flip is its own commit after GREEN:
  `docs(spec): mark T<n> done`. Then run `mth archive <node>/SPEC.md` when
  the node nears its ceiling (`.context-limits`).
- Never raise a ceiling to get green. Move rows down to the node that owns
  them.
- A failing test or a bug goes into `§B` with the invariant that would
  have caught it (backprop). Do not fix the root cause silently.
- Skills: `/ck:spec`, `/ck:build`, `/ck:check`, `/ck:backprop`; in cloud
  sessions `/spec`, `/build`, `/check`, `/backprop`, `/caveman`. If they
  are not installed, edit `SPEC.md` by hand in the caveman format
  (`~/.claude/FORMAT.md` once the agent home is installed).
- Cavekit asks the user before applying a spec change. An unattended run
  must not stall on that: record the change and say so in your report.

## Federation

Root `SPEC.md` §F lists the nodes. Work under the spec of the node that
owns the files you touch (`scripts/SPEC.md`, `nix/SPEC.md`,
`docs/SPEC.md`); repo-wide rules live in root `SPEC.md`.

- Ids are unique across all nodes. The next id is the highest over every
  `SPEC*.md`, plus 1 (same for `V`, `B`, `C`).
- Cite a parent as `` `.:C15` `` and a sibling as `` `docs:T13` ``.

## The gate

[hk](https://github.com/jdx/hk), defined in [`hk.pkl`](hk.pkl). Every step
and how to run it by hand: [`docs/INTEGRATION.md`](docs/INTEGRATION.md).

- Commit from inside the dev shell (`direnv allow` or `nix develop`). It
  installs the git hooks, and each hook re-enters the pinned shell.
- Run the whole gate: `hk check --all >gate.log 2>&1; echo rc=$?`. Read
  the log only when `rc` is not 0; a green gate is quiet.
- A Bash command past 120 seconds moves to the background and keeps
  going. Wait for the completion notice, which carries the real exit
  status; do not read the 120-second return as the result.
- Never use `--no-verify`. Never weaken a check or edit a test to get
  green: fix the code, or record why the rule is wrong in the spec.
- A tool that could not run is a failure, not a pass.
- Every tracked `*.sh` with a shebang must be executable. Use
  `git update-index --chmod=+x <file>`; `perl -pi` and `sed -i` drop the
  bit, and `core.fileMode` may be false.
- Shell lives in `scripts/**/*.sh` (or root `setup.sh`), with
  `set -euo pipefail`, shellcheck-clean and `shfmt -i 4`. Never embed
  shell in a nix string, an hk step or a heredoc. Every `*.sh` needs
  `tests/unit/<same path>.bats` and the reverse.
- Tests must be parallel-safe: own `BATS_TEST_TMPDIR`, unset `GIT_*` in
  git fixtures, no wall-clock assertions.

## Docs

If you change an app's behaviour (`nix-dev`, `inputs`, `domains`,
`guide`, ...), add a follow-up `docs:` commit that updates
[`docs/CLI.md`](docs/CLI.md) and any other doc that names it.

## Cloud sessions

Measured in real sessions: root, `HOME=/root`, `CLAUDE_CODE_REMOTE=true`.

- A SessionStart hook (`scripts/dev/session-start.sh`) runs
  `git fetch --unshallow` and `nix develop -c true` (installs the hooks).
  It is silent on success. If it warns, do what it says before you
  commit; `tdd-order` refuses a shallow clone.
- Hooks and session start enter the dev shell through `nix-dev` when it is
  installed (every cloud session), else `nix develop`.
- git 2.54 or newer runs the config-based hooks. An older git, such as a
  cloud image's, runs the `.git/hooks` shims copied from
  `scripts/dev/legacy-hook.sh`, which run the same command.
  `scripts/dev/shell-hook.sh` never overwrites a hook that is not its own.
- Commits are authored as `Claude <noreply@anthropic.com>` with a
  `Claude-Session:` trailer; `commit-msg` accepts that.
- The pushed branch gets a random suffix (`claude/<name>-<suffix>`).
- GitHub goes through a proxy. A `github:` flake input missing from a
  binary cache fails with 403; use `git+https://github.com/<owner>/<repo>`. This repo's dev-shell inputs are
  fetched that way, so only nixpkgs is a `github:` input (served by
  cache.nixos.org).
- Launch cloud tasks with `just cloud <node:Tn>` (`--dry-run` first), never
  a hand-written `claude --cloud`. A cloud agent pushes
  `claude/<node>-<task>` and opens no PR; the owner reviews and merges.

## Choosing the model

This project launches cloud jobs with `--model sonnet`; without it,
sessions ran on Opus ([`docs/FACTS.md`](docs/FACTS.md)). Put the task text
first, the model after:

```sh
claude --cloud "<task>" --model sonnet
```

`--model` first fails with `--cloud requires a description`. The
`ANTHROPIC_MODEL` variable does not choose the model. The `Co-Authored-By`
trailer of a session's commits shows which model ran.
