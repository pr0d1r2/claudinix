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
| `.envrc` | shellcheck | direnv runs it with bash |
| `.nix` | nixfmt, xenolith, `nix flake check` | no shell inside nix strings |
| `.pkl` | none beyond hygiene | `hk` evaluates `hk.pkl` on every run, so a broken file stops the gate; `pkl/Config.pkl` is hk's schema, vendored verbatim and excluded from `typos` |
| `.yml` | actionlint, zizmor (`--offline`, pedantic) | GitHub workflows only |
| `.md` | none beyond hygiene | every `SPEC.md` also gets `mth fmt`, `mth check`, `itok check` and `sherd validate`, `sync --check`, `check`, `budget`; `SPEC-ARCHIVE.md` files are sinks with hygiene only |
| `.toml` | xenolith (`xenolith.toml` only) | `.typos.toml` is config for `typos` itself |
| `.txt` | `setup.sh`'s bats | `allowlist.txt` and `env-names.txt`: tests check the hosts they name and that no value looks like a secret |
| `.context-limits` | `itok check`, `sherd validate`, `sherd budget` | token ceilings for `SPEC.md` |
| `.lock` | none beyond hygiene | `flake.lock`, written by `nix flake lock` |
| `.gitignore` | none beyond hygiene | git config |

## Known gaps

- Markdown has no structural linter (such as markdownlint) and no link
  checker yet.
- TOML has no formatter (such as taplo) yet.
- Nix has no anti-pattern or dead-code linter (statix, deadnix) yet.
- Line coverage of the shell scripts (kcov) is planned but not gated.
