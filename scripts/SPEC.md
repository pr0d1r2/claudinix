# SPEC

## §G GOAL

repo shell tools under `scripts/`: gate guards \& runners, dev shell hook, CI checks, target-project apps run from the project sent to cloud.

## §N NAV

rel|path|lens
up|.|-
self|scripts|repo shell tools: gate guards, hk runners, dev shell hook, CI checks, target-project apps (`nix-dev`, `inputs`, `domains`, `guide`, probe launcher)
sib|nix|flake outputs: dev shell, checks, agent home `homeConfigurations.cloud` \\& its activation package, cachix push of it
sib|docs|human docs in plain English: setup walkthrough, facts, runbook, security, consumer \\& release docs
sib|experiments|cloud-session experiments: prompts, dated results, setup timing, snapshot reuse, skill survival, self-build runs; results feed `docs/FACTS.md`
sib|dev|`claudinix-dev`: repo-only Rust tool, generated README badges \\& doc numbers + their drift checks, `publish = false`

## §C CONSTRAINTS


## §I INTERFACES

- cmd: `just bump-nix <ver>` → `scripts/bump-nix.sh`: ver ! MAJOR.MINOR.PATCH (else exit 2); fetches `install.sha256` from releases.nixos.org (1 × 64-hex ! ); rewrites `version=` \& default sha256 in `setup.sh` together (`.:V11`) or writes ⊥; runs ⊥ else. seams `BUMP_SETUP`, `NIX_RELEASES_URL`.
- cmd: `nix-dev [INSTALLABLE] [ARGS...]` — installed by `setup.sh` to `/usr/local/bin`; `nix develop` w/ V13 failover; 1st arg ⊥ `-` = installable (`.#ci`), passed to every tier \& the final `nix develop`, its flake dir's `flake.lock` read; ⊥ local flake dir \| ⊥ `flake.lock` → plain `nix develop` logged tier 1.
- cmd: target-project tools run FROM the project to be sent to cloud, ⊥ clone of this repo: flake apps `nix run github:pr0d1r2/claudinix#<app>` w/ `<app>` ∈ {`domains`, `inputs`, `guide`}; default dir = cwd (the target project). `just <app>` here = same app on `.` for dev.
- cmd: `just guide [--force] [--agent-home] [--rev SHA] [--from STEP] [flake-dir]` (credit question accepts `none`; step 5: uncached inputs + remedy before launch; 1st check `nix-dev -c true`, `--model sonnet\|opus`) → `scripts/guide.sh` (seams `CLAUDINIX_README` (default `../README.md`; app → store copy), `CLAUDINIX_SETUP_REV`, `CLAUDINIX_MODEL_DOC`, `CLAUDINIX_ENV_NAMES`). step 3 \& `update` copy setup line, ⊥ `setup.sh`: = README release block line (`.:C25`, ⊥ `gh`) + ` --agent-home` iff given; placeholder → "no release yet" + `--rev SHA` (+ newest green `main` SHA as the `--rev` to rerun with, when `gh` answers), exit 1; `--rev` 7-40 hex (V37; else exit 2 naming it) \| `CLAUDINIX_SETUP_REV` → `setup-line.sh [--force] [--agent-home] SHA`, refusal → exit 1. walks `docs/SETUP.md` steps 0-5 in order + `just guide update` = "Updating the environment" flow (selector: start page, ⊥ in session; replace whole setup script; new session verifies). per step: says what \& where, opens URL (`open` \| `xdg-open`), copies paste value (`pbcopy` \| `wl-copy` \| `xclip`; setup line, domains, env name); env name asked in step 3, default = project name (basename of git top of flake-dir, else of flake-dir), reused by step 4 \& `update`, waits Enter \| `y/n`. checks locally: `claude auth status`, `remote.defaultEnvironmentId` set, `just inputs` → uncached inputs (step 5). money step 0 = explicit `y` each (credit shown, usage credits OFF), ⊥ skippable. ⊥ network writes, ⊥ secrets.
- cmd: guide step 4 pins the env per project: after `/remote-env` (user scope only) reads the id, on `Y/n` sets `remote.defaultEnvironmentId` in the project `.claude/settings.local.json` (other keys kept; non-object file left alone; atomic write, as `dev/session-start.sh`); warns if git does not ignore it; the only file the guide writes.
- cmd: `scripts/setup-line.sh [--force] [--agent-home] [REV]` (moved from root) → prints the 1-line UI setup script for REV (default HEAD; per V37): fresh `mktemp -d`, `curl` `setup.sh` at the SHA, `bash` it w/ the SHA; `--agent-home` appended (`.:C24`). refuses (exit 1) unless newest `ci.yml` run on `main` for the SHA = completed success (`gh run list`, read-only, seam `GH_BIN`); gh failure says why: not installed \| not signed in \| 404 \| other; `--force` prints anyway + warns.
- cmd: `just domains [project-dir…] [--from-log FILE]` → union, deduped, sorted after base: (1) `allowlist.txt` base; (2) hosts detected from each project's files: `Cargo.lock`\|`Cargo.toml` → `index.crates.io`, `static.crates.io` (+ `[source]` \& git dep hosts); `flake.nix` `nixConfig` substituters; `flake.lock` non-`github` input URLs (`github` ones → `just inputs`); `.gitmodules`; `package-lock.json`\|`yarn.lock`\|`pnpm-lock.yaml` `resolved` hosts; `uv.lock`\|`requirements*.txt` → `pypi.org`, `files.pythonhosted.org`; `Gemfile.lock` remotes; `go.sum` → `proxy.golang.org`, `sum.golang.org`; (3) `--from-log`: hosts named in proxy refusals (`Host not in allowlist: <host>`, `CONNECT tunnel failed, response 403` w/ URL) from a session log. each line tagged source (`base`\|`<file>`\|`log`) w/ `--why`; plain output = paste-ready, copied to clipboard when available (`pbcopy` \| `wl-copy` \| `xclip`). ⊥ network.
- cmd: `nix run …#probe [--model M] [--yes] [--cleanup]` (refuses w/o remote `origin`, detached HEAD, unpushed \| out-of-date branch; asks y/N before a billed session unless `--yes`) (+ `just probe`): from target project, starts 1 cloud session (`claude --cloud`, needs a TTY ∴ run under `script -q`; default `--model sonnet`) w/ the probe prompt (`.:C8` facts, fetch tiers, devShell, `cargo`\|`hk` if present), finds its pushed branch by prefix `claude/nix-probe` (harness adds random suffix), prints the report; `--cleanup` deletes `claude/nix-probe*` branches (session cannot delete branches). follow-ups via `claude -p MSG --cloud ID` (no TTY needed).
- cmd: `just inputs [flake-dir]` → `scripts/inputs.sh`: ∀ node in `flake.lock` (recursive, deduped) of type `github` → 1 line `owner/repo rev status`; status = `cached` (input source store path from `nix flake archive --dry-run --json` has narinfo in `pr0d1r2.cachix.org` ∨ `cache.nixos.org`, seam `INPUTS_CACHES`; nixpkgs comes from the latter, probe 4) \| `uncached` (⊥ cached ∴ must be uncacheded to session \| routine, docs/SETUP.md). default flake-dir = `.`; works on any target flake (e.g. sherd). exit 1 iff any `uncached` w/ `--check`. any `uncached` → 1 remedy line on stderr (nix-dev fetches over git \| rewrite as `git+https://github.com/<o>/<r>`); `--check` exit 1 iff any `uncached`.
- file: `.claudinix.toml` — `version = 1` !; tables \& keys: `[session] model` (sonnet\|opus), `agent_home` (bool); `[devshell] installable` (str); `[network] extra_domains` ([str]); `[cache] name` (str), `push_sources` (bool); `[probe] branch_prefix` (str). read via `scripts/config.sh [--dir D] get <table.key>` \| `json` \| `check`. lookup: `CLAUDINIX_CONFIG_JSON` (effective config from a caller, ⊥ nix) \| `--dir D` → git top of D \| D \| w/o `--dir`: `CLAUDINIX_CONFIG` \| git top of cwd \| cwd; no file ⇒ ⊥ nix eval; default installable `.`; values: strings ≠ "", `cache.name` ~ `^[a-z0-9][a-z0-9-]*$`, `extra_domains` bare hostnames, `installable` \& `branch_prefix` ⊥ space \| quote \| control char.
- cmd: `cloud`, `rebase`, `review` take `[--model M] [--yes] [--dry-run]`; refuse no `origin`, detached, unpushed \| behind; model `--model` > `session.model` > sonnet; y/N unless `--yes`; `--dry-run` prints the pasteable command; ⊥ waits (`.:C29`). PR = number \| URL via `gh pr view </dev/null` (B19).
- cmd: `just cloud <node:Tn \| Tn>` → `scripts/cloud-task.sh`: exactly 1 open (`.`) row across §F nodes, else refuse; prompt `scripts/cloud-task-prompt.txt`; pushes `claude/<node>-<task>`, opens a PR.
- cmd: `just rebase <PR>` → `scripts/cloud-rebase.sh`: PR open, head `claude/*`, base `main` else refuse; prompt `scripts/cloud-rebase-prompt.txt`: rebase, generated outputs re-written ⊥ hand-merged, decision conflict → abort, gate, lease push to the same branch; ⊥ PR, ⊥ merge.
- cmd: `just review <role \| all> <PR>` → `scripts/cloud-review.sh`: role ∈ `scripts/review/<role>.md` (new role = new file), else refuse listing them; PR open; prompt `scripts/cloud-review-prompt.txt` + the role file: review the diff as that role only, findings → 1 PR comment; read-only.

