# SPEC

## §G GOAL
`claudinix` ("Claude in cloud on Nix"; claud = Claude \| cloud, "i nix" = Polish "and nix"): functional Nix (flakes on, owner cachix) inside Claude Code cloud session VM + 1 home-manager activation = agent home (user packages, `~/.claude` skills incl. cavekit) before Claude starts; repo toolchains, linters, git hooks, deps = target repo's own flake devShell.

## §F FEDERATION

dir|owns|⊥owns|tokens
scripts|repo shell: gate guards, hk runners, CI checks, target-project apps|`setup.sh` (`setup`), `probe.sh` (root), flake (`nix`), cloud launchers (`cloud`)|-
nix|flake outputs: dev shell, checks, agent home build, cachix push|session setup (`setup`), shell logic (`scripts`)|-
docs|plain-English docs: setup, facts, runbook, security, release|the gate (`gate`), spec rules|-
experiments|cloud-session experiments \& results|setup code (`setup`), tools (`scripts`), the docs prose (`docs`)|-
dev|`claudinix-dev`: generated badges \& doc numbers|session code (`setup`, `scripts`), anything a user installs|-
home|`~/.claude`: skills, rtk, caveman, permission rules|flake wiring (`nix`), setup (`setup`)|-
cloud|cloud launchers \& their prompts, `enroll`|the gate \& other shell (`scripts`), permissions (`home`)|-
gate|the gate: `hk.pkl`, `xenolith.toml`, `.context-limits`, CI workflow, ceilings \& archive layout|guard \& runner shell (`scripts`), the flake (`nix`)|-
setup|`setup.sh`, `allowlist.txt`: install, network, owner values, opt-in agent home, release line|`probe.sh` (root), the setup line app (`scripts`)|-

## §N NAV

rel|path|lens
up|-|-
self|.|-

