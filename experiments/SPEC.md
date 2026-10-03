# SPEC

## §G GOAL

cloud-session experiments under `experiments/`: 1 prompt file + 1 dated result per experiment, run as Sonnet cloud jobs; facts proven here go to `docs/FACTS.md` \& the root spec.

## §N NAV

rel|path|lens
up|.|-
self|experiments|cloud-session experiments: prompts, dated results, setup timing, snapshot reuse, skill survival, self-build runs; results feed `docs/FACTS.md`
sib|scripts|repo shell tools: gate guards, hk runners, dev shell hook, CI checks, target-project apps (`nix-dev`, `inputs`, `domains`, `guide`, probe launcher)
sib|nix|flake outputs: dev shell, checks, agent home `homeConfigurations.cloud` \\& its activation package, cachix push of it
sib|docs|human docs in plain English: setup walkthrough, facts, runbook, security, consumer \\& release docs

## §C CONSTRAINTS

- C23: experiment order (T56-T66): E1, E3, E4, E5 together in 1 Sonnet session after sherd #96; E6, E7 from #96 results; E9 then E8; E2 after 1st push; E10 last; E11 alongside each.

## §I INTERFACES


## §V INVARIANTS


## §T TASKS

id|status|task|cites
T7|.|measure setup wall time on fresh VM; record; > 5 min → trim|`.:V5`,C1
T14|.|probe ext: `echo $HOME`, `id`, `ls -la ~/.claude`, `settings.json` owner \& content before/after launch; setup places 1 test skill in `~/.claude/skills` → visible to Claude (`/` list) ?|C13,`nix:V14`,I.file
T52|.|record VM resources (`nproc`, `free`, `df /`, store growth) in FACTS; set bats `--jobs`, hk jobs, cargo jobs from them|C18,`docs:T34` — measured: 4 vCPU ∴ hk \& bats jobs = 4, cargo default
T55|.|measure snapshot reuse: 2nd session in same env skips setup?; start time cold vs warm; record in FACTS|`.:V5`,C1,`docs:T34`
T56|.|EXP E1 skills survive: `setup.sh` places test skill + `~/.claude/settings.json`; session lists skills \& reads file; decides agent-home design (`nix:T16`, `.:T17`) vs account-synced skills|C13,`nix:V14`,T14
T57|.|EXP E2 SHA-pinned fetch: in session `curl raw.githubusercontent.com/<o>/<r>/<sha>/setup.sh` + `nix build git+https://…?rev=<sha>#…`; after 1st push (or sherd stand-in)|`.:V20`,`nix:V15`,`.:T24`
T62|.|EXP E7 silence prompts: commit exact `add_repo` allow rule in sherd `.claude/settings.json`; try `--permission-mode` w/ `--cloud`|`docs:T47`,`.:T51`
T63|.|EXP E8 cache fast path: after sherd CI pushes inputs + devShell (`.:T54`), fresh session times plain `nix develop` (target < 10 s), confirms narHash substitution ⊥ git fetch|`.:V8`,`.:T54`
T64|.|EXP E9 `nix-dev` auto-overrides prototype on itok \| microlith w/o changing their flakes|`scripts:T49`,`scripts:V13`
T65|.|EXP E10 unattended routine: API-triggered routine on env `nix`, trivial task; watch prompts \& errors|`.:T51`
T66|.|EXP E11 cost per session: usage page before/after E1-E5; confirms credit charged at API rates ?|I.file,`docs:T42` — first reading 2026-10-03: $7 for 8 short sessions (7 probes + 1 job, 7 on Opus 5.5) ≈ $0.90/session; per-session split still unmeasured
T102|.|EXP self-build 1: after 1st push + green CI, `just cloud` 1 small real task (e.g. `docs:T44`-sized); record in FACTS: setup ok, dev shell time, gate ok, hooks fired (old git?), prompts hit, branch pushed, cost|C29,T56,T57,T62

## §B BUGS

id|date|cause|fix
