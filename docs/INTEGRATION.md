# Integration

How this repository's gate is put together, and how to run any part of it by
hand.

The gate itself lives in [`hk.pkl`](../hk.pkl) and that file is the only
definition of it. If this document and `hk.pkl` ever disagree, `hk.pkl` is
right and this file has a bug.

## One definition, three callers

| caller | set | when |
|---|---|---|
| `pre-commit` hook | `fast`, 37 steps | every commit, on the staged files |
| `pre-push` hook | `all`, 41 steps | every push |
| `hk check --all` in CI | `all`, 41 steps | every push to `main` and every pull request |

A fourth hook, `commit-msg`, runs two steps on the commit message.

`all` is `fast` plus four steps that judge the branch rather than a single
commit: the bats suite, the dev crate's `cargo test`, `bats-mirror` and
`tdd-order`. They stay off `pre-commit` on purpose. A RED commit adds a
failing test before its code exists, so running the suites or the mirror
check on every commit would make the RED commit impossible.

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
`hk install`. That writes config-based hooks (`hook.hk-<event>.command` in
the local git config), and the script rewrites each command to
`CLAUDINIX_HOOK=1 nix-dev -c hk run <hook>` where `nix-dev` is installed (a
cloud session), or `CLAUDINIX_HOOK=1 nix develop -c hk run <hook>` where it
is not. A commit therefore always uses the pinned tools, even from a
terminal whose `PATH` is stale. `CLAUDINIX_HOOK=1` tells the shell hook,
when the hook enters the shell, not to reinstall the hooks again.

Only git 2.54 or newer runs config-based hooks. An older git, such as the
one in a cloud image, runs only `.git/hooks/<event>`, so the shell hook also
copies [`scripts/dev/legacy-hook.sh`](../scripts/dev/legacy-hook.sh) there
for `pre-commit`, `commit-msg` and `pre-push`. Under an older git it runs
the very command the config hook holds; under a newer git it does nothing,
so the gate never runs twice. A hook someone else put there is never
overwritten: it is left alone with a warning, and an older git then does
not run that gate hook.

In a cloud session, the project's SessionStart hook runs
`bash "$CLAUDE_PROJECT_DIR/scripts/dev/session-start.sh"`. It fetches the
full history and enters the dev shell once (`nix-dev -c true`, else
`nix develop -c true`), which installs the hooks before the first commit.

The `cloud-permissions` step keeps the cloud permission list narrow: it
refuses blanket rules (`Bash`, `Bash(*)`, a rule starting with `*`, a bare
`nix develop` or `nix-dev` runner rule), requires the main-push deny rules,
and refuses a `permissions` block in `.claude/settings.json`, which local
sessions read.

Each external tool is called through
[`scripts/hk/run-tool.sh`](../scripts/hk/run-tool.sh). If the tool is not
on `PATH`, the step fails with "gate could not run, nothing was checked".
A missing tool must never look like a pass, and never like a finding.

## The steps

Run any step by hand from inside the dev shell with the command in its
`check` column; the `fix` column, where there is one, is what the
pre-commit hook and `hk fix` run instead. `<files>` means the files hk
hands the step (by hand, name the files yourself) and `<node>` a spec
node's directory. `fast` steps run on every commit, `all` steps join them
on push and in CI, and the `commit-msg` steps check the message.

The table is generated from `hk.pkl` by `claudinix-dev steps --write`, and
the `integration-steps` step fails when it no longer matches.

