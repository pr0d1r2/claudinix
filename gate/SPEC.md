# SPEC

## §G GOAL

the gate: hk steps \& how they run, CI, the owner Rust tools, token ceilings \& archive layout; the guard \& runner shell stays in `scripts`.

## §N NAV

rel|path|lens
up|.|-
self|gate|the gate: `hk.pkl`, `xenolith.toml`, `.context-limits`, CI workflow, ceilings \& archive layout
sib|scripts|repo shell: gate guards, hk runners, CI checks, target-project apps
sib|nix|flake outputs: dev shell, checks, agent home build, cachix push
sib|docs|plain-English docs: setup, facts, runbook, security, release
sib|experiments|cloud-session experiments \& results
sib|dev|`claudinix-dev`: generated badges \& doc numbers
sib|home|`~/.claude`: skills, rtk, caveman, permission rules
sib|cloud|cloud launchers \& their prompts, `enroll`
sib|setup|`setup.sh`, `allowlist.txt`: install, network, owner values, opt-in agent home, release line

## §C CONSTRAINTS

- C14: gate = hk via `github:pr0d1r2/nix-hk` (binary only; checks in our `hk.pkl`). `nixpkgs-lock` + `nix-hk` w/ `follows` (⊥ forked nixpkgs ∴ cachix hits). `hk.pkl` per itok \| xenolith: vendored `pkl/Config.pkl`, `fail_fast`, `CLX_NO_PROGRESS=1` (in `env`, success = silence, `.:V31`), `local fast` (pre-commit, `fix=true`, `stash="git"`) ⊂ `local all` (pre-push, `check`), `commit-msg`. `hk install` from shellHook (`builtins.readFile`, ⊥ inline). CI = `nix develop --command hk check --all --check --no-fail-fast` + `nix flake check`.
- C15: language purity via xenolith (`xnl`, `.override { languages = [ "nix" "shell" ]; }`): 1 language per file; shell ⊥ in nix strings \| hk steps \| justfile \| heredocs beyond 1 simple command → `scripts/**/*.sh`. hk step = 1 plain command (⊥ `&&` `||` `|`). `xenolith.toml` allow entries carry a reason; stale entry = violation.
- C18: ∀ checks parallel: hk `jobs`; bats `--jobs` via `pkgs.parallel` + `BATS_NUMBER_OF_PARALLEL_JOBS` (I/O-bound, owner infra repo); `depends`\|`exclusive` only for real locks. tests parallel-safe by construction (`.:V21`).
- C20: owner Rust tools as gate steps (pinned flake inputs, `follows`): `mth` (microlith, pin tag: `fmt --check`, `check`), `itok check` (`.context-limits`, `--bpe`), `sherd` (`validate`, `sync --check`, `check`, `budget`; split a node that outgrows its ceiling), `pklith` ? (`.pklith` → generated hk steps; `pklith check` = ∀ tracked file type reached by a check + 1-to-1 unit rule; its steps inline shell ⇒ conflicts C15 → pick pklith gen ∨ hand `hk.pkl`, ⊥ blanket xenolith exclude). tool failing to RUN ≠ pass (`.:V18`).
- C32: gate speed (2026-10-04): hooks run the fast layer per commit; an agent ends a task w/ `hk check --from-ref main --to-ref HEAD` (changed files); `--all` = CI, lead after merge, \& `hk.pkl`\|`flake.lock`\|`nix/dev-shell.nix` changes.
- C34: archive layout (2026-10-17): `mth archive` rewrites `SPEC-ARCHIVE.md` as §T only, so the `## §B BUGS` tables hand-moved into `cloud`, `home` \& `scripts` archives are ⊥ tool-owned ∴ ⊥ run `mth archive` on those 3 nodes (`scripts:T173` `spec-ids` now catches a loss on push, but the tool still rewrites those archives until B91 is fixed upstream); after any run on another node `git diff` of its archive ! only add rows. Upstream request: `mth archive` keeps \& appends to `## §B BUGS` (B91).

## §I INTERFACES

- file: `hk.pkl` (+ pklith-generated steps ? C20), `xenolith.toml`, `.context-limits`, `scripts/guard/*.sh`, `scripts/hk/*.sh` — gate (C14, C15, C18, C20).
- file: `.github/workflows/ci.yml` — gate + cachix push (event `push` to default branch only; write token only then) + `scripts/ci/push-sources.sh` (eval-time input sources, `nix flake archive --json`) + verify (`verify-cachix.sh --sources .` + dev shell + agent home; source ok if owner cache \| `UPSTREAM_URL` = cache.nixos.org answers 200); `fetch-depth: 0`, SHA-pinned actions, `permissions: contents: read`, `persist-credentials: false`, push only on default branch.

## §V INVARIANTS

V17: gate green before ∀ commit (fast) \& push (all); ⊥ `--no-verify`. hooks run tools from devShell: `nix develop -c hk run <hook>` (⊥ stale PATH tool, rekall B19, owner infra repo scripts invariant 7); `watch_file` ∀ `nix/*.nix` (xenolith `scripts` `.:B2`).
V22: CI proves what it claims: same `hk check --all` as local; `nix flake check --all-systems` (bare form skips systems silently, nix-hk `experiments:T14`); cachix push verified by narinfo 200 for built paths, empty \| 403 push = red (nix-hk `.:B3`-B5); pre-push peels annotated tags `^{commit}` (microlith B22, rekall B18, sherd B27).
V24: long gate commands in the Bash tool: default 120 s does NOT kill (probe 6): command moves to background at 120 s and finishes (limit 30 min); real exit status arrives only w/ the completion notice ∴ agent prompts \& wrappers wait for completion, ⊥ read the 120 s return as result. `BASH_DEFAULT_TIMEOUT_MS` raise = optional (fewer backgrounded runs).
V32: the gate's git hooks fire under the git that actually commits (cloud: image git, likely < 2.54, outside the dev shell): config-based hooks (git ≥ 2.54) + `.git/hooks` shims for older git; bats proves a bad commit is refused by an old git (`.:B9`). impl: `scripts/dev/legacy-hook.sh` copied to `$(git rev-parse --git-path hooks)/{pre-commit,commit-msg,pre-push}`; exits 0 under git ≥ 2.54 (that git runs both, else gate twice), else runs `hook.hk-<event>.command`; ⊥ overwrite a foreign hook.
V36: a commit that changes `hk.pkl` stages it w/ every file its fix steps regenerate (README badges, INTEGRATION counts) in the SAME commit; ⊥ commit other work while `hk.pkl` has unstaged edits (hk reads the worktree `hk.pkl` before `stash = "git"`) (`.:B12`).
V67: a `.context-limits` change is judged per chain (sherd#167), ⊥ per row: ⊥ chain row rises; a file row rises only if its node's chain row falls in the same change (root's file row = root's chain ∴ ⊥ rises); an added chain row ≤ the largest chain row at base; an added file row needs its node's chain row added too; deleting the file fails. A split that shrinks every chain passes; a plain raise fails. `just merge` stays strict (`cloud:V51`).

## §T TASKS

id|status|task|cites
T180|x|`hk.pkl` globs of `context-limits` \& `spec-ids` name `scripts/lib/require-full-history.sh`, the helper both source|`.:V19`,V36,`scripts:T163`

## §B BUGS

id|date|cause|fix
