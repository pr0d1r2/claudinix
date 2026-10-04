# SPEC

## §G GOAL

flake outputs under `nix/`: pinned dev shell, flake checks, agent home `homeConfigurations.cloud` activated by `setup.sh` \& pushed to cachix.

## §N NAV

rel|path|lens
up|.|-
self|nix|flake outputs: dev shell, checks, agent home `homeConfigurations.cloud` \\& its activation package, cachix push of it
sib|scripts|repo shell tools: gate guards, hk runners, dev shell hook, CI checks, target-project apps (`nix-dev`, `inputs`, `domains`, `guide`, probe launcher)
sib|docs|human docs in plain English: setup walkthrough, facts, runbook, security, consumer \\& release docs
sib|experiments|cloud-session experiments: prompts, dated results, setup timing, snapshot reuse, skill survival, self-build runs; results feed `docs/FACTS.md`
sib|dev|`claudinix-dev`: repo-only Rust tool, generated README badges \\& doc numbers + their drift checks, `publish = false`

## §C CONSTRAINTS

- C12: agent home reuses owner home-config pattern (`nix/modules/claude-home.nix`): `nix-home-manager-claude-code` module + set-and-setting `mkTrip` (today owner home config `lib/mk-trip.nix` → move upstream to set-and-setting, ⊥ copy) \| `lib.mkSet` meanwhile. cavekit = non-flake input `github:JuliusBrussee/cavekit` (plugins ⊥ installed in cloud ∴ skills materialized). standalone home-manager (Ubuntu, ⊥ NixOS). sources `nix-home-manager-claude-code`, set-and-setting \& cavekit as `flake = false` inputs (import `modules/default.nix`, `set/lib/mk-set.nix`) until upstream drops dev-only inputs (nix-home-manager-claude-code#34, set-and-setting#559); only `home-manager` is a flake input. since T78: nixpkgs-lock, home-manager, nix-home-manager-claude-code, set-and-setting, cavekit fetched as `git+https://github.com/<o>/<r>?ref=<branch>&shallow=1` (`.:V30`); `programs.man` \& `systemd.user` off (−~150 MiB closure, `.:V5`).

## §I INTERFACES


## §V INVARIANTS
V14: activation runs in `setup.sh` (before Claude launches) as the uid \& `$HOME` Claude runs as ∴ skills present at launch \& kept in snapshot.
V15: activation failover, tier logged: (1) `nix build "git+https://github.com/pr0d1r2/claudinix?rev=<sha>&shallow=1#homeConfigurations.cloud.activationPackage"` (⊥ `github:`: 403 unless attached, C6); (2) `nix-store -r $(cat cloud-home.storepath)` from cachix (⊥ GitHub). both fail → Nix stays usable, setup exit 0, loud warning + marker file; consumer preflight sees missing skills, ⊥ silent.
V16: agent home = agent-level tools \& skills only (what skills shell out to); ⊥ language toolchains (target devShell owns, C3).

## §T TASKS

id|status|task|cites
T15|.|set-and-setting issue: move `mkTrip` from owner home config `lib/mk-trip.nix` upstream; add cavekit category (non-flake input). via its spec|C12,C9
T16|x|ARCHIVED to SPEC-ARCHIVE.md|C12,V16,I.file
T18|x|ARCHIVED to SPEC-ARCHIVE.md|V15,`.:V6`,C5
T78|x|ARCHIVED to SPEC-ARCHIVE.md|`.:V30`,`.:V5`,V16,C12
T127|x|cloud permissions allow `git push --force-with-lease origin HEAD:claude/*` (`scripts:T126` rebase push); main deny rules unchanged|`.:C29`,`scripts:T126`
T133|x|cloud permissions allow `git push origin HEAD:*` (`scripts:T132` fixup push to a PR branch); the main deny rules still win; ⊥ force|`.:C29`,`scripts:T132`

## §B BUGS

id|date|cause|fix