<!-- BEGIN steps: generated from hk.pkl by `claudinix-dev steps --write`; do not edit -->
| step | layer | files | check | fix |
|---|---|---|---|---|
| `shellcheck` | fast | `**/*.sh` `**/*.bats` `.envrc` | `shellcheck <files>` | - |
| `shfmt` | fast | `**/*.sh` `**/*.bats` | `shfmt --diff --indent 4 <files>` | `shfmt --write --indent 4 <files>` |
| `nixfmt` | fast | `**/*.nix` | `nixfmt --check <files>` | `nixfmt <files>` |
| `xenolith` | fast | `**/*.nix` `**/*.sh` `**/*.bats` `xenolith.toml` | `xnl check <files>` | - |
| `just` | fast | `justfile` | `just --fmt --check --unstable` | `just --fmt --unstable` |
| `pkl-eval` | fast | `hk.pkl` `pkl/*.pkl` | `pkl eval --output-path /dev/null hk.pkl` | - |
| `actionlint` | fast | `.github/workflows/*.yml` `.github/workflows/*.yaml` | `actionlint <files>` | - |
| `zizmor` | fast | `.github/workflows/*.yml` `.github/workflows/*.yaml` | `zizmor --offline --no-progress --persona=pedantic <files>` | - |
| `spec-fmt` | fast | `**/SPEC.md` | `mth fmt --check <node>/SPEC.md` | `mth fmt <node>/SPEC.md` |
| `spec-check` | fast | `**/SPEC.md` | `mth check <node>/SPEC.md` | - |
| `spec-tokens` | fast | `**/SPEC.md` `.context-limits` | `itok check` | - |
| `federation` | fast | `**/SPEC.md` `.context-limits` | `sherd validate` | - |
| `nav` | fast | `**/SPEC.md` | `sherd sync --check` | `sherd sync` |
| `spec-structure` | fast | `**/SPEC.md` | `sherd check` | - |
| `budget` | fast | `**/SPEC.md` `.context-limits` | `sherd budget` | - |
| `typos` | fast | `**/*` | `typos --force-exclude <files>` | `typos --force-exclude --write-changes <files>` |
| `no-private-key` | fast | `**/*` | `hk util detect-private-key <files>` | - |
| `ripsecrets` | fast | `**/*` | `ripsecrets <files>` | - |
| `trailing-whitespace` | fast | `**/*` | `hk util trailing-whitespace <files>` | `hk util trailing-whitespace --fix <files>` |
| `final-newline` | fast | `**/*` | `hk util end-of-file-fixer <files>` | `hk util end-of-file-fixer --fix <files>` |
| `line-endings` | fast | `**/*` | `hk util mixed-line-ending <files>` | `hk util mixed-line-ending --fix <files>` |
| `no-large-files` | fast | `**/*` | `hk util check-added-large-files <files>` | - |
| `no-merge-conflict` | fast | `**/*` | `hk util check-merge-conflict --assume-in-merge <files>` | - |
| `readme-setup-line` | fast | `README.md` `scripts/setup-line.sh` `scripts/guard/readme-setup-line.sh` | `scripts/guard/readme-setup-line.sh` | - |
| `jobs-match-vcpus` | fast | `docs/FACTS.md` `nix/dev-shell.nix` `scripts/guard/jobs-match-vcpus.sh` | `scripts/guard/jobs-match-vcpus.sh` | - |
| `dev-fmt` | fast | `dev/**` | `cargo fmt --check --manifest-path dev/Cargo.toml` | `cargo fmt --manifest-path dev/Cargo.toml` |
| `dev-clippy` | fast | `dev/**` | `cargo clippy --quiet --all-targets --manifest-path dev/Cargo.toml -- -D warnings` | - |
| `readme-badges` | fast | `README.md` `LICENSE` `setup.sh` `.claudinix.toml` `hk.pkl` `pkl/*.pkl` `SPEC.md` `.github/workflows/ci.yml` `tests/unit/**/*.bats` `dev/**` | `claudinix-dev badges --check` | `claudinix-dev badges --write` |
| `integration-steps` | fast | `docs/INTEGRATION.md` `hk.pkl` `pkl/*.pkl` `dev/**` | `claudinix-dev steps --check` | `claudinix-dev steps --write` |
| `staged-generated` | fast | `README.md` `LICENSE` `setup.sh` `.claudinix.toml` `hk.pkl` `pkl/*.pkl` `SPEC.md` `.github/workflows/ci.yml` `tests/unit/**/*.bats` `docs/INTEGRATION.md` `dev/**` `scripts/guard/staged-generated.sh` | `scripts/guard/staged-generated.sh` | - |
| `third-party-notices` | fast | `docs/THIRD-PARTY-NOTICES.md` `flake.lock` `dev/**` | `claudinix-dev notices --check` | `claudinix-dev notices --write` |
| `prose-facts` | fast | `README.md` `docs/LLM-DISCLAIMER.md` `docs/FACTS.md` `setup.sh` `hk.pkl` `pkl/*.pkl` `SPEC.md` `tests/unit/**/*.bats` `dev/**` | `claudinix-dev facts --check` | - |
| `cli-usage` | fast | `docs/CLI.md` `setup.sh` `scripts/*.sh` `dev/**` | `claudinix-dev cli --check` | - |
| `config-keys` | fast | `docs/CONFIG.md` `scripts/config.jq` `dev/**` | `claudinix-dev config --check` | `claudinix-dev config --write` |
| `claudinix-config` | fast | `.claudinix.toml` `scripts/config.sh` `scripts/config.jq` | `scripts/config.sh check` | - |
| `cloud-permissions` | fast | `nix/cloud-permissions.json` `.claude/settings.json` `scripts/guard/cloud-permissions.sh` | `scripts/guard/cloud-permissions.sh` | - |
| `exec-bit` | fast | `**/*` | `scripts/guard/exec-bit.sh` | - |
| `bats` | all | `**/*.sh` `**/*.bats` `**/*.jq` `**/*.tsv` `**/*.txt` `justfile` `docs/SETUP.md` `tests/fixtures/**` | `bats --recursive tests/unit` | - |
| `dev-test` | all | `dev/**` | `cargo test --quiet --manifest-path dev/Cargo.toml` | - |
| `bats-mirror` | all | `**/*` | `scripts/guard/bats-mirror.sh` | - |
| `tdd-order` | all | `**/*` | `scripts/guard/tdd-order.sh` | - |
| `commit-msg` | commit-msg | the message | `scripts/guard/commit-msg.sh` | - |
| `changelog` | commit-msg | the message | `claudinix-dev changelog <message-file>` | - |
<!-- END steps -->

