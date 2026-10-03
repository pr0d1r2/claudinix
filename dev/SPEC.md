# SPEC

## §G GOAL

`claudinix-dev`: tooling that maintains THIS repo \& ships to nobody (`publish = false`): generated doc blocks (README badges, doc numbers) \& their drift checks, as tested Rust, std only.

## §N NAV

rel|path|lens
up|.|-
self|dev|`claudinix-dev`: repo-only Rust tool, generated README badges \\& doc numbers + their drift checks, `publish = false`
sib|scripts|repo shell tools: gate guards, hk runners, dev shell hook, CI checks, target-project apps (`nix-dev`, `inputs`, `domains`, `guide`, probe launcher)
sib|nix|flake outputs: dev shell, checks, agent home `homeConfigurations.cloud` \\& its activation package, cachix push of it
sib|docs|human docs in plain English: setup walkthrough, facts, runbook, security, consumer \\& release docs
sib|experiments|cloud-session experiments: prompts, dated results, setup timing, snapshot reuse, skill survival, self-build runs; results feed `docs/FACTS.md`

## §C CONSTRAINTS

- C30: ⊥ published, ⊥ in any session closure; ⊥ dependencies (std only) ∴ builds offline \& in cloud w/o crates.io; built by Nix (`packages.<sys>.claudinix-dev`, in the dev shell).
- C31: pure fns over `&str` ∀ parser \& renderer; `main.rs` alone reads the repo \& writes ∴ ∀ rule testable w/o a repository. exit 0 clean · 1 drift · 2 usage \| I/O. Rust gate: `cargo fmt --check`, `cargo clippy -D warnings`, `cargo test` on `dev/**`. `dev-test` runs on push only (a RED commit fails on purpose, `.:C17`); the dev shell carries the package built w/o its tests; dev shell = `mkShell` (cargo needs a C linker).

## §I INTERFACES

- cmd: `claudinix-dev badges --write\|--check [--root DIR]` — splices `<!-- BEGIN badges -->`…`<!-- END badges -->` in README.md; `--check` exit 1 on drift w/ a diff.
- cmd: `claudinix-dev counts --check [--root DIR]` — the gate step counts `docs/INTEGRATION.md` states = `hk.pkl` (fast, all).

## §V INVARIANTS

V1: every generated number comes from the file that OWNS it (`hk.pkl` steps, `@test` lines in `tests/unit/**/*.bats`, `setup.sh` `min_version`, root §F rows, `ci.yml` path, `.claudinix.toml` `cache.name`); a value that reads empty \| zero → exit 2 naming the file.
V2: a badge's alt text \& URL come from ONE value ∴ they cannot disagree.
V3: render is idempotent: splice(splice(x)) == splice(x) ∴ `--check` is equality.
V4: the status badge follows the README's `> **Alpha|Beta|Preview, <date>.**` callout \& is absent w/o one; the CI slug comes from `setup.sh`'s fork block `repo=`, the cache from `.claudinix.toml` `cache.name`.

## §T TASKS

id|status|task|cites
T106|.|`steps --write\|--check`: the whole hk step table in `docs/INTEGRATION.md` (name, layer, glob, by-hand command) from `hk.pkl` via `pkl eval -x`, replacing the counts-only check (pklith `agents`)|V1,V3,`.:T105`
T107|.|`cli --check`: each `usage:` line `docs/CLI.md` quotes = the script's own usage text (read from `scripts/*.sh`, `setup.sh`) (pklith `cli`)|V1,V3
T108|.|`config --write\|--check`: `docs/CONFIG.md` key table (key, type, default, readers) from `scripts/config.jq`'s schema (pklith `catalog`)|V1,V3,`scripts:V34`
T109|.|`notices --write\|--check`: `docs/THIRD-PARTY-NOTICES.md` inputs table (name, source, locked rev) from `flake.lock` (pklith/xenolith `notices`)|V1,V3
T110|.|`facts --check`: numbers README \& `docs/LLM-DISCLAIMER.md` quote in prose (gate steps, tests, nodes, probe count) = their owning files (pklith `facts`)|V1
T111|.|`changelog FILE` (commit-msg hook step): a `feat`\|`fix` commit touching session code (`setup.sh`, `scripts/**`, `nix/cloud-home.nix`, `nix/cloud-permissions.json`) adds a `CHANGELOG.md` entry in the same commit, else refuse w/ the rule; `docs`/`test`/`refactor` exempt (pklith `changelog`)|`.:V20`,`docs:T37`
T112|.|? `select`: run only the generated outputs a changed file can affect (xenolith `select`) — when the gate gets slow|V3

## §B BUGS

id|date|cause|fix
