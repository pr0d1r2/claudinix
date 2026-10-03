# SPEC

## §G GOAL
functional Nix (flakes on, owner cachix) inside Claude Code cloud session VM + 1 home-manager activation = agent home (user packages, `~/.claude` skills incl. cavekit) before Claude starts; repo toolchains, linters, git hooks, deps = target repo's own flake devShell.

## §C CONSTRAINTS
- C1: platform = Claude Code cloud, Anthropic-hosted env: Ubuntu 24.04 x86_64; setup script = bash as root, runs before Claude Code; fs snapshot cached iff setup ≲ 5 min; cached snapshot ⇒ setup skipped; rebuilt on script \| allowlist change \| ~7d expiry. running processes ⊥ survive snapshot.
- C2: ⊥ management API for cloud envs (docs 2026-09-26) ∴ files in this repo = source of truth, pasted by hand in claude.ai/code env dialog.
- C3: scope = Nix + 1 home-manager activation of `homeConfigurations.cloud` (amended 2026-10-03: nix derivation installs ∀ agent-level packages \& skills). ⊥ apt toolchains, ⊥ repo-specific steps. repo-level → target flake (`nix develop`) + target repo `.claude/settings.json` SessionStart hook.
- C4: upstream Nix installer from `releases.nixos.org`, version pinned (seed 2.35.2) + installer sha256 pinned; installer checks own tarball hash.
- C5: substituters: `cache.nixos.org` (default) + `https://pr0d1r2.cachix.org`, key `pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=`. public, read-only ∴ ⊥ token.
- C6: network = Custom + "include default list" (covers `*.nixos.org`) + `pr0d1r2.cachix.org`. GitHub traffic via GitHub proxy: API \& release-asset requests reach only repos attached to session (docs) ∴ `github:` flake inputs (e.g. `github:NixOS/nixpkgs`) may 403 ?.
- C7: repo = nix + shell only (+ `hk.pkl`, CI yaml, md, toml data). shell style per owner infra repo: `set -euo pipefail`, shellcheck, `shfmt -i 4`, env-var seams for paths. guardrails = 1st thing built (C14); ⊥ feature code before gate green.
- C8: unknown session facts ?: session uid (root ?), systemd PID 1 ?, unprivileged user namespaces ?, Bash tool sources shell profiles ?. resolved by probe (T3, T4).
- C9: first consumer = owner's private the owner's private seed repo (its T7) \& its public Rust targets; reusable by any flake repo. consumers change via own specs.
- C10: open source (decided 2026-10-03). MIT, public GitHub `pr0d1r2/nix-claude-code-cloud`, same as owner's `sherd` \| `itok` \| `rekall`. public GitHub also = cloud sessions can clone it.
- C12: agent home reuses owner home config pattern (`nix/modules/claude-home.nix`): `nix-home-manager-claude-code` module + set-and-setting `mkTrip` (today owner home config `lib/mk-trip.nix` → move upstream to set-and-setting, ⊥ copy) \| `lib.mkSet` meanwhile. cavekit = non-flake input `github:JuliusBrussee/cavekit` (plugins ⊥ installed in cloud ∴ skills materialized). standalone home-manager (Ubuntu, ⊥ NixOS).
- C13: unknown ?: session `$HOME` \& uid Claude runs as; Claude in VM reads pre-existing `~/.claude` skills \& `settings.json` ?; harness rewrites `~/.claude/settings.json` ?. resolved by probe (T14).
- C14: gate = hk via `github:pr0d1r2/nix-hk` (hk binary only; checks live in our `hk.pkl`). inputs `nixpkgs-lock` + `nix-hk` w/ `follows` (⊥ fork nixpkgs rev ∴ cachix hits). `hk.pkl` shape per itok \| xenolith: vendored `pkl/Config.pkl`, `fail_fast`, `HK_HIDE_WHEN_DONE` (success = silence), `local fast` (pre-commit, `fix=true`, `stash="git"`) ⊂ `local all` (pre-push, `check`), `commit-msg`. `hk install` from shellHook (`builtins.readFile`, ⊥ inline). CI = `nix develop --command hk check --all --check --no-fail-fast` + `nix flake check`.
- C15: language purity via xenolith (`github:pr0d1r2/xenolith`, `xnl`, `.override { languages = [ "nix" "shell" ]; }`): 1 language per file; ⊥ shell embedded in nix strings \| hk steps \| justfile \| heredoc beyond 1 simple command → own `scripts/**/*.sh`. hk step = 1 plain command (⊥ `&&` `||` `|`). `xenolith.toml` allow entries carry reason; stale entry = violation.
- C16: coverage: (a) unicoverage = bats 1-to-1 mirror: ∀ `*.sh` ↔ `tests/unit/<same path>.bats`, orphans fail both ways (owner infra repo `scripts:V4`, xenolith `scripts/guard:V21`); (b) line coverage 100% target via `kcov` + bats on Linux CI ?, ratchet floor ⊥ drops (macOS ≠ Linux numbers ∴ one-sided compare, itok B20/B27).
- C17: TDD RED → GREEN → REFACTOR: RED commit `test:` (failing bats) then GREEN commit `feat:`\|`fix:` both committed; REFACTOR `refactor:` separate commit after, tests unchanged \& green. Conventional Commits + `Why:` body. guard `tdd-order` (test file exists in parent of impl commit, rename-aware `-M`) + `commit-msg`; reuse xenolith \| owner infra repo `scripts/guard/{tdd-order,bats-mirror,commit-msg}.sh` (flake export if ∃, else vendor w/ provenance header). mirror, tdd-order, bats run pre-push \| `all`, ⊥ pre-commit (else RED commit impossible, xenolith `scripts/guard` B1).
- C18: ∀ checks parallel: hk `jobs`; bats `--jobs` via `pkgs.parallel` + `BATS_NUMBER_OF_PARALLEL_JOBS` (I/O-bound, owner infra repo); `depends`\|`exclusive` only for real locks. tests parallel-safe by construction (V21).
- C19: repo = control plane: CI builds `activationPackage` \& every input closure → `pr0d1r2.cachix.org`, verifies push (narinfo 200, nix-hk V35); UI setup script = 1 deterministic line pinned to repo GIT SHA (V20). bump = new SHA in UI, ⊥ other UI edit.
- C20: owner Rust tools as gate steps (pinned flake inputs, `follows`): `mth` (microlith: `mth fmt --check SPEC.md`, `mth check SPEC.md`; pin tag), `itok check` (token ceilings in `.context-limits`, `--bpe`), `sherd` (spec federation: `validate`, `sync --check`, `check`, `budget`; split `SPEC.md` when it outgrows ceiling), `pklith` ? (early: `.pklith` → `hk.pklith.pkl` hk steps, `pklith check` = ∀ tracked file type has a check that reaches it + 1-to-1 unit rule; generated steps inline `command -v … || {…}` shell ⇒ conflicts C15 → pick 1: pklith gen ∨ hand `hk.pkl`, ⊥ blanket xenolith exclude). tool failing to RUN ≠ pass (V18).
- C11: owner-specific values (cachix host + key) in 1 config block at top of `setup.sh`; fork = edit block only. README says how.

