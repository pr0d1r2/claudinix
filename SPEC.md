# SPEC

## §G GOAL
functional Nix (flakes on, owner cachix) inside Claude Code cloud session VM + 1 home-manager activation = agent home (user packages, `~/.claude` skills incl. cavekit) before Claude starts; repo toolchains, linters, git hooks, deps = target repo's own flake devShell.

## §F FEDERATION

dir|owns|⊥owns|tokens
scripts|repo shell tools: gate guards, hk runners, dev shell hook, CI checks, target-project apps (`nix-dev`, `inputs`, `domains`, `guide`, probe launcher)|`setup.sh` \& `probe.sh` (root), flake wiring (`nix`)|-
nix|flake outputs: dev shell, checks, agent home `homeConfigurations.cloud` \& its activation package, cachix push of it|session setup (root `setup.sh`), shell logic (`scripts`)|-
docs|human docs in plain English: setup walkthrough, facts, runbook, security, consumer \& release docs|the gate's definition (`hk.pkl`), spec rules|-

## §N NAV

rel|path|lens
up|-|-
self|.|-

## §C CONSTRAINTS
- C1: platform = Claude Code cloud, Anthropic-hosted env: Ubuntu 24.04 x86_64; setup script = bash as root, runs before Claude Code; fs snapshot cached iff setup ≲ 5 min; cached snapshot ⇒ setup skipped; rebuilt on script \| allowlist change \| ~7d expiry. running processes ⊥ survive snapshot.
- C2: ⊥ management API for cloud envs (docs 2026-09-26) ∴ files in this repo = source of truth, pasted by hand in claude.ai/code env dialog.
- C3: scope = Nix + 1 home-manager activation of `homeConfigurations.cloud` (amended 2026-10-03: nix derivation installs ∀ agent-level packages \& skills). ⊥ apt toolchains, ⊥ repo-specific steps. repo-level → target flake (`nix develop`) + target repo `.claude/settings.json` SessionStart hook.
- C4: upstream Nix installer from `releases.nixos.org`, version pinned (seed 2.35.2) + installer sha256 pinned; installer checks own tarball hash. image ships Nix 2.34.6 (probe 1) ∴ use it when `nix --version` ≥ floor `NIX_MIN_VERSION` (seed 2.34), else install pinned version; ⊥ 2nd Nix on PATH.
- C5: substituters: `cache.nixos.org` (default) + `https://pr0d1r2.cachix.org`, key `pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=`. public, read-only ∴ ⊥ token.
- C6: network = Custom + "include default list" + explicit hosts: `pr0d1r2.cachix.org`, `cache.nixos.org`, `channels.nixos.org`, `releases.nixos.org` (probes 1-3: default list did NOT cover nixos.org hosts) + per-target ecosystem hosts (`apps.domains`, e.g. crates.io). GitHub traffic goes via GitHub proxy, ⊥ allowlist: `github:` inputs (archive tarball `github.com/<o>/<r>/archive/<rev>.tar.gz`, GitHub API) → 403 unless repo attached; `add_repo` read on public repo = no-op; plain git reads (`git+https`, `git ls-remote`) of owner's public repos pass; 3rd-party git read (`actions/checkout`) → 403 w/o `github.com` in allowlist (probe 5), passes w/ it (sherd #96 session, 2026-10-03) ∴ allowlist names `github.com`. tools sending `GH_TOKEN` (placeholder `proxy-injected`) get 401 (zizmor in sherd #97) ∴ such tools run w/o token or offline (`docs:T8`). allowlist edits reach new sessions only.
- C7: repo = nix + shell only (+ `hk.pkl`, CI yaml, md, toml data). shell style per owner infra repo: `set -euo pipefail`, shellcheck, `shfmt -i 4`, env-var seams for paths. guardrails = 1st thing built (C14); ⊥ feature code before gate green.
- C8: session facts (probe 2026-10-03, sherd): uid 0 root, `HOME=/root`, PID 1 `process_api` (⊥ systemd), `unshare -Ur` ok, Bash `PATH` starts `/nix/var/nix/profiles/default/bin`. image ships Nix 2.34.6 (nix-installer receipt, root profile, ⊥ daemon) ∴ `setup.sh` skips install, only config + links. proxy refused `cache.nixos.org` \& `channels.nixos.org` despite default list ∴ allowlist names them. flake `nixConfig` ignored w/o `accept-flake-config`. clone shallow (`--is-shallow-repository` true) ∴ `tdd-order` needs unshallow. git author = `Claude <noreply@anthropic.com>`, ssh-signed (`commit.gpgsign`), harness adds `Claude-Session:` trailer. pushed branch gets random suffix (`claude/nix-probe-8yxk95`). in-session `add_repo` tool: public repo ⇒ "read_available", attaches nothing.
- C8b: probe log (sherd) 2-4: probe 2: `git ls-remote` of public repo passes proxy; `github.com/<o>/<r>/archive/<rev>.tar.gz` (Nix `github:` fetcher) → 403 ∴ small inputs as `git+https://github.com/<o>/<r>`, big (nixpkgs) via cachix substitution. probe 4: w/ `cache.nixos.org` allowed nixpkgs source substituted by narHash (⊥ GitHub); sherd devShell 34 s cold, store 3.7 GB; allowlist edit ⊥ reaches running session (new session needed); crates.io hosts explicit (`index.crates.io`, `static.crates.io`).
- C8c: probe log 5-7: probe 5 (sherd, git+https overrides): `cargo test` green 12.5 s; `hk check --all` 2m45s, all green except zizmor online audit: `github.com/actions/checkout.git/git-upload-pack` 403 (git read of 3rd-party repo refused; pr0d1r2/* git reads passed) ∴ online-audit tools need offline mode in cloud ?. probe 6: 4 vCPU, 15 GB RAM, no swap, ~30 GB free disk per session (252 GB device), no cgroup v2 limits visible; VM up 3 min at session start (fresh boot); sherd devShell grows `/nix/store` 103 MB → 3.7 GB; cold `hk check --all` 3m43s (8m33s CPU). probe 7: sherd `main` after #97 (git+https inputs): plain `nix develop` OK 33 s cold, ⊥ overrides; `cargo test` 31 s. cloud flag `CLAUDE_CODE_REMOTE=true` (+ `CCR_*` vars) ∴ consumer hooks detect cloud via it (`docs:T8`, zizmor).
- C9: first consumer = owner's private the owner's private seed repo (its T7) \& its public Rust targets; reusable by any flake repo. consumers change via own specs.
- C10: open source (decided 2026-10-03). MIT, public GitHub `pr0d1r2/nix-claude-code-cloud`, same as owner's `sherd` \| `itok` \| `rekall`. public GitHub also = cloud sessions can clone it.
- C13: `~/.claude/skills` exists at launch w/ harness `session-start-hook` + account-synced skills (`synced/<id>/…`); ⊥ `~/.claude/settings.json`; dirs re-stamped at session start ∴ survival of skills pre-placed by `setup.sh` ? (T14).
- C14: gate = hk via `github:pr0d1r2/nix-hk` (hk binary only; checks live in our `hk.pkl`). inputs `nixpkgs-lock` + `nix-hk` w/ `follows` (⊥ fork nixpkgs rev ∴ cachix hits). `hk.pkl` shape per itok \| xenolith: vendored `pkl/Config.pkl`, `fail_fast`, `HK_HIDE_WHEN_DONE` (success = silence), `local fast` (pre-commit, `fix=true`, `stash="git"`) ⊂ `local all` (pre-push, `check`), `commit-msg`. `hk install` from shellHook (`builtins.readFile`, ⊥ inline). CI = `nix develop --command hk check --all --check --no-fail-fast` + `nix flake check`.
- C15: language purity via xenolith (`github:pr0d1r2/xenolith`, `xnl`, `.override { languages = [ "nix" "shell" ]; }`): 1 language per file; ⊥ shell embedded in nix strings \| hk steps \| justfile \| heredoc beyond 1 simple command → own `scripts/**/*.sh`. hk step = 1 plain command (⊥ `&&` `||` `|`). `xenolith.toml` allow entries carry reason; stale entry = violation.
- C16: coverage: (a) unicoverage = bats 1-to-1 mirror: ∀ `*.sh` ↔ `tests/unit/<same path>.bats`, orphans fail both ways (owner infra repo scripts invariant 4, xenolith scripts/guard invariant 21); (b) line coverage 100% target via `kcov` + bats on Linux CI ?, ratchet floor ⊥ drops (macOS ≠ Linux numbers ∴ one-sided compare, itok B20/B27).
- C17: TDD RED → GREEN → REFACTOR: RED commit `test:` (failing bats) then GREEN commit `feat:`\|`fix:` both committed; REFACTOR `refactor:` separate commit after, tests unchanged \& green. Conventional Commits + `Why:` body. guard `tdd-order` (test file exists in parent of impl commit, rename-aware `-M`) + `commit-msg`; reuse xenolith \| owner infra repo `scripts/guard/{tdd-order,bats-mirror,commit-msg}.sh` (flake export if ∃, else vendor w/ provenance header). mirror, tdd-order, bats run pre-push \| `all`, ⊥ pre-commit (else RED commit impossible, xenolith `scripts/guard` B1).
- C18: ∀ checks parallel: hk `jobs`; bats `--jobs` via `pkgs.parallel` + `BATS_NUMBER_OF_PARALLEL_JOBS` (I/O-bound, owner infra repo); `depends`\|`exclusive` only for real locks. tests parallel-safe by construction (V21).
- C19: repo = control plane: CI builds `activationPackage` \& every input closure → `pr0d1r2.cachix.org`, verifies push (narinfo 200, as nix-hk does); UI setup script = 1 deterministic line pinned to repo GIT SHA (V20). bump = new SHA in UI, ⊥ other UI edit.
- C20: owner Rust tools as gate steps (pinned flake inputs, `follows`): `mth` (microlith: `mth fmt --check SPEC.md`, `mth check SPEC.md`; pin tag), `itok check` (token ceilings in `.context-limits`, `--bpe`), `sherd` (spec federation: `validate`, `sync --check`, `check`, `budget`; split `SPEC.md` when it outgrows ceiling), `pklith` ? (early: `.pklith` → `hk.pklith.pkl` hk steps, `pklith check` = ∀ tracked file type has a check that reaches it + 1-to-1 unit rule; generated steps inline `command -v … || {…}` shell ⇒ conflicts C15 → pick 1: pklith gen ∨ hand `hk.pkl`, ⊥ blanket xenolith exclude). tool failing to RUN ≠ pass (V18).
- C21: atomic commits, 1 topic each (humans read changesets): Conventional Commits, body `Why:` + spec cites; ⊥ mix topics (e.g. docs for 2 findings = 2 commits); spec change ⊥ same commit as code; RED, GREEN, REFACTOR separate (C17). unpushed mixed commit → split before push.
- C23: experiment order (T56-T66): E1, E3, E4, E5 together in 1 Sonnet session after sherd #96; E6, E7 from #96 results; E9 then E8; E2 after 1st push; E10 last; E11 alongside each.
- C11: owner-specific values (cachix host + key) in 1 config block at top of `setup.sh`; fork = edit block only. README says how.

## §I INTERFACES
- file: `setup.sh` — fetched by the UI line (V20); ⊥ pasted whole. seams: `NIX_CONF_DIR`, `BIN_DIR`, `SYSTEMD_DIR`, `NIX_DEFAULT_PROFILE`, `NIX_INSTALL_URL`, `NIX_INSTALL_SHA256`.
- file: `flake.nix` output `homeConfigurations.cloud` (x86_64-linux) + its `activationPackage`; CI pushes it to cachix \& records store path in `cloud-home.storepath`.
- file: `hk.pkl` (+ `hk.pklith.pkl` ? C20), `xenolith.toml`, `.context-limits`, `scripts/guard/*.sh`, `scripts/hk/*.sh` — gate (C14-C18, C20).
- file: `.github/workflows/ci.yml` — gate + cachix push + verify; `fetch-depth: 0`, SHA-pinned actions, `permissions: contents: read`, `persist-credentials: false`, push only on default branch.
- file: `allowlist.txt` — Allowed domains, 1 per line, `#` comments ⊥ entered.
- file: `env-names.txt` — env vars for the env dialog: secrets as names only, ⊥ values; non-secret settings w/ value. ⊥ model: `ANTHROPIC_MODEL` on env does NOT pick the session model (probe 6: env sonnet-5-5, session `configured_model` opus-5-5); model = launch `--model` \| browser picker.
- cmd: `nix-dev [args]` — installed by `setup.sh` to `/usr/local/bin`; `nix develop` w/ `scripts:V13` failover, args passed through.
- file: `probe.sh` — run inside cloud session; prints session facts (C8) + nix health.
- file: `docs/SETUP.md` — browser steps to create \& update env from repo files (only UI-bound part, C2) + terminal env pick.
- ext.env: claude.ai/code → environment dialog: name, network level, allowed domains, env vars, setup script.
- cmd: `hk check --all` (local) = CI gate; `hk fix`.
- cmd: target-project tools run FROM the project to be sent to cloud, ⊥ clone of this repo: flake apps `nix run github:pr0d1r2/nix-claude-code-cloud#<app>` w/ `<app>` ∈ {`domains`, `inputs`, `guide`}; default dir = cwd (the target project). `just <app>` here = same app on `.` for dev.
- cmd: `just guide [flake-dir]` → `scripts/guide.sh`: interactive terminal walkthrough of `docs/SETUP.md` steps 0-5 in order, + `just guide update` = "Updating the environment" flow (where the selector is: start page, ⊥ inside a session; replace whole setup script; `just domains` list; new session to verify). per step: says what \& where, opens URL (`open` \| `xdg-open`), copies paste value to clipboard (`pbcopy` \| `wl-copy` \| `xclip`; setup line, allowed domains, env name), waits for Enter \| `y/n`. verifies locally what it can: `claude auth status` = claude.ai login, `remote.defaultEnvironmentId` set, `just inputs` → repos to attach. money step 0 = explicit `y` confirm each (credit shown, usage credits OFF), ⊥ skippable. resumable: `--from <step>`. ⊥ network writes, ⊥ secrets.
- cmd: `just domains [project-dir…] [--from-log FILE]` → union, deduped, sorted after base: (1) `allowlist.txt` base; (2) hosts detected from each project's files: `Cargo.lock`\|`Cargo.toml` → `index.crates.io`, `static.crates.io` (+ `[source]` \& git dep hosts); `flake.nix` `nixConfig` substituters; `flake.lock` non-`github` input URLs (`github` ones → `just inputs`); `.gitmodules`; `package-lock.json`\|`yarn.lock`\|`pnpm-lock.yaml` `resolved` hosts; `uv.lock`\|`requirements*.txt` → `pypi.org`, `files.pythonhosted.org`; `Gemfile.lock` remotes; `go.sum` → `proxy.golang.org`, `sum.golang.org`; (3) `--from-log`: hosts named in proxy refusals (`Host not in allowlist: <host>`, `CONNECT tunnel failed, response 403` w/ URL) from a session log. each line tagged source (`base`\|`<file>`\|`log`) w/ `--why`; plain output = paste-ready, copied to clipboard when available (`pbcopy` \| `wl-copy` \| `xclip`). ⊥ network.
- cmd: `nix run …#probe [--model M] [--cleanup]` (+ `just probe`): from target project, starts 1 cloud session (`claude --cloud`, needs a TTY ∴ run under `script -q`; default `--model sonnet`) w/ the probe prompt (C8 facts, fetch tiers, devShell, `cargo`\|`hk` if present), finds its pushed branch by prefix `claude/nix-probe` (harness adds random suffix), prints the report; `--cleanup` deletes `claude/nix-probe*` branches (session cannot delete branches). follow-ups via `claude -p MSG --cloud ID` (no TTY needed).
- cmd: `just inputs [flake-dir]` → `scripts/inputs.sh`: ∀ node in `flake.lock` (recursive, deduped) of type `github` → 1 line `owner/repo rev status`; status = `cached` (input source store path from `nix flake archive --dry-run --json` has narinfo in `pr0d1r2.cachix.org`) \| `attach` (⊥ cached ∴ must be attached to session \| routine, docs/SETUP.md). default flake-dir = `.`; works on any target flake (e.g. sherd). exit 1 iff any `attach` w/ `--check`.

## §V INVARIANTS
V1: `setup.sh` exit 0 ⇒ `nix --version` works from Claude Bash tool shell w/o profile sourcing (nix linked into `/usr/local/bin`).
V2: installer executed only after sha256 match; mismatch → exit ≠ 0, nothing executed.
V3: `nix.conf` managed block between begin/end marker lines, replaced whole on rerun (⊥ append-only: a changed block w/ same marker never updated): flakes on, `accept-flake-config = true`, cachix substituter + key; lines outside the block (installer's) kept; rerun ⊥ duplicates, ⊥ reinstall.
V4: Nix on PATH ≥ floor ⇒ ⊥ install. else `--daemon` iff systemd present; else `--no-daemon`. probe: image Nix found at `/nix/var/nix/profiles/default/bin` \& `~/.nix-profile` (root), no daemon, no systemd.
V5: `setup.sh` wall time on fresh VM ≤ 5 min (cache window C1); measured, ⊥ assumed.
V6: ⊥ secret in repo \| env vars; cachix read-only (⊥ `CACHIX_AUTH_TOKEN`).
V7: `setup.sh` = Nix install + agent-home activation only (C3); ⊥ target-repo step (devShell warm-up, hooks, cargo).
V8: in session, `nix develop` on target flake w/ complete `flake.lock` succeeds w/o GitHub tarball fetch: locked inputs substituted by `narHash` from `cache.nixos.org` (nixpkgs, probe 4) \| `pr0d1r2.cachix.org` (pushed by target CI, T54); devShell closure from either cache.
V9: nix store usable by session uid (whatever it is): write via daemon \| ownership. holds: session runs as root, store owned by root (probe 1).
V10: ∀ env in claude.ai UI ↔ files in this repo; mismatch = bug (§B).
V11: Nix version \& installer sha256 change together, 1 commit.
V12: ⊥ private info in repo \| history: ⊥ private hostnames, LAN, self-hosted forge paths, tokens. public-safe from 1st push.

V17: gate green before ∀ commit (fast) \& push (all); ⊥ `--no-verify`. hooks run tools from devShell: `nix develop -c hk run <hook>` (⊥ stale PATH tool, rekall B19, owner infra repo scripts invariant 7); `watch_file` ∀ `nix/*.nix` (xenolith `scripts` B2).
V18: tool missing \| crash in gate ⇒ fail w/ "gate could not run", ⊥ pass, ⊥ look like finding (itok B6/B8, xenolith `run-tool.sh`).
V19: whole-repo guards glob `**/*`; per-file steps glob by data dependency (microlith B7).
V20: UI setup script = 1 line: fetch `setup.sh` at fixed GIT SHA from `raw.githubusercontent.com/pr0d1r2/nix-claude-code-cloud/<sha>/` (reachable from setup phase ?, E2) → run w/ same `<sha>`; `setup.sh` activates `git+https://github.com/pr0d1r2/nix-claude-code-cloud?rev=<sha>&shallow=1#homeConfigurations.cloud.activationPackage` (substituted from cachix). same SHA ⇒ same VM result. activation derivation ⊥ depends on `cloud-home.storepath` (source filtered) ∴ CI commits store path after build w/o changing it.
V21: tests parallel-safe: own `BATS_TEST_TMPDIR`; ⊥ write-then-exec same path across forks (ETXTBSY: rekall B26, sherd B32, xenolith B3); ⊥ wall-clock asserts (rekall B5); fixtures unset `GIT_*` env (xenolith B1, sherd B25).
V22: CI proves what it claims: same `hk check --all` as local; `nix flake check --all-systems` (bare form skips systems silently, nix-hk T14); cachix push verified by narinfo 200 for built paths, empty \| 403 push = red (nix-hk B3-B5); pre-push peels annotated tags `^{commit}` (microlith B22, rekall B18, sherd B27).
V23: hk ≥ 1.55 (silent `--no-fail-fast` + `depends` bug, itok B21), pinned via `nix-hk`.
V24: long gate commands in the Bash tool: default 120 s does NOT kill (probe 6): command moves to background at 120 s and finishes (limit 30 min); real exit status arrives only w/ the completion notice ∴ agent prompts \& wrappers wait for completion, ⊥ read the 120 s return as result. `BASH_DEFAULT_TIMEOUT_MS` raise = optional (fewer backgrounded runs).
V25: `accept-flake-config = true` trusts cloned repo `nixConfig` ∴ env used only w/ owner-trusted repos; extra substituters outside allowlist unreachable anyway; documented in SECURITY (`docs:T36`).

## §T TASKS
id|status|task|cites
T1|x|ARCHIVED to SPEC-ARCHIVE.md|C7,C14,C18,V17,V18,V23
T2|x|ARCHIVED to SPEC-ARCHIVE.md|V1,V2,V3,V4,V6,V7,I.file
T3|x|ARCHIVED to SPEC-ARCHIVE.md|C8,V8,V9,I.file
T4|x|ARCHIVED to SPEC-ARCHIVE.md|C8,C6,V10,I.ext.env — done 2026-10-03: env `nix` created; probes 1-5 on sherd
T5|x|ARCHIVED to SPEC-ARCHIVE.md|V9,V4 — not needed: session uid = root (probe 1)
T7|.|measure setup wall time on fresh VM; record; > 5 min → trim|V5,C1
T10|.|`just bump-nix <ver>`: fetch installer + `.sha256`, rewrite pin pair, run tests|V11,C4
T11|.|MANUAL create public GitHub repo `pr0d1r2/nix-claude-code-cloud`, add remote, push after `docs:T9`|C10,V12
T14|.|probe ext: `echo $HOME`, `id`, `ls -la ~/.claude`, `settings.json` owner \& content before/after launch; setup places 1 test skill in `~/.claude/skills` → visible to Claude (`/` list) ?|C13,`nix:V14`,I.file
T17|.|`setup.sh` tail: activate agent home w/ `nix:V15` failover as Claude's uid; seams `CLOUD_HOME_FLAKE`, `CLOUD_HOME_STOREPATH`; bats w/ stub `nix`|`nix:V14`,`nix:V15`,V7,I.file
T19|x|ARCHIVED to SPEC-ARCHIVE.md|C16,C17,V17,V19
T20|x|ARCHIVED to SPEC-ARCHIVE.md|C15,V18
T21|x|ARCHIVED to SPEC-ARCHIVE.md|C20,V18
T22|x|ARCHIVED to SPEC-ARCHIVE.md|C20,C15,V19 — decided 2026-10-03: ⊥ adopt; pklith v0.1.0 (`4aa83e0`) still emits inline `command -v … \|\| {…}` per step ⇒ C15 breach; keep hand `hk.pkl`; upstream issue (emit `scripts/hk/*.sh` calls) pending owner OK to file
T23|x|ARCHIVED to SPEC-ARCHIVE.md|C19,V22,C16
T24|.|UI line: `setup.sh` takes `<sha>` arg; docs/SETUP.md shows exact 1-line script; `just`\|script prints line for HEAD after CI green; bats|V20,C19,V10
T29|x|ARCHIVED to SPEC-ARCHIVE.md|C6,V10 — answered: `github.com` allowed ⇒ 3rd-party git reads pass; `add_repo` read = no-op
T30|.|base `allowlist.txt` = Nix-only hosts (cachix, `cache.nixos.org`, `channels.nixos.org`, `releases.nixos.org`); ecosystem hosts (crates.io…) come from `apps.domains` per target, ⊥ hardcoded; SETUP shows both|C6,I.cmd,`scripts:T27`
T48|.|`env-names.txt`: optional `BASH_DEFAULT_TIMEOUT_MS=600000` (E4: default backgrounds at 120 s, ⊥ kills); SETUP + guide show them|V24,I.file
T50|.|decide env strategy: 1 shared env `nix` w/ union of target domains vs 1 env per ecosystem (`nix-rust`, …); criteria: allowlist size \& review, snapshot reuse, model per env; record decision in C6|C6,V10,I.ext.env
T51|.|unattended runs: permission mode for routines \& long jobs; what a job does while a prompt waits (timeout, report, ⊥ hang); extends `docs:T47`|`docs:T47`,C9
T52|.|record VM resources (`nproc`, `free`, `df /`, store growth) in FACTS; set bats `--jobs`, hk jobs, cargo jobs from them|C18,`docs:T34` — measured: 4 vCPU ∴ hk \& bats jobs = 4, cargo default
T54|.|cache population owner: ∀ target repo CI pushes locked inputs + devShell closure to `pr0d1r2.cachix.org` on default branch (per `docs:T6` snippet); start w/ sherd via its spec; verify narinfo 200 (V22 pattern)|V8,`docs:T6`,C16
T55|.|measure snapshot reuse: 2nd session in same env skips setup?; start time cold vs warm; record in FACTS|V5,C1,`docs:T34`
T56|.|EXP E1 skills survive: `setup.sh` places test skill + `~/.claude/settings.json`; session lists skills \& reads file; decides agent-home design (`nix:T16`, T17) vs account-synced skills|C13,`nix:V14`,T14
T57|.|EXP E2 SHA-pinned fetch: in session `curl raw.githubusercontent.com/<o>/<r>/<sha>/setup.sh` + `nix build git+https://…?rev=<sha>#…`; after 1st push (or sherd stand-in)|V20,`nix:V15`,T24
T58|x|ARCHIVED to SPEC-ARCHIVE.md|I.file,`docs:T42` — answered 2026-10-03 (probe 6): env var ⊥ effective; launcher model wins. follow-up E3b: does `claude --cloud --model sonnet` set it? (T67)
T59|x|ARCHIVED to SPEC-ARCHIVE.md|V24,T48 — answered 2026-10-03 (probe 6): cold `hk check --all` 3m43s, backgrounded at 120 s, ⊥ killed
T60|x|ARCHIVED to SPEC-ARCHIVE.md|T52,T55 — resources answered 2026-10-03 (probe 6); snapshot reuse still open (T55)
T61|x|ARCHIVED to SPEC-ARCHIVE.md|T29,C6 — answered: `github.com` allowed ⇒ 3rd-party git reads pass; `add_repo` read = no-op
T62|.|EXP E7 silence prompts: commit exact `add_repo` allow rule in sherd `.claude/settings.json`; try `--permission-mode` w/ `--cloud`|`docs:T47`,T51
T63|.|EXP E8 cache fast path: after sherd CI pushes inputs + devShell (T54), fresh session times plain `nix develop` (target < 10 s), confirms narHash substitution ⊥ git fetch|V8,T54
T64|.|EXP E9 `nix-dev` auto-overrides prototype on itok \| microlith w/o changing their flakes|`scripts:T49`,`scripts:V13`
T65|.|EXP E10 unattended routine: API-triggered routine on env `nix`, trivial task; watch prompts \& errors|T51
T66|.|EXP E11 cost per session: usage page before/after E1-E5; confirms credit charged at API rates ?|I.file,`docs:T42` — first reading 2026-10-03: $7 for 8 short sessions (7 probes + 1 job, 7 on Opus 5.5) ≈ $0.90/session; per-session split still unmeasured
T67|x|ARCHIVED to SPEC-ARCHIVE.md|T58,`scripts:T28`,I.cmd — answered 2026-10-03 (probe 7): `claude --cloud "<task>" --model sonnet` ⇒ configured, served \& trailer = Sonnet 5.5; `--model` before the task fails (`--cloud requires a description`)

## §B BUGS
id|date|cause|fix
B1|2026-10-03|assumed "include default list" covers `*.nixos.org` (docs); proxy refused `cache.nixos.org` \& `channels.nixos.org` → `nix develop` built from source \& failed|C6 names hosts explicitly; probe checks each host (T3)
B2|2026-10-03|seed `setup.sh` appended `nix.conf` block only when marker absent ∴ adding `accept-flake-config` never reached a VM w/ old block|V3 managed block rewritten whole
B3|2026-10-03|spec `nix:V15`/V20 fetched own repo via `github:` → would 403 in cloud (caught before build)|`nix:V15`, V20 use `git+https`
