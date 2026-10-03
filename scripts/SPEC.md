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
V13: input failover order, each tier logged: (1) substitute locked input by `narHash` from a cache (`.:V8`); (2) `git+https://github.com/<o>/<r>?rev=<locked rev>&shallow=1` via `--override-input` (proven probe 4: nix-hk, nixpkgs-lock; ⊥ for nixpkgs: 90k objects); (3) `github:` as locked (works only for session-attached repos); (4) `nixpkgs` → `https://channels.nixos.org/<channel>/nixexprs.tar.xz` via `--override-input` (degraded: rev ≠ lock). ∀ overrides w/ `--no-write-lock-file`, ⊥ commit lock; tier ≥ 3 → warn in session, ⊥ silent. impl (2026-10-03): tier 1 only when ∀ `github` input cached; each tier tried w/ `nix print-dev-env`, tier repeating an earlier command skipped; ⊥ `flake.lock` ∨ ⊥ `jq` → plain `nix develop`, logged tier 1; log line contains `tier N` (`.:T3` probe greps it).
V26: ∀ error message about a user-given path \| arg names it as given (⊥ a fallback like `.`); bats asserts the arg appears in the message.

## §T TASKS

id|status|task|cites
T12|x|ARCHIVED to SPEC-ARCHIVE.md|V13,`.:V8`,I.cmd
T25|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,`.:V8`,V13,C6
T26|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,C2,`.:V10`,`docs:T13`,T25
T27|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,C2,`.:V10`,C15,C16
T28|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,`.:T3`,C8
T49|x|ARCHIVED to SPEC-ARCHIVE.md|V13,T12,T25

## §B BUGS

id|date|cause|fix
B4|2026-10-03|`scripts/inputs.sh /nonexistent` said `no directory .`: failed `dir="$(cd … && pwd)"` emptied `dir`, `${dir:-.}` showed `.` ⇒ user cannot tell which path was wrong (found by docs round 2 running the CLI)|V26