## §I INTERFACES
- file: `setup.sh` — fetched by the UI line (V20); ⊥ pasted whole. seams: `NIX_CONF_DIR`, `BIN_DIR`, `SYSTEMD_DIR`, `NIX_DEFAULT_PROFILE`, `NIX_INSTALL_URL`, `NIX_INSTALL_SHA256`.
- file: `flake.nix` output `homeConfigurations.cloud` (x86_64-linux) + its `activationPackage`; CI pushes it to cachix \& records store path in `cloud-home.storepath`.
- file: `hk.pkl` (+ `hk.pklith.pkl` ? C20), `xenolith.toml`, `.context-limits`, `scripts/guard/*.sh`, `scripts/hk/*.sh` — gate (C14-C18, C20).
- file: `.github/workflows/ci.yml` — gate + cachix push + verify; `fetch-depth: 0`, SHA-pinned actions, `permissions: contents: read`, `persist-credentials: false`, push only on default branch.
- file: `allowlist.txt` — Allowed domains, 1 per line, `#` comments ⊥ entered.
- file: `env-names.txt` — env var names only, ⊥ values.
- cmd: `nix-dev [args]` — installed by `setup.sh` to `/usr/local/bin`; `nix develop` w/ V13 failover, args passed through.
- file: `probe.sh` — run inside cloud session; prints session facts (C8) + nix health.
- file: `docs/SETUP.md` — browser steps to create \& update env from repo files (only UI-bound part, C2) + terminal env pick.
- ext.env: claude.ai/code → environment dialog: name, network level, allowed domains, env vars, setup script.
- cmd: `hk check --all` (local) = CI gate; `hk fix`; `just` ⊥ required.

