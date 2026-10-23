# SPEC ARCHIVE

Task rows moved out of `SPEC.md` by `mth archive`. An id is never reused
(`V12`), so a citation to an archived row still resolves -- here.

This is a SINK, not a spec. The citations inside these rows point into
`SPEC.md`, so `mth check` on this file reports every one of them as dangling,
correctly and uselessly. The verb that reads it is `mth tasks`.

## §T TASKS

T106|x|`steps --write\|--check`: the whole hk step table in `docs/INTEGRATION.md` (name, layer, glob, by-hand command) from `hk.pkl` via `pkl eval -x`, replacing the counts-only check (pklith `agents`)|V1,V3,`.:T105`
T107|x|`cli --check`: each `usage:` line `docs/CLI.md` quotes = the script's own usage text (read from `scripts/*.sh`, `setup.sh`) (pklith `cli`)|V1,V3
T108|x|`config --write\|--check`: `docs/CONFIG.md` key table (key, type, default, readers) from `scripts/config.jq`'s schema (pklith `catalog`)|V1,V3,`scripts:V34`
T109|x|`notices --write\|--check`: `docs/THIRD-PARTY-NOTICES.md` inputs table (name, source, ref, whole locked rev, type) from `flake.lock` (pklith/xenolith `notices`)|V1,V3
T110|x|`facts --check`: numbers README \& `docs/LLM-DISCLAIMER.md` quote in prose (gate steps, tests, nodes, probe count, pinned Nix \& floor) = their owning files; probes = distinct `probe N` in FACTS rows (pklith `facts`)|V1
T111|x|`changelog FILE` (commit-msg step): `feat`\|`fix` staging session code (`setup.sh`, `probe.sh`, `*.txt` app data, `nix/{cloud-home,apps}.nix`, `nix/cloud-permissions.json`, `scripts/**` ⊥ `{guard,hk,ci,dev,nix}/`) ! stage `CHANGELOG.md`; else refuse w/ rule \& paths (pklith `changelog`)|`.:V20`,`docs:T37`
T123|x|enforce V39: `badges` \& `steps` `--check` on an index snapshot (`git checkout-index`) in pre-commit|V39,`.:V36`,B18
T179|x|`claudinix-dev` fills the `docs/MODEL.md` price block (`<!-- BEGIN\|END -->`) from the `scripts/burn.sh` table; `--check` fails on drift (gate step: `hk.pkl` \& the block in 1 commit, `.:V36`)|`scripts:V61`,`docs:T178`