## §C CONSTRAINTS
- C1: platform = Claude Code cloud, Anthropic-hosted env: Ubuntu 24.04 x86_64; setup script = bash as root, runs before Claude Code; fs snapshot cached iff setup ≲ 5 min; cached snapshot ⇒ setup skipped; rebuilt on script \| allowlist change \| ~7d expiry. running processes ⊥ survive snapshot.
- C2: ⊥ management API for cloud envs (docs 2026-09-26) ∴ files in this repo = source of truth, pasted by hand in claude.ai/code env dialog.
- C5: substituters: `cache.nixos.org` (default) + `https://pr0d1r2.cachix.org`, key `pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=`. public, read-only ∴ ⊥ token.
- C7: repo = nix + shell (+ `hk.pkl`, CI yaml, md, toml). shell per owner infra repo: `set -euo pipefail`, shellcheck, `shfmt -i 4`, env-var seams for paths. guardrails 1st (`gate:C14`); ⊥ feature code before gate green. exception (2026-10-03): Rust crate `dev/` (`claudinix-dev`, `publish = false`, std only ∴ ⊥ crates.io, Nix-built) for repo tooling only (generated doc blocks \& drift checks), like `pklith-dev`/`xenolith-dev`; ⊥ shipped to sessions.
- C9: first consumer = owner's private seed repo (its `experiments:T7`) \& its public Rust targets; reusable by any flake repo. consumers change via own specs.
- C10: open source (2026-10-03): MIT, public `pr0d1r2/claudinix` (renamed before 1st push; working name `nix-claude-code-cloud` stays in history ⊥ rewritten); README: unofficial, ⊥ affiliated w/ \| endorsed by Anthropic, like owner's `sherd` \| `itok` \| `rekall`. public ∴ cloud sessions can clone it.
- C17: TDD: RED `test:` (failing bats) → GREEN `feat:`\|`fix:`, both committed → REFACTOR `refactor:` separate, tests unchanged \& green. Conventional Commits + `Why:` body. guards `tdd-order` (test exists in impl commit's parent, rename-aware `-M`) + `commit-msg`, from xenolith \| owner infra repo `scripts/guard/{tdd-order,bats-mirror,commit-msg}.sh` (flake export if ∃, else vendored w/ provenance header). mirror, tdd-order, bats run pre-push \| `all`, ⊥ pre-commit (else RED commit impossible, xenolith `scripts/guard` B1).
- C19: repo = control plane: CI builds `activationPackage` \& every input closure → `pr0d1r2.cachix.org`, verifies push (narinfo 200, as nix-hk does); UI setup script = 1 deterministic line pinned to repo GIT SHA (`setup:V20`). bump = new SHA in UI, ⊥ other UI edit.
- C21: atomic commits, 1 topic each (humans read changesets): Conventional Commits, body `Why:` + spec cites; ⊥ mix topics (e.g. docs for 2 findings = 2 commits); spec change ⊥ same commit as code; RED, GREEN, REFACTOR separate (C17). unpushed mixed commit → split before push.
- C27: `.claude/settings.json` SessionStart hook (2026-10-03): cloud sessions ON claudinix run `git fetch --unshallow` (if shallow) + `nix develop -c true` (hooks) before 1st commit, via bats-covered `bash "$CLAUDE_PROJECT_DIR/scripts/dev/session-start.sh"`, ⊥ inline; only when `CLAUDE_CODE_REMOTE=true`; `timeout` 600 s; always exit 0 (warns only). hooks \& session start enter the shell via `nix-dev` when installed.
- C28: `.claudinix.toml` (2026-10-03): optional, at the target repo root; read by the target-project tools (`domains`, `inputs`, `guide`, `probe`, `nix-dev`) \& the central cache job; ⊥ by `setup.sh` (env-level, shared by repos). parsed by `builtins.fromTOML` via `nix eval` ∴ ⊥ extra parser in the VM. schema \& precedence: `scripts:V34`, `scripts:I.file`; this repo carries its own.
- C29: self-build (2026-10-03): claudinix ! be buildable by its own cloud agents: a session on this repo gets Nix + agent home (`home:V47`) from its own setup line, enters its dev shell w/o GitHub 403s, passes its gate (SessionStart hook, old-git shims) \& pushes `claude/*`; agent opens a PR; only the owner merges: by hand or by `just merge` \| `just all --merge` from the owner's terminal (`cloud:V51`); the cloud list denies `gh pr merge` + rtk twin. A launcher acting on another repo's PR ⊥ merges, ⊥ edits (labels, title, body, base), ⊥ closes (`cloud:V52`); the cloud list denies `gh pr close` \& `gh pr edit` + MCP `update_pull_request` for ∀ cloud sessions (`home:V58`). 1 task = 1 build session (`just all` adds review \& fixup).

## §I INTERFACES
- file: `flake.nix` output `homeConfigurations.cloud` (x86_64-linux) + its `activationPackage`; CI pushes it to cachix \& records store path in `cloud-home.storepath`.
- file: `env-names.txt` — env vars for the env dialog: secrets as names only, ⊥ values; non-secret settings w/ value. ⊥ model: `ANTHROPIC_MODEL` on env does NOT pick the session model (probe 6: env sonnet-5-5, session `configured_model` opus-5-5); model = launch `--model` \| browser picker.
- file: `probe.sh` — run inside cloud session; prints session facts (`experiments:C8`) + nix health.
- file: `docs/SETUP.md` — browser steps to create \& update env from repo files (only UI-bound part, C2) + terminal env pick.
- ext.env: claude.ai/code → environment dialog: name, network level, allowed domains, env vars, setup script.
- cmd: `hk check --all` (local) = CI gate; `hk fix`.

## §V INVARIANTS
V1: `setup.sh` exit 0 ⇒ `nix --version` works from Claude Bash tool shell w/o profile sourcing (nix linked into `/usr/local/bin`).
V2: installer executed only after sha256 match; mismatch → exit ≠ 0, nothing executed.
V5: `setup.sh` wall time on fresh VM ≤ 5 min (cache window C1); measured, ⊥ assumed. worst case w/ install 3 × `CLAUDINIX_NIX_TIMEOUT` ?
V6: ⊥ secret in repo \| env vars; cachix read-only (⊥ `CACHIX_AUTH_TOKEN`).
V7: `setup.sh` = Nix install + `nix-dev` + opt-in agent home (`setup:C3`, `setup:C24`) only; ⊥ target-repo step (devShell warm-up, hooks, cargo).
V8: in session, `nix develop` on target flake w/ complete `flake.lock` succeeds w/o GitHub tarball fetch: locked inputs substituted by `narHash` from `cache.nixos.org` (nixpkgs, probe 4) \| `pr0d1r2.cachix.org` (pushed by target CI, T54); devShell closure from either cache.
V9: nix store usable by session uid (whatever it is): write via daemon \| ownership. holds: session runs as root, store owned by root (probe 1).
V10: ∀ env in claude.ai UI ↔ files in this repo; mismatch = bug (§B).
V11: Nix version \& installer sha256 change together, 1 commit.
V12: ⊥ private info in repo \| history: ⊥ private hostnames, LAN, self-hosted forge paths, tokens. public-safe from 1st push.

V18: tool missing \| crash in gate ⇒ fail w/ "gate could not run", ⊥ pass, ⊥ look like finding (itok B6/B8, xenolith `run-tool.sh`).
V19: whole-repo guards glob `**/*`; per-file steps glob by data dependency (microlith B7).
V21: tests parallel-safe: own `BATS_TEST_TMPDIR`; ⊥ write-then-exec same path across forks (ETXTBSY: rekall B26, sherd B32, xenolith B3); ⊥ wall-clock asserts (rekall B5); fixtures unset `GIT_*` env (xenolith B1, sherd B25); ⊥ host tools/env (B16).
V23: hk ≥ 1.55 (silent `--no-fail-fast` + `depends` bug, itok B21), pinned via `nix-hk`.
V25: `accept-flake-config = true` trusts cloned repo `nixConfig` ∴ env used only w/ owner-trusted repos; extra substituters outside allowlist unreachable anyway; documented in SECURITY (`docs:T36`).
V27: `hk.pkl` evaluates under the official `pkl` (⊥ only hk's lenient parser): gate step `pkl eval hk.pkl` (B5).
V28: every tracked `*.sh` w/ a shebang is executable (mode 100755); gate step checks (B6).
V30: every input needed to EVALUATE an output a session builds (agent home, dev shell) is fetchable in the cloud: `git+https` \| narinfo in an allowed cache; CI verifies narinfo for pushed sources, ⊥ only built outputs (B8). cache.nixos.org counts for sources it already serves (nixpkgs).
V31: gate output for a non-TTY caller (agent) on success ≤ a few lines; full log on failure only. rtk (`nix:T151`) condenses Bash output ⇒ `rc=$?` \& the log, ⊥ condensed text, are the result.
V48: ⊥ `-` in a §F node name: sherd splits cites at last `-` (sherd#128, B57); drop `node-names` when fixed.

## §T TASKS
id|status|task|cites
T1|x|ARCHIVED to SPEC-ARCHIVE.md|C7,`gate:C14`,`gate:C18`,`gate:V17`,V18,V23
T2|x|ARCHIVED to SPEC-ARCHIVE.md|V1,V2,`setup:V3`,`setup:V4`,V6,V7,I.file
T3|x|ARCHIVED to SPEC-ARCHIVE.md|`experiments:C8`,V8,V9,I.file
T4|x|ARCHIVED to SPEC-ARCHIVE.md|`experiments:C8`,`setup:C6`,V10,I.ext.env — done 2026-10-03: env `nix` created; probes 1-5 on sherd
T5|x|ARCHIVED to SPEC-ARCHIVE.md|V9,`setup:V4` — not needed: session uid = root (probe 1)
T10|x|ARCHIVED to SPEC-ARCHIVE.md|V11,`setup:C4`
T11|x|ARCHIVED to SPEC-ARCHIVE.md|C10,V12
T17|x|ARCHIVED to SPEC-ARCHIVE.md|`nix:V14`,`nix:V15`,V7,I.file
T19|x|ARCHIVED to SPEC-ARCHIVE.md|`scripts:C16`,C17,`gate:V17`,V19
T20|x|ARCHIVED to SPEC-ARCHIVE.md|`gate:C15`,V18
T21|x|ARCHIVED to SPEC-ARCHIVE.md|`gate:C20`,V18
T22|x|ARCHIVED to SPEC-ARCHIVE.md|`gate:C20`,`gate:C15`,V19 — decided 2026-10-03: ⊥ adopt; pklith v0.1.0 (`4aa83e0`) still emits inline `command -v … \|\| {…}` per step ⇒ `gate:C15` breach; keep hand `hk.pkl`; upstream issue (emit `scripts/hk/*.sh` calls) pending owner OK to file
T23|x|ARCHIVED to SPEC-ARCHIVE.md|C19,`gate:V22`,`scripts:C16`
T24|x|ARCHIVED to SPEC-ARCHIVE.md|`setup:V20`,C19,V10
T29|x|ARCHIVED to SPEC-ARCHIVE.md|`setup:C6`,V10 — answered: `github.com` allowed ⇒ 3rd-party git reads pass; `add_repo` read = no-op
T30|x|ARCHIVED to SPEC-ARCHIVE.md|`setup:C6`,I.cmd,`scripts:T27`
T48|x|ARCHIVED to SPEC-ARCHIVE.md|`gate:V24`,I.file
T50|x|ARCHIVED to SPEC-ARCHIVE.md|`setup:C6`,V10,I.ext.env
T54|.|cache population owner: ∀ target repo CI pushes locked inputs + devShell closure to `pr0d1r2.cachix.org` on default branch (per `docs:T6` snippet); start w/ sherd via its spec; verify narinfo 200 (`gate:V22` pattern); `docs/CACHE-CI.md` is the snippet; sources: target CI pushes them; once T93 lands, a target w/ `push_sources = true` skips that \& T93 pushes them. open: sherd adopts via its own spec (⊥ reachable from claudinix sessions: repo scope)|V8,`docs:T6`,`scripts:C16`
T58|x|ARCHIVED to SPEC-ARCHIVE.md|I.file,`docs:T42` — answered 2026-10-03 (probe 6): env var ⊥ effective; launcher model wins. follow-up E3b: does `claude --cloud --model sonnet` set it? (T67)
T59|x|ARCHIVED to SPEC-ARCHIVE.md|`gate:V24`,T48 — answered 2026-10-03 (probe 6): cold `hk check --all` 3m43s, backgrounded at 120 s, ⊥ killed
T60|x|ARCHIVED to SPEC-ARCHIVE.md|`experiments:T52`,`experiments:T55` — resources answered 2026-10-03 (probe 6); snapshot reuse still open (`experiments:T55`)
T61|x|ARCHIVED to SPEC-ARCHIVE.md|T29,`setup:C6` — answered: `github.com` allowed ⇒ 3rd-party git reads pass; `add_repo` read = no-op
T67|x|ARCHIVED to SPEC-ARCHIVE.md|T58,`scripts:T28`,I.cmd — answered 2026-10-03 (probe 7): `claude --cloud "<task>" --model sonnet` ⇒ configured, served \& trailer = Sonnet 5.5; `--model` before the task fails (`--cloud requires a description`)
T68|x|ARCHIVED to SPEC-ARCHIVE.md|`setup:C11`,`setup:V3`,I.file
T69|x|ARCHIVED to SPEC-ARCHIVE.md|`setup:V20`,C19,I.file
T71|x|ARCHIVED to SPEC-ARCHIVE.md|C10,`setup:C11`,`setup:V3`,I.file,I.cmd
T73|x|ARCHIVED to SPEC-ARCHIVE.md|`setup:C24`,V1,`setup:V4`,V5,`nix:V15`
T74|x|ARCHIVED to SPEC-ARCHIVE.md|V30,`gate:V22`,C19
T75|x|ARCHIVED to SPEC-ARCHIVE.md|`setup:C25`,`nix:V15`,`setup:V20`
T76|x|ARCHIVED to SPEC-ARCHIVE.md|C27,`gate:V17`,`scripts:V29`
T77|x|ARCHIVED to SPEC-ARCHIVE.md|V27,V28,V19,V31,`gate:C14`
T86|x|ARCHIVED to SPEC-ARCHIVE.md|`gate:V32`,`gate:V17`,C27,V28
T87|x|ARCHIVED to SPEC-ARCHIVE.md|`scripts:V33`,`setup:C25`,`nix:V15`
T88|x|ARCHIVED to SPEC-ARCHIVE.md|V5,V1,`scripts:V13`
T92|x|ARCHIVED to SPEC-ARCHIVE.md|C28,`scripts:V34`
T93|.|central cache job (after 1st push): `cache-targets.txt` (flake refs of owner repos) + nightly \| dispatch workflow job → `push-sources.sh <cache> <ref>` ∀ target whose `.claudinix.toml` says `push_sources = true`, then `verify-cachix.sh --sources <ref>`; sources only, ⊥ build outputs of other repos (trust); reads cache name from `cache.name` (⊥ CLI arg only)|C28,`.:V30`,C19,V6
T99|x|ARCHIVED to SPEC-ARCHIVE.md|C29,V30,`setup:C6`
T100|x|ARCHIVED to SPEC-ARCHIVE.md|C29,`scripts:V34`,`gate:V24`
T101|x|ARCHIVED to SPEC-ARCHIVE.md|C29,`setup:C24`,C27,`docs:T47`,`experiments:T104`
T105|x|ARCHIVED to SPEC-ARCHIVE.md|C22,V19,C7,`dev:V1`
T121|x|ARCHIVED to SPEC-ARCHIVE.md|`setup:V38`,`setup:C6`,B15,`docs:T122`
T152|x|ARCHIVED to SPEC-ARCHIVE.md|`nix:T151`,I.file

## §B BUGS
id|date|cause|fix
B1|2026-10-03|assumed "include default list" covers `*.nixos.org` (docs); proxy refused `cache.nixos.org` \& `channels.nixos.org` → `nix develop` built from source \& failed|`setup:C6` names hosts explicitly; probe checks each host (T3)
B2|2026-10-03|seed `setup.sh` appended `nix.conf` block only when marker absent ∴ adding `accept-flake-config` never reached a VM w/ old block|`setup:V3` managed block rewritten whole
B3|2026-10-03|spec `nix:V15`/`setup:V20` fetched own repo via `github:` → would 403 in cloud (caught before build)|`nix:V15`, `setup:V20` use `git+https`
B5|2026-10-03|`hk.pkl` put `///` doc comments inside `hooks {}`: official `pkl eval` rejects it; passed only via hk's lenient default parser|V27
B6|2026-10-03|`scripts/setup-line.sh` committed mode 100644; docs say run it directly → `permission denied`; tests call it via `bash` ∴ never caught|V28
B8|2026-10-03|agent home tier 1 needs home-manager, nix-home-manager-claude-code \& set-and-setting sources at EVAL time; `github:` inputs ⊥ cached (cachix-action daemon pushes only built paths) → 403 in cloud; tier 2 `cloud-home.storepath` never written → agent home never activates|V30
B9|2026-10-03|hk 1.58 installs only config-based hooks under git ≥ 2.54 (dev shell); system git 2.50 committed a bad message unchecked ⇒ in cloud (image git) no hook fires|`gate:V32`
B12|2026-10-03|hk loads worktree `hk.pkl` before stashing ∴ unstaged new fix steps rewrote README \& INTEGRATION in unrelated commits; 2 messages claimed numbers their diffs lacked (reworded pre-push)|`gate:V36`
B15|2026-10-04|setup line downloads `setup.sh` from `raw.githubusercontent.com`; host ∉ `allowlist.txt` → fresh env setup: `curl: (22) ... 403`|`setup:V38`
B16|2026-10-04|cloud: probe test saw the session's `nix-dev`; setup test expected unset `$USER` (setup: `id -un`)|V21
B45|2026-10-09|rtk rewrites `git push origin main` to `rtk git push …`; prefix deny rules may miss it (#24 review)|`home:V44`
B57|2026-10-12|`agent-home:C33` resolved as `home:C33` (#30)|V48
B61|2026-10-13|`node-names` trusted the §F shape: header-only passed unchecked, any `\|` line after the header was a row (#34 review)|V48
