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
