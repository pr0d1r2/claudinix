# SPEC

## §G GOAL
`claudinix` ("Claude in cloud on Nix"; claud = Claude \| cloud, "i nix" = Polish "and nix"): functional Nix (flakes on, owner cachix) inside Claude Code cloud session VM + 1 home-manager activation = agent home (user packages, `~/.claude` skills incl. cavekit) before Claude starts; repo toolchains, linters, git hooks, deps = target repo's own flake devShell.

## §F FEDERATION

dir|owns|⊥owns|tokens
scripts|repo shell tools: gate guards, hk runners, dev shell hook, CI checks, target-project apps (`nix-dev`, `inputs`, `domains`, `guide`, probe launcher)|`setup.sh` \& `probe.sh` (root), flake wiring (`nix`)|-
nix|flake outputs: dev shell, checks, agent home `homeConfigurations.cloud` \& its activation package, cachix push of it|session setup (root `setup.sh`), shell logic (`scripts`)|-
docs|human docs in plain English: setup walkthrough, facts, runbook, security, consumer \& release docs|the gate's definition (`hk.pkl`), spec rules|-
experiments|cloud-session experiments: prompts, dated results, setup timing, snapshot reuse, skill survival, self-build runs; results feed `docs/FACTS.md`|setup code (root), tools (`scripts`), the docs prose (`docs`)|-

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
- C8b: probe log 2-4 (sherd, 2026-10-03) → `docs/FACTS.md` (dated per probe); conclusions live in C6, C8, V8, `scripts:V13`.
- C8c: probe log 5-7 (sherd, 2026-10-03) → `docs/FACTS.md`; conclusions live in C6, C8, V24, C18 (4 vCPU), `docs:T43` timings.
- C9: first consumer = owner's private seed repo (its `experiments:T7`) \& its public Rust targets; reusable by any flake repo. consumers change via own specs.
- C10: open source (decided 2026-10-03). MIT, public GitHub `pr0d1r2/claudinix` (renamed 2026-10-03 before 1st push; working name `nix-claude-code-cloud` stays in history ⊥ rewritten); README states unofficial, ⊥ affiliated w/ \| endorsed by Anthropic; same as owner's `sherd` \| `itok` \| `rekall`. public GitHub also = cloud sessions can clone it.
- C13: `~/.claude/skills` exists at launch w/ harness `session-start-hook` + account-synced skills (`synced/<id>/…`); ⊥ `~/.claude/settings.json`; dirs re-stamped at session start ∴ survival of skills pre-placed by `setup.sh` ? (`experiments:T14`).
- C14: gate = hk via `github:pr0d1r2/nix-hk` (hk binary only; checks live in our `hk.pkl`). inputs `nixpkgs-lock` + `nix-hk` w/ `follows` (⊥ fork nixpkgs rev ∴ cachix hits). `hk.pkl` shape per itok \| xenolith: vendored `pkl/Config.pkl`, `fail_fast`, `CLX_NO_PROGRESS=1` in `env {}` (success = silence, V31; hk 1.58.1 ignores `HK_HIDE_WHEN_DONE` there \& has no env for `--quiet`; a TTY loses live progress too), `local fast` (pre-commit, `fix=true`, `stash="git"`) ⊂ `local all` (pre-push, `check`), `commit-msg`. `hk install` from shellHook (`builtins.readFile`, ⊥ inline). CI = `nix develop --command hk check --all --check --no-fail-fast` + `nix flake check`.
- C15: language purity via xenolith (`github:pr0d1r2/xenolith`, `xnl`, `.override { languages = [ "nix" "shell" ]; }`): 1 language per file; ⊥ shell embedded in nix strings \| hk steps \| justfile \| heredoc beyond 1 simple command → own `scripts/**/*.sh`. hk step = 1 plain command (⊥ `&&` `||` `|`). `xenolith.toml` allow entries carry reason; stale entry = violation.
- C16: coverage: (a) unicoverage = bats 1-to-1 mirror: ∀ `*.sh` ↔ `tests/unit/<same path>.bats`, orphans fail both ways (owner infra repo scripts invariant 4, xenolith scripts/guard invariant 21); (b) line coverage 100% target via `kcov` + bats on Linux CI ?, ratchet floor ⊥ drops (macOS ≠ Linux numbers ∴ one-sided compare, itok B20/B27).
- C17: TDD RED → GREEN → REFACTOR: RED commit `test:` (failing bats) then GREEN commit `feat:`\|`fix:` both committed; REFACTOR `refactor:` separate commit after, tests unchanged \& green. Conventional Commits + `Why:` body. guard `tdd-order` (test file exists in parent of impl commit, rename-aware `-M`) + `commit-msg`; reuse xenolith \| owner infra repo `scripts/guard/{tdd-order,bats-mirror,commit-msg}.sh` (flake export if ∃, else vendor w/ provenance header). mirror, tdd-order, bats run pre-push \| `all`, ⊥ pre-commit (else RED commit impossible, xenolith `scripts/guard` B1).
- C18: ∀ checks parallel: hk `jobs`; bats `--jobs` via `pkgs.parallel` + `BATS_NUMBER_OF_PARALLEL_JOBS` (I/O-bound, owner infra repo); `depends`\|`exclusive` only for real locks. tests parallel-safe by construction (V21).
- C19: repo = control plane: CI builds `activationPackage` \& every input closure → `pr0d1r2.cachix.org`, verifies push (narinfo 200, as nix-hk does); UI setup script = 1 deterministic line pinned to repo GIT SHA (V20). bump = new SHA in UI, ⊥ other UI edit.
- C20: owner Rust tools as gate steps (pinned flake inputs, `follows`): `mth` (microlith: `mth fmt --check SPEC.md`, `mth check SPEC.md`; pin tag), `itok check` (token ceilings in `.context-limits`, `--bpe`), `sherd` (spec federation: `validate`, `sync --check`, `check`, `budget`; split `SPEC.md` when it outgrows ceiling), `pklith` ? (early: `.pklith` → `hk.pklith.pkl` hk steps, `pklith check` = ∀ tracked file type has a check that reaches it + 1-to-1 unit rule; generated steps inline `command -v … || {…}` shell ⇒ conflicts C15 → pick 1: pklith gen ∨ hand `hk.pkl`, ⊥ blanket xenolith exclude). tool failing to RUN ≠ pass (V18).
- C21: atomic commits, 1 topic each (humans read changesets): Conventional Commits, body `Why:` + spec cites; ⊥ mix topics (e.g. docs for 2 findings = 2 commits); spec change ⊥ same commit as code; RED, GREEN, REFACTOR separate (C17). unpushed mixed commit → split before push.
- C11: owner-specific values (cachix host + key, repo slug) in 1 config block at top of `setup.sh` (`# BEGIN fork config (SPEC C11)`: `cache_host`, `cache_key`, `repo`; bats: ⊥ `pr0d1r2` outside it); fork = edit block + the files outside `setup.sh` that `docs/FORKING.md` lists (allowlist, flake `nixConfig`, CI, probe \& verify defaults, `setup-line.sh`).
- C24: agent home = OPT-IN (decided 2026-10-03): setup default = Nix + `nix-dev` only; `setup.sh [SHA] --agent-home` (\| `CLAUDINIX_AGENT_HOME=1`) adds `nix:` agent home; README states what it installs (owner set rules, cavekit skills, claude-code config) \& that it changes Claude's behaviour.
- C25: paste line distribution (decided 2026-10-03): each release publishes the exact 1-line setup script (pinned SHA w/ green CI, cachix filled) in a generated README block + GitHub release notes; users copy it, run ⊥. `scripts/setup-line.sh` = maintainer tool. before the 1st release the README block holds the exact placeholder sentence the gate accepts (`scripts/guard/readme-setup-line.sh`); `just release REV` fills it. release: `release.sh record [REV]` → commit `cloud-home.storepath` → `release.sh publish REV2` (V33).
- C26: README top line = alpha status until E2 (`experiments:T57`) \& E1 (`experiments:T56`) pass: what is proven vs not, dated; removed by the commit that records them passing.
- C27: this repo's own `.claude/settings.json` SessionStart hook (decided 2026-10-03): cloud sessions working ON claudinix run `git fetch --unshallow` (if shallow) + `nix develop -c true` (hooks) before 1st commit; via bats-covered script, ⊥ inline. runs only when `CLAUDE_CODE_REMOTE=true`; hook `timeout` 600 s; always exit 0 (warnings only). command `bash "$CLAUDE_PROJECT_DIR/scripts/dev/session-start.sh"`; hooks \& session start enter the shell via `nix-dev` when installed.
- C28: per-repo config `.claudinix.toml` (decided 2026-10-03), optional, at the target repo root; read by the target-project tools (`domains`, `inputs`, `guide`, `probe`, `nix-dev`) \& the central cache job; ⊥ by `setup.sh` (environment-level, shared by repos). parsed by Nix itself (`builtins.fromTOML` via `nix eval`) ∴ ⊥ extra parser in the VM. schema \& precedence: `scripts:V34`, `scripts:I.file`; dogfood: this repo carries its own.
- C29: self-build (decided 2026-10-03): claudinix ! be buildable by its own cloud agents — a cloud session on this repo clones it, gets Nix + agent home (cavekit `/build`) from its own setup line, enters its own dev shell w/o GitHub 403s, passes its own gate (SessionStart hook, old-git shims) \& pushes a `claude/*` branch; owner reviews \& merges (CI on the branch). 1 task = 1 cloud session, launched from a laptop.

