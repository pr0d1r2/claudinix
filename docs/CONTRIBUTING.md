# Contributing to nix-claude-code-cloud

This repository is built **spec-first**. The design and the build queue live in
[`SPEC.md`](../SPEC.md), and each child directory (`scripts`, `nix`, `docs`)
has its own `SPEC.md`. A human or an agent drives the loop the same way.
[`AGENTS.md`](../AGENTS.md) is the same loop as a short checklist.

The most useful single thing you can send is **a measurement the repository
gets wrong**: a fact in [`FACTS.md`](FACTS.md) that no longer holds, a host the
cloud proxy treats differently than the allowlist says, a setup step that
fails on a fresh session. Output from [`probe.sh`](../probe.sh), or the
transcript of a session, is worth more than a description of one.

## Get set up

Everything the gate needs comes from the flake. Nothing is assumed installed
except Nix with flakes enabled.

```sh
nix develop        # or: direnv allow  (the .envrc is `use flake`)
```

Entering the shell runs
[`scripts/dev/shell-hook.sh`](../scripts/dev/shell-hook.sh), which installs
the git hooks with `hk install`. Each hook then re-enters the pinned shell
itself (`nix develop -c hk run <hook>`), so a commit uses the pinned tools
even from a terminal whose `PATH` is stale.

`flake.nix` declares the owner's cache, `pr0d1r2.cachix.org`, as a substituter
so that `hk` and the other tools are downloaded rather than built. Nix only
honours that for users in `trusted-users`; everyone else gets a source build,
which works but is slow the first time.

To run the whole gate by hand:

```sh
hk check --all     # every step, as CI runs it
hk fix             # the formatters
```

## The loop

- **The `SPEC.md` files are the queue.** `§T` rows are the work: `.` not
  started, `~` in progress, `x` done. Work on one `§T` row at a time. Its
  `cites` column names the invariants (`§V`) and interfaces (`§I`) your change
  must keep.
- **Change the spec on its own.** A spec change is never in the same commit as
  code. A finished task only flips its status cell.
- **A bug found gets a `§B` row** stating its cause and the invariant that
  would have caught it. Do not fix a root cause silently.
- **Ids are never reused.** Finished tasks move to `SPEC-ARCHIVE.md` and keep
  their ids.
- **Test first.** Every shell script is a RED `test:` commit adding the
  failing bats file, then a GREEN `feat:` or `fix:` commit adding the script,
  then any `refactor:` commit with the tests unchanged and green. The guard
  [`scripts/guard/tdd-order.sh`](../scripts/guard/tdd-order.sh) checks that
  each script's test landed in an earlier commit, and
  [`scripts/guard/bats-mirror.sh`](../scripts/guard/bats-mirror.sh) checks that
  every `*.sh` has `tests/unit/<same path>.bats` and the reverse.
- **Shell lives in `scripts/**/*.sh`** (or a root script such as `setup.sh`),
  with `set -euo pipefail`, shellcheck-clean and `shfmt -i 4`. Never embed
  shell in a nix string, an hk step or a heredoc: xenolith (`xnl check`)
  refuses it.
- **Tests are safe to run in parallel.** Each works in its own
  `BATS_TEST_TMPDIR`, unsets `GIT_*` variables in git fixtures, and never
  asserts on wall-clock time.

## The gate

There is one definition of the gate: [`hk.pkl`](../hk.pkl). The git hooks run
it, and CI ([`ci.yml`](../.github/workflows/ci.yml)) enters the same dev shell
and runs `hk check --all`, so a laptop and a runner cannot disagree.

| when | what runs |
|---|---|
| `pre-commit` | the fast set, on the files you changed: shellcheck, shfmt, nixfmt, xenolith, actionlint, zizmor, the spec tools (`mth`, `itok`, `sherd`), typos, the secret scanners and the hygiene checks |
| `commit-msg` | [`scripts/guard/commit-msg.sh`](../scripts/guard/commit-msg.sh) |
| `pre-push`, `hk check --all` | everything above plus the bats suite, `bats-mirror` and `tdd-order` |

[`INTEGRATION.md`](INTEGRATION.md) has the full picture: every step, which
files it sees, and how to reproduce any verdict by hand.

## The one hard rule

**Never `--no-verify`**, on commit or on push. A gate that can be stepped
around is not a gate.

The same applies to the subtler versions: weakening a test, raising a token
ceiling in `.context-limits`, or silencing a lint to get past it. If a rule
is wrong, that is a real and welcome finding: change the rule deliberately,
through the spec, in its own commit, with the reason recorded. The objection
is to routing around a verdict, not to disagreeing with one.

A tool that could not run is a failure, not a pass. Every external tool runs
through [`scripts/hk/run-tool.sh`](../scripts/hk/run-tool.sh), which says so
out loud when the tool is missing.

## Working from a cloud session

If you contribute from a Claude Code cloud session, the facts in
[`FACTS.md`](FACTS.md) apply: the clone is shallow, so run
`git fetch --unshallow` before pushing or `tdd-order` cannot see the RED
commits; your commits are authored as `Claude <noreply@anthropic.com>` with a
`Claude-Session:` trailer, which the `commit-msg` hook accepts; and the branch
you push gets a random suffix.

## Things that will get a patch turned down

- **A bypassed or weakened gate.** See above.
- **A claim with no evidence.** "The proxy allows this host" invites the
  probe line that shows it, with a date.
- **A fix aimed at the symptom.** If a check fires, the question is what it
  found, not how to stop it firing.
- **A rule with no runner.** An invariant that no test, guard or gate step
  executes is a comment with a number on it.
- **A secret, or private information.** No tokens, no private hostnames, LAN
  addresses or self-hosted forge paths, and no private repository named, in
  code, fixtures, docs or commit messages. The repository is public.

## Reporting a bug

Open an issue with what you ran, what you expected, and what happened. Attach
the smallest output that shows it. Before a larger change, open an issue
first: the spec decides what the repository does, and a patch against a rule
the spec does not hold starts with a spec change.

Security issues go privately instead: see [SECURITY.md](SECURITY.md).

## Commits

One logical change per commit, in
[Conventional Commits](https://www.conventionalcommits.org/) form, with a body
that says **why**:

```text
fix(setup): replace the nix.conf block on every run

An existing block with the same marker was never updated, so a changed
setting did not reach a VM that already had the old block. The block is
rewritten whole now.

Why: the managed block must reach VMs that already hold an older one.
Refs: §V.3, §B.2
```

The subject type is one of `feat`, `fix`, `docs`, `test`, `refactor`, `perf`,
`build`, `ci`, `chore`, `style` or `revert`. The body must contain a line
starting `Why:`, and should name the spec ids it touches on a `Refs:` line;
the `commit-msg` hook refuses a message without the `Why:` line. The diff
already says what changed. `Why:` is the only part of the record that cannot
be reconstructed from the tree.

One topic per commit: two docs are two commits, and a spec change is never in
the same commit as code.

One change per pull request, small enough to review in one sitting. CI must be
green. Say in the description which spec rows it serves and what you ran.

## License

By contributing, you agree that your contributions are licensed under the MIT
License, the same terms as the rest of the project. See
[LICENSE](../LICENSE).
