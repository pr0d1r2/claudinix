# SPEC

## §G GOAL

repo shell tools under `scripts/`: gate guards \& runners, dev shell hook, CI checks, target-project apps run from the project sent to cloud.

## §N NAV

rel|path|lens
up|.|-
self|scripts|repo shell tools: gate guards, hk runners, dev shell hook, CI checks, target-project apps (`nix-dev`, `inputs`, `domains`, `guide`, probe launcher)
sib|nix|flake outputs: dev shell, checks, agent home `homeConfigurations.cloud` \\& its activation package, cachix push of it
sib|docs|human docs in plain English: setup walkthrough, facts, runbook, security, consumer \\& release docs

## §C CONSTRAINTS


## §I INTERFACES


## §V INVARIANTS
V13: input failover order, each tier logged: (1) substitute locked input by `narHash` from a cache (`.:V8`); (2) `git+https://github.com/<o>/<r>?rev=<locked rev>&shallow=1` via `--override-input` (proven probe 4: nix-hk, nixpkgs-lock; ⊥ for nixpkgs: 90k objects); (3) `github:` as locked (works only for session-attached repos); (4) `nixpkgs` → `https://channels.nixos.org/<channel>/nixexprs.tar.xz` via `--override-input` (degraded: rev ≠ lock). ∀ overrides w/ `--no-write-lock-file`, ⊥ commit lock; tier ≥ 3 → warn in session, ⊥ silent.

## §T TASKS

id|status|task|cites
T12|.|`nix-dev` wrapper: try tiers V13 in order, log tier used, channel from target `flake.lock` nixpkgs ref (`nixos-<ver>` \| `nixpkgs-unstable`) else `nixpkgs-unstable`; installed by `setup.sh`; bats w/ stub `nix`|V13,`.:V8`,I.cmd
T25|x|`apps.inputs` (+ `just inputs`) + `scripts/inputs.sh`, default dir = cwd (jq over `flake.lock`, narinfo check via curl); bats w/ fixture lock files (nested, deduped, non-github skipped, cached vs attach); `--check` mode|I.cmd,`.:V8`,V13,C6
T26|.|`apps.guide` (+ `just guide`, `update` flow) + `scripts/guide.sh`, default dir = cwd; explicit model step: explain Sonnet 5.5 default vs Opus 5.5 (prices from `docs/MODEL.md`), ask choice, print the launch form `claude --cloud --model <alias>` \& browser picker hint (env var does not set it, probe 6), say how to check via commit trailer; steps from 1 data file shared w/ `docs/SETUP.md` (step ids, titles, URLs, paste values) ∴ ⊥ drift; bats via stdin answers \& stubbed `open`/clipboard/`claude`; parity test: guide steps == SETUP.md headings|I.cmd,C2,`.:V10`,`docs:T13`,T25
T27|x|`apps.domains` (+ `just domains`) + `scripts/domains.sh`, default dir = cwd: base + per-ecosystem detectors (1 script per ecosystem under `scripts/domains/`, xenolith-pure) + `--from-log`; bats per detector w/ fixture projects (sherd-like Cargo + flake, npm, py, go, gitmodules), dedup, `--why`, clipboard stubbed \& optional|I.cmd,C2,`.:V10`,C15,C16
T28|.|`apps.probe` + `scripts/probe-launch.sh` (TTY via `script`; task text right after `--cloud`, then `--model`; branch-by-prefix wait, report print, `--cleanup`); reuses `.:T3` prompt; bats w/ stubbed `claude`\|`git`|I.cmd,`.:T3`,C8
T49|.|`nix-dev` auto-overrides: read target `flake.lock`; ∀ `github` input w/o cache hit (T25 status) add `--override-input <path> git+https://github.com/<o>/<r>?rev=<locked>&shallow=1`; consumers need ⊥ flake change; prototype = E9|V13,T12,T25

## §B BUGS

id|date|cause|fix
