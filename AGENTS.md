# AGENTS.md

This repository sets up Nix, and an agent home built with home-manager,
inside a Claude Code cloud session before Claude starts. You are probably
one of the agents it serves, so the rules below apply to you twice: once as
a contributor here, and once as the session the setup script prepares.

## Start from the spec

[`SPEC.md`](SPEC.md) is the law and the backlog. Read it before you change
anything, and cite it in every commit.

- Work on one `§T` task at a time. Its `cites` column names the invariants
  (`§V`) and interfaces (`§I`) your change must keep.
- Change the spec only through `/ck:spec`, and never in the same commit as
  code. `/ck:build` may only flip a task's status cell.
- A failing test or a bug you find goes into `§B` with the invariant that
  would have caught it (`/ck:backprop`). Do not fix the root cause silently.

`SPEC.md` is caveman-encoded. The symbols carry meaning:

```
→ leads to    ∴ therefore    ∀ for all      ! must
⊥ never       ? open/optional ≤ at most     ∈ in
```

## The gate

The gate is [hk](https://github.com/jdx/hk), defined once in
[`hk.pkl`](hk.pkl). [`docs/INTEGRATION.md`](docs/INTEGRATION.md) lists every
step and how to run it by hand.

- **Commit from inside the dev shell** (`direnv allow`, or `nix develop`).
  Entering it installs the git hooks, and each hook re-enters the pinned
  shell itself.
- **Never use `--no-verify`.** A refusing gate is the system working.
- **Never raise a ceiling, weaken a check or edit a test to get green.**
  Fix the code, or record why the rule is wrong through `/ck:spec`.
- **A tool that could not run is a failure, not a pass.** Every external
  tool runs through `scripts/hk/run-tool.sh`, which says so out loud.
- Run the whole gate by hand with `hk check --all`.

## Commits

Humans read the history, so each commit is about one thing.

- Conventional Commits subject, then a body with a `Why:` line and the spec
  ids it touches (`Refs: §T.19, §V.17`). The `commit-msg` hook checks the
  subject and the `Why:` line.
- One topic per commit. Two docs are two commits. A spec change is never in
  the same commit as code.
- Test first, in separate commits: RED (`test:`, a failing bats file), then
  GREEN (`feat:` or `fix:`), then any REFACTOR (`refactor:`, tests
  unchanged and green). The `tdd-order` guard checks that every script's
  test landed in an earlier commit, and `bats-mirror` checks that every
  `*.sh` has `tests/unit/<same path>.bats` and the reverse.
- Shell lives in `scripts/**/*.sh` (or a root script such as `setup.sh`),
  with `set -euo pipefail`, shellcheck-clean and `shfmt -i 4`. Never embed
  shell in a nix string, an hk step or a heredoc; xenolith (`xnl check`)
  refuses it.
- Tests must be safe to run in parallel: each works in its own
  `BATS_TEST_TMPDIR`, unsets `GIT_*` variables in git fixtures, and never
  asserts on wall-clock time.

## Working inside a cloud session

These facts were measured in real sessions (`SPEC.md` C8):

- The session runs as root with `HOME=/root`, and sets
  `CLAUDE_CODE_REMOTE=true`.
- The clone is shallow. Run `git fetch --unshallow` before pushing, or
  `tdd-order` cannot see the RED commits.
- Your commits are authored as `Claude <noreply@anthropic.com>` with a
  `Claude-Session:` trailer; the `commit-msg` hook accepts that.
- The branch you push gets a random suffix (`claude/<name>-<suffix>`).
- A Bash command that runs past 120 seconds moves to the background and
  keeps going. Its real exit status arrives only with the completion
  notice, so wait for it; do not read the 120-second return as the result.
- GitHub traffic goes through a proxy. Nix `github:` inputs that are not
  in a binary cache fail with 403; fetching the same repository as
  `git+https://github.com/<owner>/<repo>` works.

## Choosing the model

Cloud jobs default to Sonnet 5.5. Launch them with the task text first and
the model after it:

```sh
claude --cloud "<task>" --model sonnet
```

`--model` before the task fails with `--cloud requires a description`. The
`ANTHROPIC_MODEL` environment variable does not choose the session's model.
Check which model ran from the `Co-Authored-By` trailer of its commits.
