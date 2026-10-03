# Integration

How this repository's gate is put together, and how to run any part of it by
hand.

The gate itself lives in [`hk.pkl`](../hk.pkl) and that file is the only
definition of it. If this document and `hk.pkl` ever disagree, `hk.pkl` is
right and this file has a bug.

## One definition, three callers

| caller | set | when |
|---|---|---|
| `pre-commit` hook | `fast`, 21 steps | every commit, on the staged files |
| `pre-push` hook | `all`, 24 steps | every push |
| `hk check --all` in CI | `all`, 24 steps | every push to `main` and every pull request |

A fourth hook, `commit-msg`, runs one step on the commit message.

`all` is `fast` plus three steps that judge the branch rather than a single
commit: the bats suite, `bats-mirror` and `tdd-order`. They stay off
`pre-commit` on purpose. A RED commit adds a failing test before its script
exists, so running the suite or the mirror check on every commit would make
the RED commit impossible.

[`ci.yml`](../.github/workflows/ci.yml) does not list any step. It enters
the pinned dev shell and delegates:

```sh
nix develop --command hk check --all --check --no-fail-fast
nix flake check --all-systems
```

Locally the gate stops at the first failure, because the loop is cheap. CI
passes `--no-fail-fast`, because a round trip costs minutes and whoever
fixes it should see every failure at once.

## Where the tools come from

Every tool comes from the dev shell in [`flake.nix`](../flake.nix) and
[`nix/dev-shell.nix`](../nix/dev-shell.nix), pinned by `flake.lock`.
Entering the shell (`direnv allow`, or `nix develop`) runs
[`scripts/dev/shell-hook.sh`](../scripts/dev/shell-hook.sh), which runs
`hk install` and rewrites each installed hook to
`nix develop -c hk run <hook>`. A commit therefore always uses the pinned
tools, even from a terminal whose `PATH` is stale.

Each external tool is called through
[`scripts/hk/run-tool.sh`](../scripts/hk/run-tool.sh). If the tool is not
on `PATH`, the step fails with "gate could not run, nothing was checked".
A missing tool must never look like a pass, and never like a finding.

## The steps

Run any step by hand from inside the dev shell. `{{files}}` means the files
hk hands the step; by hand, name the files yourself.

### On every commit (`fast`)

| step | files | by hand |
|---|---|---|
| `shellcheck` | `*.sh`, `*.bats`, `.envrc` | `shellcheck <files>` |
| `shfmt` | `*.sh`, `*.bats` | `shfmt --diff --indent 4 <files>` (fix: `--write`) |
| `nixfmt` | `*.nix` | `nixfmt --check <files>` (fix: drop `--check`) |
| `xenolith` | `*.nix`, `*.sh`, `*.bats`, `xenolith.toml` | `xnl check <files>` |
| `actionlint` | `.github/workflows/*.yml` | `actionlint <files>` |
| `zizmor` | `.github/workflows/*.yml` | `zizmor --offline --no-progress --persona=pedantic <files>` |
| `spec-fmt` | every `SPEC.md` | `mth fmt --check <node>/SPEC.md` (fix: `mth fmt`) |
| `spec-check` | every `SPEC.md` | `mth check <node>/SPEC.md` |
| `spec-tokens` | `SPEC.md` files, `.context-limits` | `itok check` |
| `federation` | `SPEC.md` files, `.context-limits` | `sherd validate` |
| `nav` | `SPEC.md` files | `sherd sync --check` (fix: `sherd sync`) |
| `spec-structure` | `SPEC.md` files | `sherd check` |
| `budget` | `SPEC.md` files, `.context-limits` | `sherd budget` |
| `typos` | every file | `typos --force-exclude <files>` |
| `no-private-key` | every file | `hk util detect-private-key <files>` |
| `ripsecrets` | every file | `ripsecrets <files>` |
| `trailing-whitespace` | every file | `hk util trailing-whitespace <files>` |
| `final-newline` | every file | `hk util end-of-file-fixer <files>` |
| `line-endings` | every file | `hk util mixed-line-ending <files>` |
| `no-large-files` | every file | `hk util check-added-large-files <files>` |
| `no-merge-conflict` | every file | `hk util check-merge-conflict --assume-in-merge <files>` |

A few notes on why the steps look the way they do:

- **xenolith** enforces one language per file: no shell inside nix strings,
  hk steps or heredocs. The `xnl` binary is built with only the `nix` and
  `shell` languages, because those are the languages this repository has.
- **zizmor** runs `--offline`. A gate must not need the network, and inside
  a cloud session the injected `GH_TOKEN` placeholder makes online audits
  fail with 401.
- **The spec steps** (`mth`, `itok`, `sherd`) keep the spec well formed and
  under the token ceilings in `.context-limits`. The spec is federated: the
  root `SPEC.md` names its child nodes (`scripts`, `nix`, `docs`) in a
  `§F` table, and each node has its own `SPEC.md`. `mth` runs once per
  changed node; `sherd check` follows citations across nodes, and
  `sherd sync --check` keeps each node's `§N` in step with its parent's
  `§F`. When a spec outgrows its ceiling, move rows down to the node that
  owns them; do not raise the number. Finished tasks move to
  `SPEC-ARCHIVE.md` with `mth archive`.
- **Secrets** are checked twice because the two tools answer different
  questions: `detect-private-key` finds key blocks, `ripsecrets` finds token
  shapes. The repository is public from its first push.

### On every push (`all` adds)

| step | by hand |
|---|---|
| `bats` | `bats --recursive tests/unit` |
| `bats-mirror` | `scripts/guard/bats-mirror.sh` |
| `tdd-order` | `scripts/guard/tdd-order.sh [range]` |

`bats-mirror` checks that every tracked `*.sh` has
`tests/unit/<same path>.bats` and that every bats file still has its script.
`tdd-order` checks that each commit adding a script had the script's test in
its parent commit. It reads history, so it needs a full clone: in a shallow
clone (as in a cloud session) run `git fetch --unshallow` first.

### On every commit message

| step | by hand |
|---|---|
| `commit-msg` | `scripts/guard/commit-msg.sh <message-file>` |

The subject must follow Conventional Commits and the body must have a
`Why:` line. Merge, revert and fixup subjects pass untouched.

### In `nix flake check`

| check | what it runs |
|---|---|
| `checks.<system>.xenolith` | [`scripts/nix/xenolith-check.sh`](../scripts/nix/xenolith-check.sh): `xnl check .` over the flake source |

### In CI only

On `main`, `cachix/cachix-action` pushes what the gate job built to
`pr0d1r2.cachix.org`. A separate `verify cache` job then runs
[`scripts/ci/verify-cachix.sh`](../scripts/ci/verify-cachix.sh), which asks
the cache for each output's narinfo and fails on anything but HTTP 200. A
push step that exits 0 is not proof that anything arrived.

## Parallelism

hk runs independent steps in parallel. `depends` is used only where one
step must wait for another: `spec-check` waits for `spec-fmt`, and
`budget`, `nav` and `spec-structure` wait for `federation`.

The dev shell sets `HK_JOBS=4` and `BATS_NUMBER_OF_PARALLEL_JOBS=4`, so hk
and the bats suite (through GNU `parallel`) each run four jobs at once. Four
is the cloud VM's vCPU count. Every bats test works in its own
`BATS_TEST_TMPDIR`, so the tests are safe to run together.