## §V INVARIANTS
V1: `setup.sh` exit 0 ⇒ `nix --version` works from Claude Bash tool shell w/o profile sourcing (nix linked into `/usr/local/bin`).
V2: installer executed only after sha256 match; mismatch → exit ≠ 0, nothing executed.
V3: `nix.conf` edit append-only behind marker line: flakes on, cachix substituter + key; installer lines (e.g. `build-users-group`) kept; rerun ⊥ duplicates, ⊥ reinstall.
V4: `--daemon` iff systemd present; else `--no-daemon`.
V5: `setup.sh` wall time on fresh VM ≤ 5 min (cache window C1); measured, ⊥ assumed.
V6: ⊥ secret in repo \| env vars; cachix read-only (⊥ `CACHIX_AUTH_TOKEN`).
V7: `setup.sh` = Nix install + agent-home activation only (C3); ⊥ target-repo step (devShell warm-up, hooks, cargo).
V8: in session, `nix develop` on target flake w/ complete `flake.lock` succeeds w/o GitHub fetch: ∀ locked input (by `narHash`) \& devShell closure substituted from `pr0d1r2.cachix.org`.
V9: nix store usable by session uid (whatever it is): write via daemon \| ownership.
V10: ∀ env in claude.ai UI ↔ files in this repo; mismatch = bug (§B).
V11: Nix version \& installer sha256 change together, 1 commit.
V12: ⊥ private info in repo \| history: ⊥ private hostnames, LAN, self-hosted forge paths, tokens. public-safe from 1st push.
V13: input failover order, each tier logged: (1) substitute locked input by `narHash` from cachix (V8); (2) fetch as locked (`github:` via proxy); (3) `nixpkgs` → `https://channels.nixos.org/<channel>/nixexprs.tar.xz` via `--override-input` + `--no-write-lock-file` (degraded: rev ≠ lock, ⊥ commit lock). tier 3 used → warn in session, ⊥ silent.
V14: activation runs in `setup.sh` (before Claude launches) as the uid \& `$HOME` Claude runs as ∴ skills present at launch \& kept in snapshot.
V15: activation failover, tier logged: (1) `nix build github:pr0d1r2/nix-claude-code-cloud#homeConfigurations.cloud.activationPackage`; (2) `nix-store -r $(cat cloud-home.storepath)` from cachix (⊥ GitHub). both fail → Nix stays usable, setup exit 0, loud warning + marker file; consumer preflight sees missing skills, ⊥ silent.
V16: agent home = agent-level tools \& skills only (what skills shell out to); ⊥ language toolchains (target devShell owns, C3).