## §I INTERFACES
- file: `setup.sh [SHA] [--agent-home]` — fetched by the UI line (V20); ⊥ pasted whole; SHA = full 40-hex commit; any other arg → exit 2; `--agent-home` \| `CLAUDINIX_AGENT_HOME=1` activates the agent home (C24), else 1 line says it was skipped \& how to opt in; every fetch bounded (`--connect-timeout 10 --max-time 60`); nix-dev installed all-or-nothing; script dir only from `BASH_SOURCE` (stdin → fetch at SHA, ⊥ cwd); `CLOUD_HOME_STOREPATH` default beside the script \| temp dir. seams: `NIX_CONF_DIR`, `BIN_DIR`, `SYSTEMD_DIR`, `NIX_DEFAULT_PROFILE`, `NIX_INSTALL_URL`, `NIX_INSTALL_SHA256`, `NIX_MIN_VERSION`; agent home: `CLOUD_HOME_FLAKE`, `CLOUD_HOME_STOREPATH` (file), `CLOUD_HOME_MARKER` (default `~/.local/state/claudinix/agent-home.failed`); nix-dev: `CLAUDINIX_LIB_DIR` (default `/usr/local/lib/claudinix`, `nix-dev` symlinked into `BIN_DIR`), `CLAUDINIX_RAW_URL`, `CLAUDINIX_REV` (default: SHA arg, else `main`). Nix ops: `--option connect-timeout 10 --option stalled-download-timeout 30` + `timeout $CLAUDINIX_NIX_TIMEOUT` (s, default 120, else exit 2) on installer \& each tier; empty `CLAUDINIX_AGENT_HOME` = unset.
- cmd: `scripts/setup-line.sh [--force] [--agent-home] [REV]` (`--agent-home` appends it to the printed line, C24; gh failure says why: not installed \| not signed in \| 404 \| other) → prints the 1-line UI setup script for REV (default HEAD; full 40-hex SHA taken w/o a clone): fresh `mktemp -d`, `curl` `setup.sh` at the SHA, `bash` it w/ the SHA. refuses (exit 1) unless newest `ci.yml` run on `main` for that commit = completed success (`gh run list`, read-only, seam `GH_BIN`); `--force` prints anyway + warns.
- file: `flake.nix` output `homeConfigurations.cloud` (x86_64-linux) + its `activationPackage`; CI pushes it to cachix \& records store path in `cloud-home.storepath`.
- file: `hk.pkl` (+ `hk.pklith.pkl` ? C20), `xenolith.toml`, `.context-limits`, `scripts/guard/*.sh`, `scripts/hk/*.sh` — gate (C14-C18, C20).
- file: `.github/workflows/ci.yml` — gate + cachix push (event `push` to default branch only; write token only then) + `scripts/ci/push-sources.sh` (eval-time input sources, `nix flake archive --json`) + verify (`verify-cachix.sh --sources .` + dev shell + agent home; source ok if owner cache \| `UPSTREAM_URL` = cache.nixos.org answers 200); `fetch-depth: 0`, SHA-pinned actions, `permissions: contents: read`, `persist-credentials: false`, push only on default branch.
- file: `allowlist.txt` — Allowed domains, 1 per line, `#` comments ⊥ entered.
- file: `env-names.txt` — env vars for the env dialog: secrets as names only, ⊥ values; non-secret settings w/ value. ⊥ model: `ANTHROPIC_MODEL` on env does NOT pick the session model (probe 6: env sonnet-5-5, session `configured_model` opus-5-5); model = launch `--model` \| browser picker.
- file: `probe.sh` — run inside cloud session; prints session facts (C8) + nix health.
- file: `docs/SETUP.md` — browser steps to create \& update env from repo files (only UI-bound part, C2) + terminal env pick.
- ext.env: claude.ai/code → environment dialog: name, network level, allowed domains, env vars, setup script.
- cmd: `hk check --all` (local) = CI gate; `hk fix`.