## §V INVARIANTS
V13: input failover order, each tier logged: (1) substitute locked input by `narHash` from a cache (`.:V8`); (2) `git+https://github.com/<o>/<r>?rev=<locked rev>&shallow=1` via `--override-input` (proven probe 4: nix-hk, nixpkgs-lock; ⊥ for nixpkgs: 90k objects); (3) `github:` as locked (works only for session-attached repos); (4) `nixpkgs` → `https://channels.nixos.org/<channel>/nixexprs.tar.xz` via `--override-input` (degraded: rev ≠ lock). ∀ overrides w/ `--no-write-lock-file`, ⊥ commit lock; tier ≥ 3 → warn in session, ⊥ silent. impl (2026-10-03): tier 1 only when ∀ `github` input cached; each tier tried w/ `nix print-dev-env`, tier repeating an earlier command skipped; ⊥ `flake.lock` ∨ ⊥ `jq` → plain `nix develop`, logged tier 1; log line contains `tier N` (`.:T3` probe greps it). T79: nixpkgs matched case-insensitive (`nixos/nixpkgs`); tier 4 channel per nixpkgs node; failure log = 1st `error:` line; ⊥ `jq` → loud WARNING, plain develop.
V26: ∀ error message about a user-given path \| arg names it as given (⊥ a fallback like `.`); bats asserts the arg appears in the message.
V34: config precedence = flag > `.claudinix.toml` > built-in default; no file = today's behaviour; unknown table \| key \| wrong type \| `version` ≠ 1 → exit 2 naming the key \& the file (V26); 1 reader (`scripts/config.sh`), ⊥ ad-hoc parsing in each tool. absent `config.sh` (old nix-dev install) = no file.
V37: a claudinix commit given by the user (`setup-line.sh` REV, guide `--rev`): 40 hex = as is, ⊥ clone; 7-39 hex = short SHA → full SHA from GitHub (`gh api repos/pr0d1r2/claudinix/commits/<hex>`, read-only), ⊥ local git (the guide app runs in the target repo ∴ a local prefix may name a wrong commit); answer ⊥ 40 hex \| gh fails → exit 1 naming REV (V26), no line; other REV (`HEAD~1`, branch) → local `git rev-parse`.