A few notes on why the steps look the way they do:

- **xenolith** enforces one language per file: no shell inside nix strings,
  hk steps or heredocs. The `xnl` binary is built with only the `nix` and
  `shell` languages, because those are the languages this repository has.
- **just** keeps the `justfile` in just's own layout. `--unstable` is there
  because `just --fmt` still asks for it. Each recipe is one plain command
  that calls a script under `scripts/`; the logic lives in the bats-covered
  script, not in the justfile.
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
- **claudinix-config** checks this repository's own
  [`.claudinix.toml`](CONFIG.md) with the reader every tool uses, so a typo
  in it fails the gate and not a later `probe` or `guide` run. It is in the
  fast layer, and its glob includes the reader (`scripts/config.sh`,
  `scripts/config.jq`), because a change to the schema must rerun the check
  on the file. Like the reader, it needs `nix` and `jq` on `PATH` and fails
  loudly without them; it never passes for a tool it could not run.
- **readme-badges**, **integration-steps**, **cli-usage** and
  **config-keys** run `claudinix-dev`, the repository's own Rust tool in
  `dev/` (std only, never published, built by Nix into the dev shell). The
  README badges, the step table above and the step counts in the caller
  table are generated from the files that own them (`hk.pkl` through
  `pkl eval`, the `@test` lines, `setup.sh`, `.claudinix.toml`, `LICENSE`,
  the root `§F`), so adding a gate step or a bats test means running
  `claudinix-dev badges --write` and `claudinix-dev steps --write` in the
  same commit. The pre-commit fix writes their output to the worktree only,
  so **staged-generated** runs both checks again on a copy of the index:
  a commit that stages the source without the rewritten output fails until
  you `git add` it. `cli-usage` checks that every `usage:` line
  [`CLI.md`](CLI.md) quotes is the text its script prints, and
  `config-keys` that the key table in [`CONFIG.md`](CONFIG.md) is the one
  `claudinix-dev config --write` renders from the schema in
  `scripts/config.jq`.