## §V INVARIANTS
V1: `setup.sh` exit 0 ⇒ `nix --version` works from Claude Bash tool shell w/o profile sourcing (nix linked into `/usr/local/bin`).
V2: installer executed only after sha256 match; mismatch → exit ≠ 0, nothing executed.
V3: `nix.conf` managed block between begin/end marker lines, replaced whole on rerun (⊥ append-only: a changed block w/ same marker never updated): flakes on, `accept-flake-config = true`, cachix substituter + key; lines outside the block (installer's) kept; rerun ⊥ duplicates, ⊥ reinstall.
V4: Nix on PATH ≥ floor ⇒ ⊥ install. else `--daemon` iff systemd present; else `--no-daemon`. probe: image Nix found at `/nix/var/nix/profiles/default/bin` \& `~/.nix-profile` (root), no daemon, no systemd.
V5: `setup.sh` wall time on fresh VM ≤ 5 min (cache window C1); measured, ⊥ assumed. worst case w/ install 3 × `CLAUDINIX_NIX_TIMEOUT` ?
V6: ⊥ secret in repo \| env vars; cachix read-only (⊥ `CACHIX_AUTH_TOKEN`).
V7: `setup.sh` = Nix install + `nix-dev` + opt-in agent home (C3, C24) only; ⊥ target-repo step (devShell warm-up, hooks, cargo).
V8: in session, `nix develop` on target flake w/ complete `flake.lock` succeeds w/o GitHub tarball fetch: locked inputs substituted by `narHash` from `cache.nixos.org` (nixpkgs, probe 4) \| `pr0d1r2.cachix.org` (pushed by target CI, T54); devShell closure from either cache.
V9: nix store usable by session uid (whatever it is): write via daemon \| ownership. holds: session runs as root, store owned by root (probe 1).
V10: ∀ env in claude.ai UI ↔ files in this repo; mismatch = bug (§B).
V11: Nix version \& installer sha256 change together, 1 commit.
V12: ⊥ private info in repo \| history: ⊥ private hostnames, LAN, self-hosted forge paths, tokens. public-safe from 1st push.

V17: gate green before ∀ commit (fast) \& push (all); ⊥ `--no-verify`. hooks run tools from devShell: `nix develop -c hk run <hook>` (⊥ stale PATH tool, rekall B19, owner infra repo scripts invariant 7); `watch_file` ∀ `nix/*.nix` (xenolith `scripts` B2).
V18: tool missing \| crash in gate ⇒ fail w/ "gate could not run", ⊥ pass, ⊥ look like finding (itok B6/B8, xenolith `run-tool.sh`).
V19: whole-repo guards glob `**/*`; per-file steps glob by data dependency (microlith B7).
V20: UI setup script = 1 line: fetch `setup.sh` at fixed GIT SHA from `raw.githubusercontent.com/pr0d1r2/claudinix/<sha>/` (reachable from setup phase ?, E2) → run w/ same `<sha>`; `setup.sh` activates `git+https://github.com/pr0d1r2/claudinix?rev=<sha>&shallow=1#homeConfigurations.cloud.activationPackage` (substituted from cachix). same SHA ⇒ same VM result. activation derivation ⊥ depends on `cloud-home.storepath` (source filtered) ∴ CI commits store path after build w/o changing it.
V21: tests parallel-safe: own `BATS_TEST_TMPDIR`; ⊥ write-then-exec same path across forks (ETXTBSY: rekall B26, sherd B32, xenolith B3); ⊥ wall-clock asserts (rekall B5); fixtures unset `GIT_*` env (xenolith B1, sherd B25).
V22: CI proves what it claims: same `hk check --all` as local; `nix flake check --all-systems` (bare form skips systems silently, nix-hk `experiments:T14`); cachix push verified by narinfo 200 for built paths, empty \| 403 push = red (nix-hk B3-B5); pre-push peels annotated tags `^{commit}` (microlith B22, rekall B18, sherd B27).
V23: hk ≥ 1.55 (silent `--no-fail-fast` + `depends` bug, itok B21), pinned via `nix-hk`.
V24: long gate commands in the Bash tool: default 120 s does NOT kill (probe 6): command moves to background at 120 s and finishes (limit 30 min); real exit status arrives only w/ the completion notice ∴ agent prompts \& wrappers wait for completion, ⊥ read the 120 s return as result. `BASH_DEFAULT_TIMEOUT_MS` raise = optional (fewer backgrounded runs).
V25: `accept-flake-config = true` trusts cloned repo `nixConfig` ∴ env used only w/ owner-trusted repos; extra substituters outside allowlist unreachable anyway; documented in SECURITY (`docs:T36`).
V27: `hk.pkl` evaluates under the official `pkl` (⊥ only hk's lenient parser): gate step `pkl eval hk.pkl` (B5).
V28: every tracked `*.sh` w/ a shebang is executable (mode 100755); gate step checks (B6).
V29: a guard that reads history detects a shallow clone \& says so w/ the fix (`git fetch --unshallow`), ⊥ blame commits it cannot see; w/o upstream it checks `merge-base HEAD origin/HEAD..HEAD` (B7).
V30: every input needed to EVALUATE an output a session builds (agent home, dev shell) is fetchable in the cloud: `git+https` \| narinfo in an allowed cache; CI verifies narinfo for pushed sources, ⊥ only built outputs (B8). cache.nixos.org counts for sources it already serves (nixpkgs).
V31: gate output for a non-TTY caller (agent) on success ≤ a few lines; full log on failure only.
V32: the gate's git hooks fire under the git that actually commits (cloud: image git, likely < 2.54, outside the dev shell): config-based hooks (git ≥ 2.54) + `.git/hooks` shims for older git; bats proves a bad commit is refused by an old git (B9). impl: `scripts/dev/legacy-hook.sh` copied to `$(git rev-parse --git-path hooks)/{pre-commit,commit-msg,pre-push}`; exits 0 under git ≥ 2.54 (that git runs both, else gate twice), else runs `hook.hk-<event>.command`; ⊥ overwrite a foreign hook.
V33: a released SHA contains `cloud-home.storepath` for its own agent home, \& every eval-time input source has narinfo 200 (`verify-cachix.sh --sources`) before the line is published (B10).

## §T TASKS
id|status|task|cites
T1|x|ARCHIVED to SPEC-ARCHIVE.md|C7,C14,C18,V17,V18,V23
T2|x|ARCHIVED to SPEC-ARCHIVE.md|V1,V2,V3,V4,V6,V7,I.file
T3|x|ARCHIVED to SPEC-ARCHIVE.md|C8,V8,V9,I.file
T4|x|ARCHIVED to SPEC-ARCHIVE.md|C8,C6,V10,I.ext.env — done 2026-10-03: env `nix` created; probes 1-5 on sherd
T5|x|ARCHIVED to SPEC-ARCHIVE.md|V9,V4 — not needed: session uid = root (probe 1)
T10|x|ARCHIVED to SPEC-ARCHIVE.md|V11,C4
T11|.|MANUAL create public GitHub repo `pr0d1r2/claudinix`, add remote, push after `docs:T9`|C10,V12
T17|x|ARCHIVED to SPEC-ARCHIVE.md|`nix:V14`,`nix:V15`,V7,I.file
T19|x|ARCHIVED to SPEC-ARCHIVE.md|C16,C17,V17,V19
T20|x|ARCHIVED to SPEC-ARCHIVE.md|C15,V18
T21|x|ARCHIVED to SPEC-ARCHIVE.md|C20,V18
T22|x|ARCHIVED to SPEC-ARCHIVE.md|C20,C15,V19 — decided 2026-10-03: ⊥ adopt; pklith v0.1.0 (`4aa83e0`) still emits inline `command -v … \|\| {…}` per step ⇒ C15 breach; keep hand `hk.pkl`; upstream issue (emit `scripts/hk/*.sh` calls) pending owner OK to file
T23|x|ARCHIVED to SPEC-ARCHIVE.md|C19,V22,C16
T24|x|ARCHIVED to SPEC-ARCHIVE.md|V20,C19,V10
T29|x|ARCHIVED to SPEC-ARCHIVE.md|C6,V10 — answered: `github.com` allowed ⇒ 3rd-party git reads pass; `add_repo` read = no-op
T30|x|ARCHIVED to SPEC-ARCHIVE.md|C6,I.cmd,`scripts:T27`
T48|x|ARCHIVED to SPEC-ARCHIVE.md|V24,I.file
T50|.|decide env strategy: 1 shared env `nix` w/ union of target domains vs 1 env per ecosystem (`nix-rust`, …); criteria: allowlist size \& review, snapshot reuse, model per env; record decision in C6|C6,V10,I.ext.env
T51|.|unattended runs: permission mode for routines \& long jobs; what a job does while a prompt waits (timeout, report, ⊥ hang); extends `docs:T47`|`docs:T47`,C9
T54|.|cache population owner: ∀ target repo CI pushes locked inputs + devShell closure to `pr0d1r2.cachix.org` on default branch (per `docs:T6` snippet); start w/ sherd via its spec; verify narinfo 200 (V22 pattern)|V8,`docs:T6`,C16
T58|x|ARCHIVED to SPEC-ARCHIVE.md|I.file,`docs:T42` — answered 2026-10-03 (probe 6): env var ⊥ effective; launcher model wins. follow-up E3b: does `claude --cloud --model sonnet` set it? (T67)
T59|x|ARCHIVED to SPEC-ARCHIVE.md|V24,T48 — answered 2026-10-03 (probe 6): cold `hk check --all` 3m43s, backgrounded at 120 s, ⊥ killed
T60|x|ARCHIVED to SPEC-ARCHIVE.md|`experiments:T52`,`experiments:T55` — resources answered 2026-10-03 (probe 6); snapshot reuse still open (`experiments:T55`)
T61|x|ARCHIVED to SPEC-ARCHIVE.md|T29,C6 — answered: `github.com` allowed ⇒ 3rd-party git reads pass; `add_repo` read = no-op
T67|x|ARCHIVED to SPEC-ARCHIVE.md|T58,`scripts:T28`,I.cmd — answered 2026-10-03 (probe 7): `claude --cloud "<task>" --model sonnet` ⇒ configured, served \& trailer = Sonnet 5.5; `--model` before the task fails (`--cloud requires a description`)
T68|x|ARCHIVED to SPEC-ARCHIVE.md|C11,V3,I.file
T69|x|ARCHIVED to SPEC-ARCHIVE.md|V20,C19,I.file
T71|x|ARCHIVED to SPEC-ARCHIVE.md|C10,C11,V3,I.file,I.cmd
T73|x|ARCHIVED to SPEC-ARCHIVE.md|C24,V1,V4,V5,`nix:V15`
T74|x|ARCHIVED to SPEC-ARCHIVE.md|V30,V22,C19
T75|x|ARCHIVED to SPEC-ARCHIVE.md|C25,`nix:V15`,V20
T76|x|ARCHIVED to SPEC-ARCHIVE.md|C27,V17,V29
T77|x|ARCHIVED to SPEC-ARCHIVE.md|V27,V28,V19,V31,C14
T86|x|ARCHIVED to SPEC-ARCHIVE.md|V32,V17,C27,V28
T87|x|ARCHIVED to SPEC-ARCHIVE.md|V33,C25,`nix:V15`
T88|x|ARCHIVED to SPEC-ARCHIVE.md|V5,V1,`scripts:V13`
T92|x|ARCHIVED to SPEC-ARCHIVE.md|C28,`scripts:V34`
T93|.|central cache job (after 1st push): `cache-targets.txt` (flake refs of owner repos) + nightly \| dispatch workflow job → `push-sources.sh <cache> <ref>` ∀ target whose `.claudinix.toml` says `push_sources = true`, then `verify-cachix.sh --sources <ref>`; sources only, ⊥ build outputs of other repos (trust); reads cache name from `cache.name` (⊥ CLI arg only)|C28,`.:V30`,C19,V6
T99|x|ARCHIVED to SPEC-ARCHIVE.md|C29,V30,C6
T100|x|ARCHIVED to SPEC-ARCHIVE.md|C29,`scripts:V34`,V24
T101|x|ARCHIVED to SPEC-ARCHIVE.md|C29,C24,C27,`docs:T47`,`experiments:T104`

## §B BUGS
id|date|cause|fix
B1|2026-10-03|assumed "include default list" covers `*.nixos.org` (docs); proxy refused `cache.nixos.org` \& `channels.nixos.org` → `nix develop` built from source \& failed|C6 names hosts explicitly; probe checks each host (T3)
B2|2026-10-03|seed `setup.sh` appended `nix.conf` block only when marker absent ∴ adding `accept-flake-config` never reached a VM w/ old block|V3 managed block rewritten whole
B3|2026-10-03|spec `nix:V15`/V20 fetched own repo via `github:` → would 403 in cloud (caught before build)|`nix:V15`, V20 use `git+https`
B5|2026-10-03|`hk.pkl` put `///` doc comments inside `hooks {}`: official `pkl eval` rejects it; passed only via hk's lenient default parser (review R2-3)|V27
B6|2026-10-03|`scripts/setup-line.sh` committed mode 100644; docs say run it directly → `permission denied`; tests call it via `bash` ∴ never caught (review R3-1, R5-1)|V28
B7|2026-10-03|`tdd-order` in a shallow clone (every cloud session) counted the graft commit as adding all 27 scripts \& refused the push w/o saying the clone is shallow (review R4-1)|V29
B8|2026-10-03|agent home tier 1 needs home-manager, nix-home-manager-claude-code \& set-and-setting sources at EVAL time; `github:` inputs ⊥ cached (cachix-action daemon pushes only built paths) → 403 in cloud; tier 2 `cloud-home.storepath` never written → agent home never activates (review R2-1, R2-2, R1-3)|V30
B9|2026-10-03|hk 1.58 installs only config-based hooks under git ≥ 2.54 (dev shell); system git 2.50 committed a bad message unchecked ⇒ in cloud (image git) no hook fires (re-review RR-1)|V32
B10|2026-10-03|`release.sh` pinned the line to REV, then asked to commit `cloud-home.storepath` after it ⇒ the released SHA lacks the file, tier 2 404s; release ⊥ checked input sources (re-review RR-2, RR-3)|V33
