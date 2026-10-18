# SPEC ARCHIVE

Task rows moved out of `SPEC.md` by `mth archive`; fixed bug rows moved by
hand, see `docs/CONTRIBUTING.md`. An id is never reused
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
T82|x|guard UX: `tdd-order` shallow detect + merge-base range + split-commit recipe in refusal; `commit-msg` reports every problem at once w/ allowed types \& an example; `run-tool` says "add it to nix/dev-shell.nix" when already in the shell; shell-hook quiet on success (review R4-1,7,8,10,15)|V29,`.:V18`,`.:V17`
T90|x|`scripts/config.sh [--dir D] get KEY\|json\|check`: `nix eval --impure --json --expr 'builtins.fromTOML (builtins.readFile …)'`, schema check (types, unknown keys, version) via jq; no file → defaults (`json` prints them); bats w/ fixture files (missing, valid, unknown key, bad type, bad version, path w/ spaces)|`.:C28`,V34,V26
T91|x|readers: `domains` adds `network.extra_domains` (source tag `config`); `inputs` \& verify defaults use `cache.name`; `guide` \& `probe` default `--model` from `session.model`, `--agent-home` from `session.agent_home`, first check \& probe use `devshell.installable`; `probe` branch prefix from `probe.branch_prefix`; `nix-dev` default installable from `devshell.installable`; flags still win; each w/ bats|V34,`.:C28`,V13
T95|x|config values, ⊥ only types: non-empty strings; `cache.name` ~ `^[a-z0-9-]+$`; `extra_domains` = bare hostnames (⊥ scheme, path); `installable` shell-quoted (`printf %q`) wherever printed into a command \| probe prompt (build review W1, W5)|V34,V26
T96|x|1 eval per run: a tool that calls another passes the effective config (`CLAUDINIX_CONFIG_JSON`) so guide → domains/inputs \& nix-dev → inputs read the file once (W6)|V34
T97|x|`--dir D` resolves D's git top like the no-flag case; `CLAUDINIX_CONFIG` applies only w/o `--dir` (multi-project `domains`) (W3, W4)|V34
T98|x|`nix-dev` w/ an invalid `.claudinix.toml` (decided 2026-10-04): warn loudly on stderr (config.sh's own message + `using defaults`) \& run w/ defaults, exit as the dev shell does; ⊥ block the dev shell in cloud (the repo's own gate refuses a bad file at commit). other tools keep exit 2 (V34)|V34,V13
T113|x|`setup-line.sh`: a 7-39 hex REV is resolved on GitHub to the full SHA; unknown \| ambiguous → exit 1 naming it|V37,V26,I.cmd
T114|x|guide `--rev` takes a short SHA (7-40 hex), passed on to `setup-line.sh`; bad value → exit 2 naming it; "no release yet" stop names the newest green `main` SHA (`gh run list --status success`, read-only) as the `--rev` to rerun with; gh missing \| silent → today's message|V37,V26,I.cmd,T113,`.:C25`
T116|x|guide env name: step 3 asks `Environment name (Enter: <project>)`, default = project name (git top basename of flake-dir), ⊥ fixed `nix`; steps 4 \& `update` name it; step 4 says `/remote-env` is user-wide ∴ pin per-project env in the repo `.claude/settings.json` (`remote.defaultEnvironmentId`)|I.cmd,V26,`.:C2`
T118|x|guide step 3 ends w/ "select Add environment" (UI label seen 2026-10-04), ⊥ "Create environment"|I.cmd,B14,`.:C2`
T119|x|guide step 4 = per-project pin (owner 2026-10-04: 1 env per project, more soon; `/remote-env` writes user scope only, `--environment` rejects `env_` ids): show the project pin if any, ask `Pin <id> to <project> [Y/n]`, write it, warn if not ignored; ⊥ id → todo; heading "(once per project)" + SETUP heading (parity)|I.cmd,V26,T116,`.:C2`
T137|x|`guide` offers `add_repo` allow|`docs:T47`,I.cmd
T150|x|guard: `.context-limits` row ↑ \| added \| file deleted vs `origin/main` → fail, ⊥ override|`.:C20`,B81
T162|x|`scripts/lib/context-limits.sh` owns the row parser; `cloud_diff_reasons` \& the guard call it|`cloud:V51`,T150

T173|x|guard: ∀ id (T V B C) in a base `SPEC*.md` ! stay in a head `SPEC*.md`; a vanished id fails, naming it; ∀ id in an `ARCHIVED to SPEC-ARCHIVE.md` pointer line ! exist in that node's archive|B91

## §B BUGS

Bug rows moved by hand: see `docs/CONTRIBUTING.md`.

id|date|cause|fix
B4|2026-10-03|`scripts/inputs.sh /nonexistent` said `no directory .`: failed `dir="$(cd … && pwd)"` emptied `dir`, `${dir:-.}` showed `.` ⇒ user cannot tell which path was wrong (found by docs round 2 running the CLI)|V26
B13|2026-10-04|`just guide --rev c63d695` (short SHA, as git prints it) → bare usage line, exit 2: `--rev` matched only 40 hex \& the message named neither the flag nor the value ⇒ owner could not tell what was wrong; pre-release there is no published line, so `--rev` is the only path|V37,V26
B17|2026-10-04|git exports `GIT_EXEC_PATH` to hooks; cloud push by image git 2.43 leaked `/usr/lib/git-core` into bats ∴ legacy-hook test's git 2.54 ran the old git's dir first, the shim saw 2.43 \& the gate ran twice; setup unset a fixed `GIT_*` list|`.:V21`
B62|2026-10-13|setup-line test "gh not signed in" asserted `404` absent from output that names the random commit SHA ∴ ~1% of SHAs contain `404` ⇒ CI failed on a PR that changed no code (#35 run 99); test fixture forces a SHA with `404`, the assertion ignores the SHA|`scripts:V26`
B7|2026-10-03|`tdd-order` in a shallow clone (every cloud session) counted the graft commit as adding all 27 scripts \& refused the push w/o saying the clone is shallow|V29
B10|2026-10-03|`release.sh` pinned the line to REV, then asked to commit `cloud-home.storepath` after it ⇒ the released SHA lacks the file, tier 2 404s; release ⊥ checked input sources|V33
B81|2026-10-16|`Owner-Override:` trailer (any agent can write it) excused ∀ raise in range, `just merge` has none, file delete passed|`.:C20`
B82|2026-10-16|guide step 5 with `--agent-home` named `nix/cloud-permissions.json`, a file of this repo the target user lacks, as deciding add_repo ⇒ guide output names only paths the user has|`scripts:V26`
B91|2026-10-17|`mth archive` rewrites SPEC-ARCHIVE.md as §T only ∴ #48 fixup (9be154f) dropped the hand-archived `cloud` B19-B43; ⊥ check saw it|T173; rows restored
B95|2026-10-17|`awk NR == FNR` + empty/missing archive ⇒ `spec-ids` swallowed every dangling pointer, exit 0|V57
B96|2026-10-17|`spec-ids` expanded `B1-B999999999` unbounded ⇒ gate hang|V57
B97|2026-10-17|`spec-ids` skipped an unknown `ARCHIVED to` shape ⇒ failed open|V57
