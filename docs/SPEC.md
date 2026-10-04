# SPEC

## §G GOAL

plain-English human docs under `docs/`: how to set up, run, trust \& fork the cloud environment.

## §N NAV

rel|path|lens
up|.|-
self|docs|human docs in plain English: setup walkthrough, facts, runbook, security, consumer \\& release docs
sib|scripts|repo shell tools: gate guards, hk runners, dev shell hook, CI checks, target-project apps (`nix-dev`, `inputs`, `domains`, `guide`, probe launcher)
sib|nix|flake outputs: dev shell, checks, agent home `homeConfigurations.cloud` \\& its activation package, cachix push of it
sib|experiments|cloud-session experiments: prompts, dated results, setup timing, snapshot reuse, skill survival, self-build runs; results feed `docs/FACTS.md`
sib|dev|`claudinix-dev`: repo-only Rust tool, generated README badges \\& doc numbers + their drift checks, `publish = false`

## §C CONSTRAINTS

- C22: human docs = plain English (⊥ caveman), modeled on owner's public repos (sherd, itok, microlith, rekall, xenolith, pklith, nix-hk) \& nixos-poe2. waves: W1 w/ guardrails (T1): AGENTS, INTEGRATION, LLM-DISCLAIMER, linter-coverage; W2 w/ seed import + probe (T2, T3): FACTS, RUNBOOK, SECURITY, CHANGELOG; W3 before 1st push (`docs:T9`): README, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, THIRD-PARTY-NOTICES, CONSUMER, EXAMPLE, MODEL; W4 later: CLI, SESSION, FORKING. 1 doc = 1 task = 1 commit (C21). doc vs gate disagree ⇒ gate (`hk.pkl`) wins, doc fixed.

## §I INTERFACES


## §V INVARIANTS


## §T TASKS

id|status|task|cites
T6|x|ARCHIVED to SPEC-ARCHIVE.md|`.:V8`,`.:V6`,C5,C6,C3
T8|x|ARCHIVED to SPEC-ARCHIVE.md|C3,`.:V7`,C9,C8
T9|x|ARCHIVED to SPEC-ARCHIVE.md|C10,C11,`.:V12`
T13|x|ARCHIVED to SPEC-ARCHIVE.md|C2,`.:V10`,I.ext.env
T31|x|ARCHIVED to SPEC-ARCHIVE.md|C22,C17,C21
T32|x|ARCHIVED to SPEC-ARCHIVE.md|C22,C14,C18
T33|x|ARCHIVED to SPEC-ARCHIVE.md|C22,C10
T34|x|ARCHIVED to SPEC-ARCHIVE.md|C22,C8,C13
T35|x|ARCHIVED to SPEC-ARCHIVE.md|C22,`.:V20`,`.:V11`,C19
T36|x|ARCHIVED to SPEC-ARCHIVE.md|C22,`.:V6`,C5
T37|x|ARCHIVED to SPEC-ARCHIVE.md|C22,`.:V20`
T38|x|ARCHIVED to SPEC-ARCHIVE.md|C22,C15,C16
T39|x|ARCHIVED to SPEC-ARCHIVE.md|C22,C17,C21
T40|x|ARCHIVED to SPEC-ARCHIVE.md|C22
T41|x|ARCHIVED to SPEC-ARCHIVE.md|C22,`nix:C12`
T42|x|ARCHIVED to SPEC-ARCHIVE.md|C22,I.cmd
T43|x|ARCHIVED to SPEC-ARCHIVE.md|C22,C8
T44|x|ARCHIVED to SPEC-ARCHIVE.md|C22,I.cmd
T45|x|ARCHIVED to SPEC-ARCHIVE.md|C22,C1,C8
T46|x|ARCHIVED to SPEC-ARCHIVE.md|C22,C11
T47|.|cloud permission prompts (seen 2026-10-03: "Allow Claude to use add repo (claude-code-remote)?" blocked the sherd #96 session until answered): find exact tool ids (`add_repo` under server `claude-code-remote`, likely `mcp__claude-code-remote__add_repo` ?) from a session transcript; document 3 ways in `docs/SETUP.md` + `docs/CONSUMER.md`: (a) target repo committed `.claude/settings.json` `permissions.allow` (read in 1-repo sessions; user `~/.claude` ⊥ reaches cloud), (b) permission mode chosen at session start (mode dropdown \| CLI flag ?), (c) answer in UI ("Always allow" scope ?). `apps.guide` offers to write (a) into the target repo as its own commit; ⊥ allow write access by default (least privilege)|C2,C9,I.cmd,`scripts:T26`,T8
T70|x|ARCHIVED to SPEC-ARCHIVE.md|`.:T24`,`.:T30`,C22
T72|x|ARCHIVED to SPEC-ARCHIVE.md|`.:C10`,`.:T71`,C22
T83|x|ARCHIVED to SPEC-ARCHIVE.md|C22,`.:C24`,`.:C25`,`.:C26`
T84|x|ARCHIVED to SPEC-ARCHIVE.md|C22
T85|x|ARCHIVED to SPEC-ARCHIVE.md|C22,`.:C17`,`.:C21`
T89|x|ARCHIVED to SPEC-ARCHIVE.md|`.:C6`,`.:V18`,C22
T94|x|`docs/CONFIG.md`: every key, type, default, which tool reads it, precedence, example (this repo's file); CLI/README/CONSUMER/SETUP mention it; plain English|`.:C28`,`scripts:V34`,C22
T103|x|AGENTS.md + CONTRIBUTING: cloud-built changes arrive as `claude/*` branches (1 task each); how the owner launches (`just cloud Tn`), reviews (CI on the branch) \& merges; what a cloud agent must report|`.:C29`,C22
T115|x|SETUP + CLI: `--rev` takes a short SHA (`scripts:V37`) \& the pre-release hint; RUNBOOK "Build claudinix on cloud credit": owner checklist from 0 (claim credit, overage OFF, GitHub App on `pr0d1r2/claudinix`, env via `just guide --rev <sha>` (agent home from `.claudinix.toml`), optional `CLAUDINIX_SESSION_PERMISSIONS=1`, `/remote-env`, `just probe`, `just cloud`, owner opens the PR from `claude/*`); plain English|`scripts:T114`,`scripts:V37`,`.:C29`,`.:C25`,C22
T117|x|SETUP + README + RUNBOOK + CLI: env name defaults to the project name (`scripts:T116`), ⊥ `nix`; 1 env per project ∴ pin it in the repo `.claude/settings.json`; SETUP step 3 ends w/ **Add environment** (`scripts:B14`); plain English|`scripts:T116`,`scripts:B14`,C22
T120|.|1 env per project (why: domains differ; blast radius: an experiment w/ a new setup line, domain or env var stays in 1 project): SETUP step 4 (pin via guide or by hand into `.claude/settings.local.json`; `/remote-env` = user scope; `--environment` = self-hosted `ccpool_` only), RUNBOOK owner checklist \& a "Add another project" path, CLI step 4, FACTS: the documented precedence (local > project > user) as docs-stated, ⊥ measured|`scripts:T119`,C22

## §B BUGS

id|date|cause|fix
