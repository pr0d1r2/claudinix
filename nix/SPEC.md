# SPEC

## §G GOAL

flake outputs under `nix/`: pinned dev shell, flake checks, agent home `homeConfigurations.cloud` (`setup.sh`, cachix).

## §N NAV

rel|path|lens
up|.|-
self|nix|flake outputs: dev shell, checks, agent home `homeConfigurations.cloud` \\& its activation package, cachix push of it
sib|scripts|repo shell tools: gate guards, hk runners, dev shell hook, CI checks, target-project apps (`nix-dev`, `inputs`, `domains`, `guide`, probe launcher)
sib|docs|human docs in plain English: setup walkthrough, facts, runbook, security, consumer \\& release docs
sib|experiments|cloud-session experiments: prompts, dated results, setup timing, snapshot reuse, skill survival, self-build runs; results feed `docs/FACTS.md`
sib|dev|`claudinix-dev`: repo-only Rust tool, generated README badges \\& doc numbers + their drift checks, `publish = false`

## §C CONSTRAINTS

- C12: agent home = owner home-config pattern: `nix-home-manager-claude-code` module + set-and-setting `lib.mkSet` (`mkTrip` upstream = T15); standalone home-manager. plugins ⊥ installed in cloud ∴ their skills \& hooks come from `flake = false` sources: cavekit, caveman (tags), the module \& set-and-setting (dev-only inputs, module#34, set-and-setting#559); flake inputs: `home-manager`, `nix-rtk`. ∀ fetched `git+https://github.com/<o>/<r>?ref=<branch \| refs/tags/T>&shallow=1` (T78, `.:V30`); `programs.man` \& `systemd.user` off (−150 MiB, `.:V5`).
- C33: caveman terse mode = chat only (commits, PRs, docs keep AGENTS.md style); costs accepted: node per prompt, `nodejs-slim` (V16 exception).

## §I INTERFACES


## §V INVARIANTS
V14: activation runs in `setup.sh` before Claude launches, as Claude's uid \& `$HOME` ∴ skills present at launch.
V15: activation failover (tier logged): (1) `nix build "git+https://github.com/pr0d1r2/claudinix?rev=<sha>&shallow=1#homeConfigurations.cloud.activationPackage"` (⊥ `github:`, C6); (2) `nix-store -r $(cat cloud-home.storepath)` from cachix. both fail → Nix usable, setup exit 0, loud warning + marker.
V16: agent home = agent-level tools \& skills only; ⊥ language toolchains (target devShell owns, C3).
V45: home ⊥ ships a skill that competes with a gate rule (`caveman-commit` vs `commit-msg`).
V46: caveman hook \& `statusLine` commands: absolute interpreter, script in store, timeout ≥ 30.
V47: `~/.claude/skills` = exactly the enabled toggles of `nix/agent-home.toml` (cavekit as `ck-<n>`); ∀ skill: dir name = its `name:`.

## §T TASKS

id|status|task|cites
T15|.|set-and-setting issue: `mkTrip` upstream; cavekit category|C12,C9
T16|x|ARCHIVED to SPEC-ARCHIVE.md|C12,V16,I.file
T18|x|ARCHIVED to SPEC-ARCHIVE.md|V15,`.:V6`,C5
T78|x|ARCHIVED to SPEC-ARCHIVE.md|`.:V30`,`.:V5`,V16,C12
T127|x|ARCHIVED to SPEC-ARCHIVE.md|`.:C29`,`scripts:T126`
T133|x|ARCHIVED to SPEC-ARCHIVE.md|`.:C29`,`scripts:T132`
T144|x|ARCHIVED to SPEC-ARCHIVE.md|`.:C29`,`scripts:T145`,B23
T147|x|ARCHIVED to SPEC-ARCHIVE.md|`.:C29`,T144,B23
T151|x|ARCHIVED to SPEC-ARCHIVE.md|C12,V16,`.:C14`,`.:C6`
T153|x|ARCHIVED to SPEC-ARCHIVE.md|C12,V16,`.:V30`
T154|x|ARCHIVED to SPEC-ARCHIVE.md|C12,C33,V45,V46,V47

## §B BUGS

id|date|cause|fix
B23|2026-10-04|`HEAD:*` allow (T133) matched `HEAD:+main` \& tag pushes; no deny did|list denies `+` refspecs \& tag pushes
B44|2026-10-09|nix-rtk locks `rtk-src` as `github:`; T151 made it the 2nd `github:` input, 403 unless cached (`.:V30`)|own `rtk-src` (`git+https`), nix-rtk follows; `rtk-pin` checks rev
B46|2026-10-09|`caveman-commit` ("skip the body") in sessions; `commit-msg` refuses that|V45; skill dropped
B47|2026-10-09|check matched strings only; moved `src/hooks` passed|V46: script must exist
B48|2026-10-09|`statusLine` ran `bash` from PATH|V46: absolute interpreter
B49|2026-10-09|hook timeout 5 vs upstream 30; slow start drops terse mode|V46: timeout ≥ 30