## §T TASKS

id|status|task|cites
T12|x|ARCHIVED to SPEC-ARCHIVE.md|V13,`.:V8`,I.cmd
T25|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,`.:V8`,V13,C6
T26|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,C2,`.:V10`,`docs:T13`,T25
T27|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,C2,`.:V10`,C15,C16
T28|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,`.:T3`,C8
T49|x|ARCHIVED to SPEC-ARCHIVE.md|V13,T12,T25
T79|x|ARCHIVED to SPEC-ARCHIVE.md|V13,V26
T80|x|ARCHIVED to SPEC-ARCHIVE.md|V13,V26,`.:V18`
T81|x|ARCHIVED to SPEC-ARCHIVE.md|`.:C24`,`.:C25`,V26
T82|x|ARCHIVED to SPEC-ARCHIVE.md|`.:V29`,`.:V18`,`.:V17`
T90|x|ARCHIVED to SPEC-ARCHIVE.md|`.:C28`,V34,V26
T91|x|ARCHIVED to SPEC-ARCHIVE.md|V34,`.:C28`,V13
T95|x|ARCHIVED to SPEC-ARCHIVE.md|V34,V26
T96|x|ARCHIVED to SPEC-ARCHIVE.md|V34
T97|x|ARCHIVED to SPEC-ARCHIVE.md|V34
T98|x|ARCHIVED to SPEC-ARCHIVE.md|V34,V13
T113|x|ARCHIVED to SPEC-ARCHIVE.md|V37,V26,I.cmd
T114|x|ARCHIVED to SPEC-ARCHIVE.md|V37,V26,I.cmd,T113,`.:C25`
T116|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,V26,`.:C2`
T118|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,B14,`.:C2`
T119|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,V26,T116,`.:C2`
T124|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,`.:C29`
T126|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,`.:C29`,`nix:T127`
T129|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,`.:C29`,`docs:T130`

