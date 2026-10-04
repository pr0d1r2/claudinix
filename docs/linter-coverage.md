# Linter coverage

Which checks reach each kind of file in this repository. Every file also
passes the hygiene steps that apply to all files: `typos`,
`no-private-key`, `ripsecrets`, `trailing-whitespace`, `final-newline`,
`line-endings`, `no-large-files` and `no-merge-conflict`. The table lists
what each type gets on top of those.

The steps are defined in [`hk.pkl`](../hk.pkl) and explained in
[`INTEGRATION.md`](INTEGRATION.md). If this table and `hk.pkl` disagree,
`hk.pkl` is right.

| file | checks on top of hygiene | notes |
|---|---|---|
| `.sh` | shellcheck, shfmt (`-i 4`), xenolith, bats-mirror, tdd-order, bats | every script has `tests/unit/<same path>.bats` |
| `.bats` | shellcheck, shfmt (`-i 4`), xenolith, bats-mirror, bats | tests; each needs its script |
| `.rs` | cargo fmt (`--check`), clippy (`-D warnings`), cargo test | `dev/` only, the `claudinix-dev` crate; clippy is pedantic with `unwrap`, `expect`, `panic` and indexing denied, and `unsafe` is forbidden (`dev/Cargo.toml`); the tests run on push; the shell steps do not apply |
| `Cargo.toml`, `Cargo.lock` | none beyond hygiene | covered by the cargo steps only: they run when anything under `dev/` changes |
| `justfile` | just (`--fmt --check --unstable`) | one plain command per recipe; the logic is in the scripts |
| `.envrc` | shellcheck | direnv runs it with bash |
| `.nix` | nixfmt, xenolith, `nix flake check` | no shell inside nix strings |
| `.pkl` | none beyond hygiene | `hk` evaluates `hk.pkl` on every run, so a broken file stops the gate; `pkl/Config.pkl` is hk's schema, vendored verbatim and excluded from `typos` |
| `.yml` | actionlint, zizmor (`--offline`, pedantic) | GitHub workflows only |
| `.md` | none beyond hygiene | every `SPEC.md` also gets `mth fmt`, `mth check`, `itok check` and `sherd validate`, `sync --check`, `check`, `budget`; `SPEC-ARCHIVE.md` files are sinks with hygiene only |
| `.toml` | xenolith (`xenolith.toml` only); `claudinix-config` (`.claudinix.toml` only) | `.typos.toml` is config for `typos` itself; `.claudinix.toml` is read by `scripts/config.sh check`, which refuses unknown keys, wrong types and a `version` other than 1 ([`CONFIG.md`](CONFIG.md)) |
| `.jq` | none beyond hygiene | `scripts/inputs.jq`, `scripts/nix-dev.jq`: jq programs read by `inputs.sh` and `nix-dev.sh`, so their bats tests run them on fixture `flake.lock` files; `scripts/config.jq` is the schema and defaults of `.claudinix.toml`, run by `config.sh` and covered by `config.bats` on fixture files |
| `.tsv` | none beyond hygiene | `scripts/guide-steps.tsv`: a bats test keeps its step titles equal to the `docs/SETUP.md` headings |
| `.txt` | `setup.sh`'s bats | `allowlist.txt` and `env-names.txt`: tests check the hosts they name and that no value looks like a secret; `scripts/probe-prompt.txt` is a template: the task text `probe-launch.sh` sends, with `@NIX_DEV@`, `@NIX_DEVELOP@` and `@BRANCH_PREFIX@` placeholders it fills in; it gets hygiene only |
| `.context-limits` | `itok check`, `sherd validate`, `sherd budget` | token ceilings for `SPEC.md` |
| `.json` | `cloud-permissions` (`nix/cloud-permissions.json` only) | the cloud session permission list: no blanket rules, the main-push deny rules present; the step also refuses a `permissions` block in `.claude/settings.json` |
| `.lock` | none beyond hygiene | `flake.lock`, written by `nix flake lock` |
| `.gitignore` | none beyond hygiene | git config |

## Known gaps

- Markdown has no structural linter (such as markdownlint) and no link
  checker yet.
- TOML has no formatter (such as taplo) yet.
- Nix has no anti-pattern or dead-code linter (statix, deadnix) yet.
- Line coverage of the shell scripts (kcov) is planned but not gated.