V17: gate green before ∀ commit (fast) \& push (all); ⊥ `--no-verify`. hooks run tools from devShell: `nix develop -c hk run <hook>` (⊥ stale PATH tool, rekall B19, owner infra repo `scripts:V7`); `watch_file` ∀ `nix/*.nix` (xenolith `scripts` B2).
V18: tool missing \| crash in gate ⇒ fail w/ "gate could not run", ⊥ pass, ⊥ look like finding (itok B6/B8, xenolith `run-tool.sh`).
V19: whole-repo guards glob `**/*`; per-file steps glob by data dependency (microlith B7).
V20: UI setup script = 1 line: fetch `setup.sh` at fixed GIT SHA from `raw.githubusercontent.com/pr0d1r2/nix-claude-code-cloud/<sha>/` → run w/ same `<sha>`; `setup.sh` activates `github:pr0d1r2/nix-claude-code-cloud/<sha>#homeConfigurations.cloud.activationPackage` (substituted from cachix). same SHA ⇒ same VM result. activation derivation ⊥ depends on `cloud-home.storepath` (source filtered) ∴ CI commits store path after build w/o changing it.
V21: tests parallel-safe: own `BATS_TEST_TMPDIR`; ⊥ write-then-exec same path across forks (ETXTBSY: rekall B26, sherd B32, xenolith B3); ⊥ wall-clock asserts (rekall B5); fixtures unset `GIT_*` env (xenolith B1, sherd B25).
V22: CI proves what it claims: same `hk check --all` as local; `nix flake check --all-systems` (bare form skips systems silently, nix-hk T14); cachix push verified by narinfo 200 for built paths, empty \| 403 push = red (nix-hk B3-B5); pre-push peels annotated tags `^{commit}` (microlith B22, rekall B18, sherd B27).
V23: hk ≥ 1.55 (silent `--no-fail-fast` + `depends` bug, itok B21), pinned via `nix-hk`.