## §B BUGS

id|date|cause|fix
B4|2026-10-03|`scripts/inputs.sh /nonexistent` said `no directory .`: failed `dir="$(cd … && pwd)"` emptied `dir`, `${dir:-.}` showed `.` ⇒ user cannot tell which path was wrong (found by docs round 2 running the CLI)|V26
B13|2026-10-04|`just guide --rev c63d695` (short SHA, as git prints it) → bare usage line, exit 2: `--rev` matched only 40 hex \& the message named neither the flag nor the value ⇒ owner could not tell what was wrong; pre-release there is no published line, so `--rev` is the only path|V37,V26
B14|2026-10-04|guide step 3 \& SETUP said "select Create environment"; the dialog button reads "Add environment" (owner, 1st real run) ⇒ UI labels drift w/o notice; ⊥ invariant can check the UI (`.:C2`), ∴ a bats test pins the label the owner saw|`.:C2`
B17|2026-10-04|git exports `GIT_EXEC_PATH` to hooks; cloud push by image git 2.43 leaked `/usr/lib/git-core` into bats ∴ legacy-hook test's git 2.54 ran the old git's dir first, the shim saw 2.43 \& the gate ran twice; setup unset a fixed `GIT_*` list|`.:V21`
B19|2026-10-04|`just rebase`: `y` → "not started"; `gh` had the TTY as stdin, its reply likely preceded `y`|gh </dev/null; flush TTY before y/N
B20|2026-10-04|`just review`: a PR head or base branch name is chosen by the PR author and goes into the prompt's shell commands; `x$(id)` is a valid ref|review refuses a head \| base ⊥ `^[A-Za-z0-9._/-]+$` before any session starts
B21|2026-10-04|`just review ROLE https://github.com/other/repo/pull/12`: only the number was kept, so this repo's #12 was reviewed, billed, with no warning|a PR URL naming another repo than the remote → refuse