- **Secrets** are checked twice because the two tools answer different
  questions: `detect-private-key` finds key blocks, `ripsecrets` finds token
  shapes. The repository is public from its first push.

### On every push (`all` adds)

`bats-mirror` checks that every tracked `*.sh` has
`tests/unit/<same path>.bats` and that every bats file still has its script.
`tdd-order` checks that each commit adding a script had the script's test in
its parent commit. It reads history, so it needs a full clone: in a shallow
clone (as in a cloud session) run `git fetch --unshallow` first. By hand it
takes a range: `scripts/guard/tdd-order.sh [range]`.

### On every commit message

By hand: `scripts/guard/commit-msg.sh <message-file>` and
`claudinix-dev changelog <message-file>`.

The subject must follow Conventional Commits and the body must have a
`Why:` line. Merge, revert and fixup subjects pass untouched.

`changelog` refuses a `feat` or `fix` commit that stages session code
without `CHANGELOG.md`. Session code is what a session VM or a
target-project user gets: `setup.sh`, `probe.sh`, `allowlist.txt`,
`env-names.txt`, `nix/cloud-home.nix`, `nix/cloud-permissions.json`,
`nix/apps.nix`, and `scripts/**` except `scripts/guard/`, `scripts/hk/`,
`scripts/ci/`, `scripts/dev/`, `scripts/nix/` and spec files. Other
commit types, merge, revert and fixup subjects, and an amend of a commit
that already staged its entry pass.

### In `nix flake check`

| check | what it runs |
|---|---|
| `checks.<system>.xenolith` | [`scripts/nix/xenolith-check.sh`](../scripts/nix/xenolith-check.sh): `xnl check .` over the flake source |
| `checks.<system>.claudinix-dev` | builds `packages.<system>.claudinix-dev` from `dev/` and runs its `cargo test` |
| `checks.x86_64-linux.cloud-home` | [`scripts/nix/cloud-home-check.sh`](../scripts/nix/cloud-home-check.sh): the agent home's activation package holds the cavekit skills, `FORMAT.md` and the set rules (only on `x86_64-linux`, the one system the agent home is built for) |

### In CI only

CI also builds the dev shell and the agent home
(`nix build --no-link .#devShells.x86_64-linux.default
.#homeConfigurations.cloud.activationPackage`), so their output paths exist
to push and to verify.

On `main`, and only on a push to `main`, `cachix/cachix-action` gets the
write token (pull requests and manual runs get none and only read the cache)
and pushes what the gate job built to `pr0d1r2.cachix.org`. The same job then
runs [`scripts/ci/push-sources.sh`](../scripts/ci/push-sources.sh), which
pushes every eval-time input source of the flake (`nix flake archive --json`,
nested inputs included): a cloud session evaluates the agent home and the dev
shell before it builds anything, and it cannot fetch a `github:` input from
GitHub there, so each source must be substitutable by its `narHash`. The
cachix action alone pushes only built paths.

A separate `verify cache` job then runs
[`scripts/ci/verify-cachix.sh`](../scripts/ci/verify-cachix.sh) with
`--sources .`, the dev shell and the agent home. It asks the cache for each
output's narinfo and fails on anything but HTTP 200, and for each input
source it accepts the owner's cache or the upstream cache `UPSTREAM_URL`
(`https://cache.nixos.org`, which serves nixpkgs) answering 200. A push step
that exits 0 is not proof that anything arrived.

## Parallelism

hk runs independent steps in parallel. `depends` is used only where one
step must wait for another: `spec-check` waits for `spec-fmt`, and
`budget`, `nav` and `spec-structure` wait for `federation`, and the cargo
steps run in a chain (`dev-fmt`, then `dev-clippy`, then `dev-test`)
because cargo locks its target directory.

The dev shell sets `HK_JOBS=4` and `BATS_NUMBER_OF_PARALLEL_JOBS=4`, so hk
and the bats suite (through GNU `parallel`) each run four jobs at once. Four
is the cloud VM's vCPU count. Every bats test works in its own
`BATS_TEST_TMPDIR`, so the tests are safe to run together.
