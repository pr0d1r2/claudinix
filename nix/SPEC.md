# SPEC

## §G GOAL

flake outputs under `nix/`: pinned dev shell, flake checks, agent home `homeConfigurations.cloud` activated by `setup.sh` \& pushed to cachix.

## §N NAV

rel|path|lens
up|.|-
self|nix|flake outputs: dev shell, checks, agent home `homeConfigurations.cloud` \\& its activation package, cachix push of it
sib|scripts|repo shell tools: gate guards, hk runners, dev shell hook, CI checks, target-project apps (`nix-dev`, `inputs`, `domains`, `guide`, probe launcher)
sib|docs|human docs in plain English: setup walkthrough, facts, runbook, security, consumer \\& release docs

## §C CONSTRAINTS

- C12: agent home reuses owner home config pattern (`nix/modules/claude-home.nix`): `nix-home-manager-claude-code` module + set-and-setting `mkTrip` (today owner home config `lib/mk-trip.nix` → move upstream to set-and-setting, ⊥ copy) \| `lib.mkSet` meanwhile. cavekit = non-flake input `github:JuliusBrussee/cavekit` (plugins ⊥ installed in cloud ∴ skills materialized). standalone home-manager (Ubuntu, ⊥ NixOS).

## §I INTERFACES


## §V INVARIANTS
V14: activation runs in `setup.sh` (before Claude launches) as the uid \& `$HOME` Claude runs as ∴ skills present at launch \& kept in snapshot.
V15: activation failover, tier logged: (1) `nix build "git+https://github.com/pr0d1r2/nix-claude-code-cloud?rev=<sha>&shallow=1#homeConfigurations.cloud.activationPackage"` (⊥ `github:`: 403 unless attached, C6); (2) `nix-store -r $(cat cloud-home.storepath)` from cachix (⊥ GitHub). both fail → Nix stays usable, setup exit 0, loud warning + marker file; consumer preflight sees missing skills, ⊥ silent.
V16: agent home = agent-level tools \& skills only (what skills shell out to); ⊥ language toolchains (target devShell owns, C3).

## §T TASKS

id|status|task|cites
T15|.|set-and-setting issue: move `mkTrip` from owner home config `lib/mk-trip.nix` upstream; add cavekit category (non-flake input). via its spec|C12,C9
T16|.|`homeConfigurations.cloud`: home-manager standalone, `nix-home-manager-claude-code` + set (`mkTrip` \| `mkSet`) + cavekit skills (`spec`,`build`,`check`,`backprop`,`caveman`) + `FORMAT.md`; `nix flake check` asserts skill files present|C12,V16,I.file
T18|.|CI: build `activationPackage` → `cachix push pr0d1r2` → commit store path to `cloud-home.storepath` (token CI-only, `.:V6`)|V15,`.:V6`,C5

## §B BUGS

id|date|cause|fix
