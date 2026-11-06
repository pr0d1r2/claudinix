# SPEC ARCHIVE

Task rows moved out of `SPEC.md` by `mth archive`. An id is never reused
(`V12`), so a citation to an archived row still resolves -- here.

This is a SINK, not a spec. The citations inside these rows point into
`SPEC.md`, so `mth check` on this file reports every one of them as dangling,
correctly and uselessly. The verb that reads it is `mth tasks`.

## §T TASKS

T14|x|probe ext: `echo $HOME`, `id`, `ls -la ~/.claude`, `settings.json` owner \& content before/after launch; setup places 1 test skill in `~/.claude/skills` → visible to Claude (`/` list) ? — answered by E1 (T56, 2026-11-04) with real agent-home skills|C13,`nix:V14`,I.file,T56
T52|x|record VM resources (`nproc`, `free`, `df /`, store growth) in FACTS; set bats `--jobs`, hk jobs, cargo jobs from them|C18,`docs:T34` — measured: 4 vCPU ∴ hk \& bats jobs = 4, cargo default
T56|x|EXP E1 skills survive: in a session whose environment ran the agent home, `~/.claude/settings.json` \& the agent-home skills are present, listed \& readable (real skills stand in for a test skill); decides agent-home design (`nix:T16`, `.:T17`) vs account-synced skills|C13,`nix:V14`,T14
T57|x|EXP E2 SHA-pinned fetch (in session only; setup phase → T190): in session `curl raw.githubusercontent.com/<o>/<r>/<sha>/setup.sh` + `nix build git+https://…?rev=<sha>#…`; after 1st push (or sherd stand-in)|`setup:V20`,`nix:V15`,`.:T24`
T64|x|EXP E9 `nix-dev` auto-overrides prototype on itok \| microlith w/o changing their flakes|`scripts:T49`,`scripts:V13`
