# SPEC

## §G GOAL

what `setup.sh` does in a session: install, network, owner values, opt-in agent home, the release paste line.

## §N NAV

rel|path|lens
up|.|-
self|setup|`setup.sh`, `allowlist.txt`: install, network, owner values, opt-in agent home, release line
sib|scripts|repo shell: gate guards, hk runners, CI checks, target-project apps
sib|nix|flake outputs: dev shell, checks, agent home build, cachix push
sib|docs|plain-English docs: setup, facts, runbook, security, release
sib|experiments|cloud-session experiments \& results
sib|dev|`claudinix-dev`: generated badges \& doc numbers
sib|home|`~/.claude`: skills, rtk, caveman, permission rules
sib|cloud|cloud launchers \& their prompts, `enroll`
sib|gate|the gate: `hk.pkl`, `xenolith.toml`, `.context-limits`, CI workflow, ceilings \& archive layout

## §C CONSTRAINTS

- C3: scope = Nix + 1 home-manager activation of `homeConfigurations.cloud` (amended 2026-10-03: nix derivation installs ∀ agent-level packages \& skills). ⊥ apt toolchains, ⊥ repo-specific steps. repo-level → target flake (`nix develop`) + target repo `.claude/settings.json` SessionStart hook.
- C4: upstream Nix installer from `releases.nixos.org`, version pinned (seed 2.35.2) + installer sha256 pinned; installer checks own tarball hash. image ships Nix 2.34.6 (probe 1) ∴ use it when `nix --version` ≥ floor `NIX_MIN_VERSION` (seed 2.34), else install pinned version; ⊥ 2nd Nix on PATH.
- C6: network = Custom + include default list + `pr0d1r2.cachix.org`, `cache.nixos.org`, `channels.nixos.org`, `releases.nixos.org`, `raw.githubusercontent.com` (probes 1-3, `.:B15`: default list lacks them) + per-target hosts (`apps.domains`, e.g. crates.io). GitHub via proxy, ⊥ allowlist: `github:` inputs (archive tarball, API) → 403 unless repo attached; `add_repo` on a public repo = no-op; `git+https` \& `git ls-remote` of owner's public repos pass; 3rd-party git read (`actions/checkout`) → 403 w/o `github.com` in allowlist (probe 5) ∴ allowlist names `github.com`. tools sending `GH_TOKEN` = placeholder `proxy-injected` → 401 ∴ such tools run tokenless \| offline (`docs:T8`). allowlist edits reach new sessions only. 1 env per repo (`.:T50`, 2026-10-04).
- C11: owner values (cachix host + key, repo slug) in 1 block atop `setup.sh` (`# BEGIN fork config (SPEC C11)`: `cache_host`, `cache_key`, `repo`; bats: ⊥ `pr0d1r2` outside it); fork = edit the block + the files `docs/FORKING.md` lists (allowlist, flake `nixConfig`, CI, probe \& verify defaults, `setup-line.sh`).
- C24: agent home = OPT-IN (decided 2026-10-03): setup default = Nix + `nix-dev` only; `setup.sh [SHA] --agent-home` (\| `CLAUDINIX_AGENT_HOME=1`) adds `nix:` agent home; README states what it installs (owner set rules, cavekit skills, claude-code config) \& that it changes Claude's behaviour.
- C25: paste line (2026-10-03): each release publishes the exact 1-line setup script (pinned SHA w/ green CI, cachix filled) in a generated README block + release notes; users copy it, run ⊥. `scripts/setup-line.sh` = maintainer tool. before the 1st release the README holds the placeholder sentence the gate accepts (`scripts/guard/readme-setup-line.sh`); `just release REV` fills it. release: `release.sh record [REV]` → commit `cloud-home.storepath` → `release.sh publish REV2` (`scripts:V33`).

## §I INTERFACES

- file: `setup.sh [SHA] [--agent-home]` — fetched by the UI line (V20); ⊥ pasted whole; SHA = full 40-hex commit; any other arg → exit 2; `--agent-home` \| `CLAUDINIX_AGENT_HOME=1` activates the agent home (C24), else 1 line says it was skipped \& how to opt in; every fetch bounded (`--connect-timeout 10 --max-time 60`); nix-dev installed all-or-nothing; script dir only from `BASH_SOURCE` (stdin → fetch at SHA, ⊥ cwd); `CLOUD_HOME_STOREPATH` default beside the script \| temp dir. seams: `NIX_CONF_DIR`, `BIN_DIR`, `SYSTEMD_DIR`, `NIX_DEFAULT_PROFILE`, `NIX_INSTALL_URL`, `NIX_INSTALL_SHA256`, `NIX_MIN_VERSION`; agent home: links `rtk` into `BIN_DIR`; `CLOUD_HOME_FLAKE`, `CLOUD_HOME_STOREPATH` (file), `CLOUD_HOME_MARKER` (default `~/.local/state/claudinix/agent-home.failed`); nix-dev: `CLAUDINIX_LIB_DIR` (default `/usr/local/lib/claudinix`, `nix-dev` symlinked into `BIN_DIR`), `CLAUDINIX_RAW_URL`, `CLAUDINIX_REV` (default: SHA arg, else `main`). Nix ops: `--option connect-timeout 10 --option stalled-download-timeout 30` + `timeout $CLAUDINIX_NIX_TIMEOUT` (s, default 120, else exit 2) on installer \& each tier; empty `CLAUDINIX_AGENT_HOME` = unset.
- file: `allowlist.txt` — Allowed domains, 1 per line, `#` comments ⊥ entered.

## §V INVARIANTS

V3: `nix.conf` managed block between begin/end marker lines, replaced whole on rerun (⊥ append-only: a changed block w/ same marker never updated): flakes on, `accept-flake-config = true`, cachix substituter + key; lines outside the block (installer's) kept; rerun ⊥ duplicates, ⊥ reinstall.
V4: Nix on PATH ≥ floor ⇒ ⊥ install. else `--daemon` iff systemd present; else `--no-daemon`. probe: image Nix found at `/nix/var/nix/profiles/default/bin` \& `~/.nix-profile` (root), no daemon, no systemd.
V20: UI setup script = 1 line: fetch `setup.sh` at fixed GIT SHA from `raw.githubusercontent.com/pr0d1r2/claudinix/<sha>/` (reachable from session ✓ E2 2026-11-04; from setup phase ? `experiments:T190`) → run w/ same `<sha>`; `setup.sh` activates `git+https://github.com/pr0d1r2/claudinix?rev=<sha>&shallow=1#homeConfigurations.cloud.activationPackage` (substituted from cachix). same SHA ⇒ same VM result. activation derivation ⊥ depends on `cloud-home.storepath` (source filtered) ∴ CI commits store path after build w/o changing it.
V38: ∀ host the setup line or `setup.sh` fetches from (`https://<host>`) ∈ `allowlist.txt` (`.:B15`).

## §T TASKS

id|status|task|cites

## §B BUGS

id|date|cause|fix
B118|2026-11-03|`experiments:T7` no-warning wall-time test ran w/ caller's `CLAUDINIX_SETUP_BUDGET` \& real elapsed time ∴ host env or slow run → red (#71 review)|`.:V21`: test sets its own budget
