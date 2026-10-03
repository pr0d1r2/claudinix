# SPEC

## §G GOAL
functional Nix (flakes on, owner cachix) inside Claude Code cloud session VM; ∀ beyond Nix (toolchains, linters, git hooks, deps) = target repo's own flake devShell.

## §C CONSTRAINTS
- C1: platform = Claude Code cloud, Anthropic-hosted env: Ubuntu 24.04 x86_64; setup script = bash as root, runs before Claude Code; fs snapshot cached iff setup ≲ 5 min; cached snapshot ⇒ setup skipped; rebuilt on script \| allowlist change \| ~7d expiry. running processes ⊥ survive snapshot.
- C2: ⊥ management API for cloud envs (docs 2026-09-26) ∴ files in this repo = source of truth, pasted by hand in claude.ai/code env dialog.
- C3: scope = Nix only. ⊥ apt toolchains, ⊥ repo-specific steps. everything else → target flake (`nix develop`) + target repo `.claude/settings.json` SessionStart hook.
- C4: upstream Nix installer from `releases.nixos.org`, version pinned (seed 2.35.2) + installer sha256 pinned; installer checks own tarball hash.
- C5: substituters: `cache.nixos.org` (default) + `https://pr0d1r2.cachix.org`, key `pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=`. public, read-only ∴ ⊥ token.
- C6: network = Custom + "include default list" (covers `*.nixos.org`) + `pr0d1r2.cachix.org`. GitHub traffic via GitHub proxy: API \& release-asset requests reach only repos attached to session (docs) ∴ `github:` flake inputs (e.g. `github:NixOS/nixpkgs`) may 403 ?.
- C7: shell style per owner infra repo: `set -euo pipefail`, shellcheck, `shfmt -i 4`, bats 1-to-1, TDD RED→GREEN, env-var seams for paths.
- C8: unknown session facts ?: session uid (root ?), systemd PID 1 ?, unprivileged user namespaces ?, Bash tool sources shell profiles ?. resolved by probe (T3, T4).
- C9: first consumer = owner's private the owner's private seed repo (its T7) \& its public Rust targets; reusable by any flake repo. consumers change via own specs.
- C10: open source (decided 2026-10-03). MIT, public GitHub `pr0d1r2/nix-claude-code-cloud`, same as owner's `sherd` \| `itok` \| `rekall`. public GitHub also = cloud sessions can clone it.
- C11: owner-specific values (cachix host + key) in 1 config block at top of `setup.sh`; fork = edit block only. README says how.

## §I INTERFACES
- file: `setup.sh` — paste into env "Setup script". seams: `NIX_CONF_DIR`, `BIN_DIR`, `SYSTEMD_DIR`, `NIX_DEFAULT_PROFILE`, `NIX_INSTALL_URL`, `NIX_INSTALL_SHA256`.
- file: `allowlist.txt` — Allowed domains, 1 per line, `#` comments ⊥ entered.
- file: `env-names.txt` — env var names only, ⊥ values.
- file: `probe.sh` — run inside cloud session; prints session facts (C8) + nix health.
- ext.env: claude.ai/code → environment dialog: name, network level, allowed domains, env vars, setup script.
- cmd: `just check` = shellcheck + shfmt + bats, same local \& CI.

## §V INVARIANTS
V1: `setup.sh` exit 0 ⇒ `nix --version` works from Claude Bash tool shell w/o profile sourcing (nix linked into `/usr/local/bin`).
V2: installer executed only after sha256 match; mismatch → exit ≠ 0, nothing executed.
V3: `nix.conf` edit append-only behind marker line: flakes on, cachix substituter + key; installer lines (e.g. `build-users-group`) kept; rerun ⊥ duplicates, ⊥ reinstall.
V4: `--daemon` iff systemd present; else `--no-daemon`.
V5: `setup.sh` wall time on fresh VM ≤ 5 min (cache window C1); measured, ⊥ assumed.
V6: ⊥ secret in repo \| env vars; cachix read-only (⊥ `CACHIX_AUTH_TOKEN`).
V7: `setup.sh` does Nix only (C3); ⊥ target-repo step (devShell warm-up, hooks, cargo).
V8: in session, `nix develop` on target flake w/ `github:` inputs succeeds; else documented fallback input form.
V9: nix store usable by session uid (whatever it is): write via daemon \| ownership.
V10: ∀ env in claude.ai UI ↔ files in this repo; mismatch = bug (§B).
V11: Nix version \& installer sha256 change together, 1 commit.
V12: ⊥ private info in repo \| history: ⊥ private hostnames, LAN, self-hosted forge paths, tokens. naming the owner's private seed repo OK (owner 2026-10-03). public-safe from 1st push.

## §T TASKS
id|status|task|cites
T1|.|`flake.nix` devShell (bats, shellcheck, shfmt, just, coreutils) + `justfile` `check` + pre-commit hook running `just check`|C7,I.cmd
T2|.|import seed from the owner's private seed repo `a35942b` `cloud/envs/nix/` → repo root (`setup.sh`, `allowlist.txt`, `env-names.txt`, `tests/unit/setup.bats`); fix paths; `just check` green|V1,V2,V3,V4,V6,V7,I.file
T3|.|`probe.sh`: `id`, PID 1 comm, systemd dir, `unshare -Ur true`, profile sourcing, `nix --version`, `nix config show substituters`, `nix flake metadata github:NixOS/nixpkgs`, cachix narinfo hit, elapsed; bats w/ stubs|C8,V8,V9,I.file
T4|.|MANUAL create env `nix` at claude.ai/code from repo files; run 1 probe session; record facts → resolve C8 `?`, C6 `?`|C8,C6,V10,I.ext.env
T5|.|if probe: session uid ≠ root ∧ no systemd → make store usable (V9) \| switch install mode; bats|V9,V4
T6|.|if probe: `github:` inputs 403 → document fallback (`https://channels.nixos.org/...` tarball \| `git+https`) for target flakes|V8,C6
T7|.|measure setup wall time on fresh VM; record; > 5 min → trim|V5,C1
T8|.|SessionStart hook snippet for target repos: enter devShell once (warm), install git hooks; doc only, target repos adopt via own spec|C3,V7,C9
T9|.|`LICENSE` (MIT), `README.md` (what, paste steps, fork block C11, known limits); V12 scan of tree \& history before 1st push|C10,C11,V12
T11|.|MANUAL create public GitHub repo `pr0d1r2/nix-claude-code-cloud`, add remote, push after T9|C10,V12
T10|.|`just bump-nix <ver>`: fetch installer + `.sha256`, rewrite pin pair, run tests|V11,C4

## §B BUGS
id|date|cause|fix
