# SPEC

## §G GOAL

cloud-session experiments under `experiments/`: 1 prompt file + 1 dated result per experiment, run as Sonnet cloud jobs; facts proven here go to `docs/FACTS.md` \& the root spec.

## §N NAV

rel|path|lens
up|.|-
self|experiments|cloud-session experiments \& results
sib|scripts|repo shell: gate guards, hk runners, CI checks, target-project apps
sib|nix|flake outputs: dev shell, checks, agent home build, cachix push
sib|docs|plain-English docs: setup, facts, runbook, security, release
sib|dev|`claudinix-dev`: generated badges \& doc numbers
sib|home|`~/.claude`: skills, rtk, caveman, permission rules
sib|cloud|cloud launchers \& their prompts, `enroll`
sib|gate|the gate: `hk.pkl`, `xenolith.toml`, `.context-limits`, CI workflow, ceilings \& archive layout
sib|setup|`setup.sh`, `allowlist.txt`: install, network, owner values, opt-in agent home, release line

## §C CONSTRAINTS

- C23: experiment order (T56-T66): E1, E3, E4, E5 together in 1 Sonnet session after sherd #96; E6, E7 from #96 results; E9 then E8; E2 after 1st push; E10 last; E11 alongside each.
- C8: session facts (probe 2026-10-03, sherd): uid 0, `HOME=/root`, PID 1 `process_api` (⊥ systemd), `unshare -Ur` ok, `PATH` starts `/nix/var/nix/profiles/default/bin`. image ships Nix 2.34.6 (nix-installer, root profile, ⊥ daemon) ∴ `setup.sh` only configures \& links. clone shallow ∴ `tdd-order` needs unshallow. git author `Claude <noreply@anthropic.com>`, ssh-signed, harness adds `Claude-Session:` trailer. pushed branch gets a random suffix (`claude/nix-probe-8yxk95`).
- C8b: probe log 2-4 (sherd, 2026-10-03) → `docs/FACTS.md` (dated per probe); conclusions live in `setup:C6`, C8, `.:V8`, `scripts:V13`.
- C8c: probe log 5-7 (sherd, 2026-10-03) → `docs/FACTS.md`; conclusions live in `setup:C6`, C8, `gate:V24`, `gate:C18` (4 vCPU), `docs:T43` timings.
- C13: `~/.claude/skills` exists at launch w/ harness `session-start-hook` + account-synced skills (`synced/<id>/…`); ⊥ `~/.claude/settings.json`; dirs re-stamped at session start ∴ skills \& `settings.json` pre-placed by `setup.sh` survive (E1, 2026-11-04, `docs/FACTS.md`) ∴ agent-home design stays.

## §I INTERFACES

## §V INVARIANTS

## §T TASKS

id|status|task|cites
T7|~|measure setup wall time on fresh VM; record; > 5 min → trim|`.:V5`,C1 — setup.sh prints time, warns ≥ 300 s; 1st figure: next fresh VM
T14|.|probe ext: `echo $HOME`, `id`, `ls -la ~/.claude`, `settings.json` owner \& content before/after launch; setup places 1 test skill in `~/.claude/skills` → visible to Claude (`/` list) ?|C13,`nix:V14`,I.file
T51|.|unattended runs: permission mode for routines \& long jobs; what a job does while a prompt waits (timeout, report, ⊥ hang); extends `docs:T47`|`docs:T47`,`.:C9`
T52|x|record VM resources (`nproc`, `free`, `df /`, store growth) in FACTS; set bats `--jobs`, hk jobs, cargo jobs from them|C18,`docs:T34` — measured: 4 vCPU ∴ hk \& bats jobs = 4, cargo default
T55|.|measure snapshot reuse: 2nd session in same env skips setup?; start time cold vs warm; record in FACTS|`.:V5`,C1,`docs:T34`
T56|.|EXP E1 skills survive: `setup.sh` places test skill + `~/.claude/settings.json`; session lists skills \& reads file; decides agent-home design (`nix:T16`, `.:T17`) vs account-synced skills|C13,`nix:V14`,T14
T57|.|EXP E2 SHA-pinned fetch: in session `curl raw.githubusercontent.com/<o>/<r>/<sha>/setup.sh` + `nix build git+https://…?rev=<sha>#…`; after 1st push (or sherd stand-in)|`setup:V20`,`nix:V15`,`.:T24`
T62|.|EXP E7 silence prompts: commit exact `add_repo` allow rule in sherd `.claude/settings.json`; try `--permission-mode` w/ `--cloud`|`docs:T47`,T51
T63|.|EXP E8 cache fast path: after sherd CI pushes inputs + devShell (`.:T54`), fresh session times plain `nix develop` (target < 10 s), confirms narHash substitution ⊥ git fetch|`.:V8`,`.:T54`
T64|.|EXP E9 `nix-dev` auto-overrides prototype on itok \| microlith w/o changing their flakes|`scripts:T49`,`scripts:V13`
T65|.|EXP E10 unattended routine: API-triggered routine on env `nix`, trivial task; watch prompts \& errors|T51
T66|.|EXP E11 cost per session: usage page before/after E1-E5; confirms credit charged at API rates ?|I.file,`docs:T42` — first reading 2026-10-03: $7 for 8 short sessions (7 probes + 1 job, 7 on Opus 5.5) ≈ $0.90/session; per-session split still unmeasured
T102|.|EXP self-build 1: after 1st push + green CI, `just cloud` 1 small real task (e.g. `docs:T44`-sized); record in FACTS: setup ok, dev shell time, gate ok, hooks fired (old git?), prompts hit, branch pushed, cost|C29,T56,T57,T62
T104|.|EXP permission location: in a session w/ the agent home, does `~/.claude/settings.json` written at setup survive to launch \& apply (no prompt for an allowed gate command)? does `.claude/settings.local.json` written by the SessionStart hook apply in the SAME session or only the next? record in FACTS; decides which of `.:T101`'s 2 routes stays|`.:T101`,`.:C27`,T56

## §B BUGS

id|date|cause|fix
