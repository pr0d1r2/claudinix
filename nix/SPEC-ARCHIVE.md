# SPEC ARCHIVE

Task rows moved out of `SPEC.md` by `mth archive`. An id is never reused
(`V12`), so a citation to an archived row still resolves -- here.

This is a SINK, not a spec. The citations inside these rows point into
`SPEC.md`, so `mth check` on this file reports every one of them as dangling,
correctly and uselessly. The verb that reads it is `mth tasks`.

## §T TASKS

T16|x|`homeConfigurations.cloud`: home-manager standalone, `nix-home-manager-claude-code` + set (`mkTrip` \| `mkSet`) + cavekit skills (`spec`,`build`,`check`,`backprop`,`caveman`) + `FORMAT.md`; `nix flake check` asserts skill files present|C12,V16,I.file
T18|x|CI: build `activationPackage` → `cachix push pr0d1r2` → verify narinfo; CI stays `contents: read` ∴ owner records store path via `scripts/nix/record-storepath.sh` (writes `cloud-home.storepath` only on narinfo 200) \& commits it (token CI-only, `.:V6`)|V15,`.:V6`,C5
T78|x|agent home inputs (home-manager, nix-home-manager-claude-code, set-and-setting, cavekit) as `git+https://github.com/<o>/<r>` (`.:V30`); `programs.man.enable = false` (man-db 75 MiB, `.:V5`); skills note: in cloud they are `/spec` `/build` …, FORMAT.md at `~/.claude/FORMAT.md` (AGENTS documents)|`.:V30`,`.:V5`,V16,C12
T127|x|cloud permissions allow `git push --force-with-lease origin HEAD:claude/*` (`scripts:T126` rebase push); main deny rules unchanged|`.:C29`,`scripts:T126`
T133|x|cloud permissions allow `git push origin HEAD:*` (`scripts:T132` fixup push to a PR branch); the main deny rules still win; ⊥ force|`.:C29`,`scripts:T132`
T144|x|cloud permissions allow `git push --force-with-lease origin HEAD:*` (`scripts:T145` rebase of any PR branch); main \& `+` \& tag denies still win; ⊥ plain force; the list is one for ∀ roles (the launcher cannot hand one role an extra rule), so the grant stays global \& T147 closes the flag forms|`.:C29`,`scripts:T145`,B23
T147|x|cloud permissions deny `--delete`, `--force` \& `--mirror` after any `git push` (a trailing `*` in an allow rule let `HEAD:x --delete` through); the guard test pins the three forms|`.:C29`,T144,B23
T151|x|agent home ships `rtk` (owner 2026-10-09): input `nix-rtk` (`git+https`, branch `cached`, its `nixpkgs-lock` follows ours; our rev = rev of its cachix build, else setup compiles rtk ⊥ silent, `just inputs` shows `uncached`; the pin also moves the gate toolchain `.:C14`, so a bump re-checks it), `rtk` on PATH, Bash rewrite hook in `settings.hooks`, `~/.claude/RTK.md` + `@RTK.md` in `~/.claude/CLAUDE.md`; a check pins all 3 + the follows|C12,V16,`.:C14`,`.:C6`
