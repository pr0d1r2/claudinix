# SPEC ARCHIVE

Task rows moved out of `SPEC.md` by `mth archive`. An id is never reused
(`V12`), so a citation to an archived row still resolves -- here.

This is a SINK, not a spec. The citations inside these rows point into
`SPEC.md`, so `mth check` on this file reports every one of them as dangling,
correctly and uselessly. The verb that reads it is `mth tasks`.

## §T TASKS

T16|x|`homeConfigurations.cloud`: home-manager standalone, `nix-home-manager-claude-code` + set (`mkTrip` \| `mkSet`) + cavekit skills (`spec`,`build`,`check`,`backprop`,`caveman`) + `FORMAT.md`; `nix flake check` asserts skill files present|C12,V16,I.file
T18|x|CI: build `activationPackage` → `cachix push pr0d1r2` → verify narinfo; CI stays `contents: read` ∴ owner records store path via `scripts/nix/record-storepath.sh` (writes `cloud-home.storepath` only on narinfo 200) \& commits it (token CI-only, `.:V6`)|V15,`.:V6`,C5
