# SPEC ARCHIVE

Task rows moved out of `SPEC.md` by `mth archive`. An id is never reused
(`V12`), so a citation to an archived row still resolves -- here.

This is a SINK, not a spec. The citations inside these rows point into
`SPEC.md`, so `mth check` on this file reports every one of them as dangling,
correctly and uselessly. The verb that reads it is `mth tasks`.

## §T TASKS

T12|x|`nix-dev` wrapper: try tiers V13 in order, log tier used, channel from target `flake.lock` nixpkgs ref (`nixos-<ver>` \| `nixpkgs-unstable`) else `nixpkgs-unstable`; installed by `setup.sh`; bats w/ stub `nix`|V13,`.:V8`,I.cmd
T25|x|`apps.inputs` (+ `just inputs`) + `scripts/inputs.sh`, default dir = cwd (jq over `flake.lock`, narinfo check via curl); bats w/ fixture lock files (nested, deduped, non-github skipped, cached vs attach); `--check` mode|I.cmd,`.:V8`,V13,C6
T26|x|`apps.guide` (+ `just guide`, `update` flow) + `scripts/guide.sh`, default dir = cwd; explicit model step: explain Sonnet 5.5 default vs Opus 5.5 (prices from `docs/MODEL.md`), ask choice, print the launch form `claude --cloud --model <alias>` \& browser picker hint (env var does not set it, probe 6), say how to check via commit trailer; steps from 1 data file shared w/ `docs/SETUP.md` (step ids, titles, URLs, paste values) ∴ ⊥ drift; bats via stdin answers \& stubbed `open`/clipboard/`claude`; parity test: guide steps == SETUP.md headings|I.cmd,C2,`.:V10`,`docs:T13`,T25
T27|x|`apps.domains` (+ `just domains`) + `scripts/domains.sh`, default dir = cwd: base + per-ecosystem detectors (1 script per ecosystem under `scripts/domains/`, xenolith-pure) + `--from-log`; bats per detector w/ fixture projects (sherd-like Cargo + flake, npm, py, go, gitmodules), dedup, `--why`, clipboard stubbed \& optional|I.cmd,C2,`.:V10`,C15,C16
T28|x|`apps.probe` + `scripts/probe-launch.sh` (TTY via `script`; task text right after `--cloud`, then `--model`; branch-by-prefix wait, report print, `--cleanup`); reuses `.:T3` prompt; bats w/ stubbed `claude`\|`git`|I.cmd,`.:T3`,C8
T49|x|`nix-dev` auto-overrides: read target `flake.lock`; ∀ `github` input w/o cache hit (T25 status) add `--override-input <path> git+https://github.com/<o>/<r>?rev=<locked>&shallow=1`; consumers need ⊥ flake change; prototype = E9|V13,T12,T25
T79|x|`nix-dev`: nixpkgs match case-insensitive (`nixos/nixpkgs`); installable arg (`.#ci`) passed to every tier's `print-dev-env`; log the `error:` line, ⊥ last line; ⊥ `jq` → loud warning (failover off); per-path channel in tier 4 (review R1-1,2,8,9,11)|V13,V26
T80|x|`inputs`: status `attach` → `uncached` + 1-line remedy on stderr (`nix-dev` fetches them over git, or use `git+https://github.com/<o>/<r>`); `domains/nix.sh` skips commented lines; clipboard tool stdout → /dev/null; `verify-cachix.sh`/`record-storepath.sh` curl `\|\| true` → HTTP 000 message (review R3-4, R1-10,12,5)|V13,V26,`.:V18`
T81|x|target-project UX: `guide` first-session check uses `nix-dev -c true` \& `--model sonnet`, own step listing uncached inputs w/ remedy before launch, credit question allows "had none", absolute paths; `probe` checks remote origin \& pushed branch \& asks y/N before a billed session; `setup-line` tells auth failure from 404/no workflow (review R3-3,6,7,13,14,15,16,21)|`.:C24`,`.:C25`,V26
T82|x|guard UX: `tdd-order` shallow detect + merge-base range + split-commit recipe in refusal; `commit-msg` reports every problem at once w/ allowed types \& an example; `run-tool` says "add it to nix/dev-shell.nix" when already in the shell; shell-hook quiet on success (review R4-1,7,8,10,15)|`.:V29`,`.:V18`,`.:V17`
