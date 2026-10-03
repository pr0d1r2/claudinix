# SPEC ARCHIVE

Task rows moved out of `SPEC.md` by `mth archive`. An id is never reused
(`V12`), so a citation to an archived row still resolves -- here.

This is a SINK, not a spec. The citations inside these rows point into
`SPEC.md`, so `mth check` on this file reports every one of them as dangling,
correctly and uselessly. The verb that reads it is `mth tasks`.

## §T TASKS

T109|x|`notices --write\|--check`: `docs/THIRD-PARTY-NOTICES.md` inputs table (name, source, ref, whole locked rev, type) from `flake.lock` (pklith/xenolith `notices`)|V1,V3
T110|x|`facts --check`: numbers README \& `docs/LLM-DISCLAIMER.md` quote in prose (gate steps, tests, nodes, probe count, pinned Nix \& floor) = their owning files; probes = distinct `probe N` in FACTS rows (pklith `facts`)|V1
T111|x|`changelog FILE` (commit-msg step): `feat`\|`fix` staging session code (`setup.sh`, `probe.sh`, `*.txt` app data, `nix/{cloud-home,apps}.nix`, `nix/cloud-permissions.json`, `scripts/**` ⊥ `{guard,hk,ci,dev,nix}/`) ! stage `CHANGELOG.md`; else refuse w/ rule \& paths (pklith `changelog`)|`.:V20`,`docs:T37`