## §T TASKS
id|status|task|cites
T1|.|GUARDRAILS FIRST: `flake.nix` (inputs `nixpkgs-lock`, `nix-hk`, `xenolith` w/ `follows`) devShell (hk, bats, `parallel`, shellcheck, shfmt, nixfmt, coreutils, kcov ?) + shellHook from file (`hk install`); `hk.pkl` from owner infra repo `hk.pkl` template (vendored `pkl/Config.pkl`, fast ⊂ all, commit-msg) w/ hk util hygiene, shellcheck, shfmt, nixfmt, typos, ripsecrets, actionlint, zizmor; parallel. ⊥ other task before T1,T19-T23 green|C7,C14,C18,V17,V18,V23
T2|.|import seed from the owner's private seed repo `a35942b` `cloud/envs/nix/` → repo root (`setup.sh`, `allowlist.txt`, `env-names.txt`, `tests/unit/setup.bats`); fix paths; `just check` green|V1,V2,V3,V4,V6,V7,I.file
T3|.|`probe.sh`: `id`, PID 1 comm, systemd dir, `unshare -Ur true`, profile sourcing, `nix --version`, `nix config show substituters`, `nix flake metadata github:NixOS/nixpkgs` (direct fetch via proxy ok ?), locked-input substitution from cachix (input source w/ `narHash` pushed, ⊥ GitHub), `channels.nixos.org` tarball fetch, `nix-dev` tier reached, cachix narinfo hit, elapsed; bats w/ stubs|C8,V8,V9,I.file
T4|.|MANUAL create env `nix` at claude.ai/code from repo files; run 1 probe session; record facts → resolve C8 `?`, C6 `?`|C8,C6,V10,I.ext.env
T5|.|if probe: session uid ≠ root ∧ no systemd → make store usable (V9) \| switch install mode; bats|V9,V4
T6|.|target-repo CI snippet (doc only, targets adopt via own spec): on push to default branch `nix flake archive --json` + devShell closure → `cachix push pr0d1r2`; push token in CI secrets only, ⊥ VM|V8,V6,C5,C6,C3
T7|.|measure setup wall time on fresh VM; record; > 5 min → trim|V5,C1
T8|.|SessionStart hook snippet for target repos: enter devShell once (warm), install git hooks; doc only, target repos adopt via own spec|C3,V7,C9
T9|.|`LICENSE` (MIT), `README.md` (what, paste steps, fork block C11, known limits); V12 scan of tree \& history before 1st push|C10,C11,V12
T11|.|MANUAL create public GitHub repo `pr0d1r2/nix-claude-code-cloud`, add remote, push after T9|C10,V12
T12|.|`nix-dev` wrapper: try tiers V13 in order, log tier used, channel from target `flake.lock` nixpkgs ref (`nixos-<ver>` \| `nixpkgs-unstable`) else `nixpkgs-unstable`; installed by `setup.sh`; bats w/ stub `nix`|V13,V8,I.cmd
T13|x|`docs/SETUP.md` for zero-knowledge user: money steps first (claim credit, usage credits OFF — before ∀ cloud session), then browser steps (selector → Add cloud environment → name, Network access Custom + default list + `allowlist.txt`, env vars from `env-names.txt`, Setup script = `setup.sh`), update flow, then terminal `/remote-env` \| `remote.defaultEnvironmentId`; prereqs, GitHub connect (App, select repos), first-session check, troubleshooting, cleanup|C2,V10,I.ext.env
T14|.|probe ext: `echo $HOME`, `id`, `ls -la ~/.claude`, `settings.json` owner \& content before/after launch; setup places 1 test skill in `~/.claude/skills` → visible to Claude (`/` list) ?|C13,V14,I.file
T15|.|set-and-setting issue: move `mkTrip` from owner home config `lib/mk-trip.nix` upstream; add cavekit category (non-flake input). via its spec|C12,C9
T16|.|`homeConfigurations.cloud`: home-manager standalone, `nix-home-manager-claude-code` + set (`mkTrip` \| `mkSet`) + cavekit skills (`spec`,`build`,`check`,`backprop`,`caveman`) + `FORMAT.md`; `nix flake check` asserts skill files present|C12,V16,I.file
T17|.|`setup.sh` tail: activate agent home w/ V15 failover as Claude's uid; seams `CLOUD_HOME_FLAKE`, `CLOUD_HOME_STOREPATH`; bats w/ stub `nix`|V14,V15,V7,I.file
T18|.|CI: build `activationPackage` → `cachix push pr0d1r2` → commit store path to `cloud-home.storepath` (token CI-only, V6)|V15,V6,C5
T19|.|guard scripts: `bats-mirror` (unicoverage, both directions), `tdd-order` (RED in parent of GREEN, `-M`), `commit-msg` (Conventional + `Why:`); reused per C17; pre-push \| all; each w/ own bats (RED→GREEN)|C16,C17,V17,V19
T20|.|xenolith step `xnl check {{files}}` + `checks.<sys>.xenolith`; `xenolith.toml` (languages nix, shell)|C15,V18
T21|.|owner tools steps: `mth` on `SPEC.md`, `itok check` + `.context-limits`, `sherd validate`\|`budget`; pinned inputs w/ `follows`; via `scripts/hk/run-tool.sh` (V18)|C20,V18
T22|.|pklith ?: `.pklith` → `hk.pklith.pkl` imported by `hk.pkl`, `pklith check` step; adopt only if generated steps pass C15 purity (else upstream pklith issue: emit `scripts/hk/*.sh` calls) \& render C14-C20 steps ⊥ loss|C20,C15,V19
T23|.|CI `.github/workflows/ci.yml`: gate + `nix flake check` + cachix push on default branch + verify job (narinfo 200); kcov line-coverage job ? w/ ratchet|C19,V22,C16
T24|.|UI line: `setup.sh` takes `<sha>` arg; docs/SETUP.md shows exact 1-line script; `just`\|script prints line for HEAD after CI green; bats|V20,C19,V10
T10|.|`just bump-nix <ver>`: fetch installer + `.sha256`, rewrite pin pair, run tests|V11,C4

## §B BUGS
id|date|cause|fix
