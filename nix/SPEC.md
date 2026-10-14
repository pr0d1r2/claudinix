# SPEC

## §G GOAL

flake outputs under `nix/`: pinned dev shell, flake checks, agent home `homeConfigurations.cloud` (`setup.sh`, cachix).

## §N NAV

rel|path|lens
up|.|-
self|nix|flake outputs: dev shell, checks, agent home build, cachix push
sib|scripts|repo shell: gate guards, hk runners, CI checks, target-project apps
sib|docs|plain-English docs: setup, facts, runbook, security, release
sib|experiments|cloud-session experiments \& results
sib|dev|`claudinix-dev`: generated badges \& doc numbers
sib|home|`~/.claude`: skills, rtk, caveman, permission rules
sib|cloud|cloud launchers \& their prompts

## §C CONSTRAINTS

- C12: agent home = owner home-config pattern: `nix-home-manager-claude-code` module + set-and-setting `lib.mkSet` (`mkTrip` upstream = T15); standalone home-manager. plugins ⊥ installed in cloud ∴ their skills \& hooks come from `flake = false` sources: cavekit, caveman (tags), the module \& set-and-setting (dev-only inputs, module#34, set-and-setting#559); flake inputs: `home-manager`, `nix-rtk`. ∀ fetched `git+https://github.com/<o>/<r>?ref=<branch \| refs/tags/T>&shallow=1` (T78, `.:V30`); `programs.man` \& `systemd.user` off (−150 MiB, `.:V5`).

## §I INTERFACES

## §V INVARIANTS
V14: activation runs in `setup.sh` before Claude launches, as Claude's uid \& `$HOME` ∴ skills present at launch.
V15: activation failover (tier logged): (1) `nix build "git+https://github.com/pr0d1r2/claudinix?rev=<sha>&shallow=1#homeConfigurations.cloud.activationPackage"` (⊥ `github:`, C6); (2) `nix-store -r $(cat cloud-home.storepath)` from cachix. both fail → Nix usable, setup exit 0, loud warning + marker.
V16: agent home = agent-level tools \& skills only; ⊥ language toolchains (target devShell owns, C3).

## §T TASKS

id|status|task|cites
T15|.|set-and-setting issue: `mkTrip` upstream; cavekit category|C12,C9
T16|x|ARCHIVED to SPEC-ARCHIVE.md|C12,V16,I.file
T18|x|ARCHIVED to SPEC-ARCHIVE.md|V15,`.:V6`,C5
T78|x|ARCHIVED to SPEC-ARCHIVE.md|`.:V30`,`.:V5`,V16,C12
T127|x|ARCHIVED to SPEC-ARCHIVE.md|`.:C29`,`cloud:T126`
T133|x|ARCHIVED to SPEC-ARCHIVE.md|`.:C29`,`cloud:T132`
T144|x|ARCHIVED to SPEC-ARCHIVE.md|`.:C29`,`cloud:T145`,B23
T147|x|ARCHIVED to SPEC-ARCHIVE.md|`.:C29`,T144,B23
T151|x|ARCHIVED to SPEC-ARCHIVE.md|C12,V16,`.:C14`,`.:C6`
T153|x|ARCHIVED to SPEC-ARCHIVE.md|C12,V16,`.:V30`
T154|x|ARCHIVED to SPEC-ARCHIVE.md|C12,`home:V45`,`home:V46`,`home:V47`,`home:C33`

## §B BUGS

id|date|cause|fix
B23|2026-10-04|`HEAD:*` allow (T133) matched `HEAD:+main` \& tag pushes; no deny did|list denies `+` refspecs \& tag pushes
B44|2026-10-09|nix-rtk locks `rtk-src` as `github:`; T151 made it the 2nd `github:` input, 403 unless cached (`.:V30`)|own `rtk-src` (`git+https`), nix-rtk follows; `rtk-pin` checks rev
B53|2026-10-12|guard: twins 1 way, deny side only main-push, rewritten set `(git\|cargo)` hand-kept, rtk 0.51 behaviour unchecked by CI; rtk's matcher ⊥ accepts `claude/*` ∴ Claude Code judges the twin (#28 review)|`.:V44`
