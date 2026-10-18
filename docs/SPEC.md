# SPEC

## §G GOAL

plain-English human docs under `docs/`: how to set up, run, trust \& fork the cloud environment.

## §N NAV

rel|path|lens
up|.|-
self|docs|plain-English docs: setup, facts, runbook, security, release
sib|scripts|repo shell: gate guards, hk runners, CI checks, target-project apps
sib|nix|flake outputs: dev shell, checks, agent home build, cachix push
sib|experiments|cloud-session experiments \& results
sib|dev|`claudinix-dev`: generated badges \& doc numbers
sib|home|`~/.claude`: skills, rtk, caveman, permission rules
sib|cloud|cloud launchers \& their prompts, `enroll`

## §C CONSTRAINTS

- C22: human docs = plain English (⊥ caveman), modeled on owner's public repos (sherd, itok, microlith, rekall, xenolith, pklith, nix-hk) \& nixos-poe2. waves: W1 w/ guardrails (T1): AGENTS, INTEGRATION, LLM-DISCLAIMER, linter-coverage; W2 w/ seed import + probe (T2, T3): FACTS, RUNBOOK, SECURITY, CHANGELOG; W3 before 1st push (`docs:T9`): README, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, THIRD-PARTY-NOTICES, CONSUMER, EXAMPLE, MODEL; W4 later: CLI, SESSION, FORKING. 1 doc = 1 task = 1 commit (C21). doc vs gate disagree ⇒ gate (`hk.pkl`) wins, doc fixed.
- C26: README top line = alpha status until E2 (`experiments:T57`) \& E1 (`experiments:T56`) pass: what is proven vs not, dated; removed by the commit that records them passing.

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
T38|x|ARCHIVED to SPEC-ARCHIVE.md|C22,`.:C15`,`scripts:C16`
T39|x|ARCHIVED to SPEC-ARCHIVE.md|C22,C17,C21
T40|x|ARCHIVED to SPEC-ARCHIVE.md|C22
T41|x|ARCHIVED to SPEC-ARCHIVE.md|C22,`nix:C12`
T42|x|ARCHIVED to SPEC-ARCHIVE.md|C22,I.cmd
T43|x|ARCHIVED to SPEC-ARCHIVE.md|C22,C8
T44|x|ARCHIVED to SPEC-ARCHIVE.md|C22,I.cmd
T45|x|ARCHIVED to SPEC-ARCHIVE.md|C22,C1,C8
T46|x|ARCHIVED to SPEC-ARCHIVE.md|C22,C11
T47|x|ARCHIVED to SPEC-ARCHIVE.md|C2,C9,I.cmd,`scripts:T137`,T8
T70|x|ARCHIVED to SPEC-ARCHIVE.md|`.:T24`,`.:T30`,C22
T72|x|ARCHIVED to SPEC-ARCHIVE.md|`.:C10`,`.:T71`,C22
T83|x|ARCHIVED to SPEC-ARCHIVE.md|C22,`.:C24`,`.:C25`,C26
T84|x|ARCHIVED to SPEC-ARCHIVE.md|C22
T85|x|ARCHIVED to SPEC-ARCHIVE.md|C22,`.:C17`,`.:C21`
T89|x|ARCHIVED to SPEC-ARCHIVE.md|`.:C6`,`.:V18`,C22
T94|x|ARCHIVED to SPEC-ARCHIVE.md|`.:C28`,`scripts:V34`,C22
T103|x|ARCHIVED to SPEC-ARCHIVE.md|`.:C29`,C22
T115|x|ARCHIVED to SPEC-ARCHIVE.md|`scripts:T114`,`scripts:V37`,`.:C29`,`.:C25`,C22
T117|x|ARCHIVED to SPEC-ARCHIVE.md|`scripts:T116`,`scripts:B14`,C22
T120|x|ARCHIVED to SPEC-ARCHIVE.md|`scripts:T119`,C22
T122|x|ARCHIVED to SPEC-ARCHIVE.md|`.:T121`,`.:B15`,`.:C6`,C22
T125|x|ARCHIVED to SPEC-ARCHIVE.md|`cloud:T124`,`.:C29`,C22
T128|x|ARCHIVED to SPEC-ARCHIVE.md|`cloud:T126`,C22
T130|x|ARCHIVED to SPEC-ARCHIVE.md|`cloud:T129`,C22
T134|x|ARCHIVED to SPEC-ARCHIVE.md|`cloud:T132`,C22
T136|x|ARCHIVED to SPEC-ARCHIVE.md|`cloud:T135`,C22
T149|x|CLI `spec-optimize` section, RUNBOOK: a node near its ceiling → `just spec-optimize [node]`, then `just all <PR#>`|`cloud:T148`,C22
T157|x|CLI `review`: review a PR of another repo from that repo's checkout (`<claudinix>/scripts/cloud-review.sh`); needs its own claude.ai env, GitHub app access, `gh` sign-in|`cloud:T156`,C22
T167|x|CLI `held` section; RUNBOOK: clear the `h10n-human` queue → `just held --dry-run`, close the listed duplicates, `just held`, merge each PR by hand|`cloud:T166`,`cloud:T169`,C22
T178|.|MODEL.md "What a session costs": 2026-10-03 figure = before rtk (2026-10-09), say so; how to measure (`just burn`, `nix run …#burn`, a PR's `## Burn`); 1 table (session, model, tokens, $) from the `## Burn` of this task's own `just all` (build, 7 reviews, fixup), added by the owner session before merge; the price block is the generated one (`dev:T179`, `scripts:V61`); FACTS cost row; SETUP step 0 \& CLI `burn` link it|C22,`scripts:T176`,`cloud:T177`,`dev:T179`

## §B BUGS

id|date|cause|fix
