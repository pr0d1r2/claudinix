# SPEC

## §G GOAL

plain-English human docs under `docs/`: how to set up, run, trust \& fork the cloud environment.

## §N NAV

rel|path|lens
up|.|-
self|docs|human docs in plain English: setup walkthrough, facts, runbook, security, consumer \\& release docs
sib|scripts|repo shell tools: gate guards, hk runners, dev shell hook, CI checks, target-project apps (`nix-dev`, `inputs`, `domains`, `guide`, probe launcher)
sib|nix|flake outputs: dev shell, checks, agent home `homeConfigurations.cloud` \\& its activation package, cachix push of it

## §C CONSTRAINTS

- C22: human docs = plain English (⊥ caveman), modeled on owner's public repos (sherd, itok, microlith, rekall, xenolith, pklith, nix-hk) \& nixos-poe2. waves: W1 w/ guardrails (T1): AGENTS, INTEGRATION, LLM-DISCLAIMER, linter-coverage; W2 w/ seed import + probe (T2, T3): FACTS, RUNBOOK, SECURITY, CHANGELOG; W3 before 1st push (`docs:T9`): README, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, THIRD-PARTY-NOTICES, CONSUMER, EXAMPLE, MODEL; W4 later: CLI, SESSION, FORKING. 1 doc = 1 task = 1 commit (C21). doc vs gate disagree ⇒ gate (`hk.pkl`) wins, doc fixed.

## §I INTERFACES


## §V INVARIANTS


## §T TASKS

id|status|task|cites
T6|x|target-repo CI snippet (doc only, targets adopt via own spec): on push to default branch `nix flake archive --json` + devShell closure → `cachix push pr0d1r2`; push token in CI secrets only, ⊥ VM|`.:V8`,`.:V6`,C5,C6,C3
T8|.|`docs/CONSUMER.md` + SessionStart hook snippet for target repos (doc only, targets adopt via own spec): `github:` inputs not in cachix → `git+https://github.com/<o>/<r>?ref=main&shallow=1` (sherd #96); tools that read 3rd-party GitHub (zizmor online audit) → in cloud (`CLAUDE_CODE_REMOTE=true`) unset `GH_TOKEN`/`GITHUB_TOKEN` (placeholder `proxy-injected` ⇒ 401) \| offline, report "could not run" ⊥ "finding"; hook: `git fetch --unshallow` (tdd-order needs history), `nix develop -c hk install`; commit author in cloud = `Claude <noreply@anthropic.com>` + `Claude-Session:` trailer ∴ commit-msg hooks must accept it; branch names get random suffix|C3,`.:V7`,C9,C8
T9|~|`LICENSE` (MIT), `README.md` (what, paste steps, fork block C11, known limits); `.:V12` scan of tree \& history before 1st push|C10,C11,`.:V12`
T13|x|ARCHIVED to SPEC-ARCHIVE.md|C2,`.:V10`,I.ext.env
T31|x|ARCHIVED to SPEC-ARCHIVE.md|C22,C17,C21
T32|x|ARCHIVED to SPEC-ARCHIVE.md|C22,C14,C18
T33|x|ARCHIVED to SPEC-ARCHIVE.md|C22,C10
T34|x|ARCHIVED to SPEC-ARCHIVE.md|C22,C8,C13
T35|x|ARCHIVED to SPEC-ARCHIVE.md|C22,`.:V20`,`.:V11`,C19
T36|x|ARCHIVED to SPEC-ARCHIVE.md|C22,`.:V6`,C5
T37|x|ARCHIVED to SPEC-ARCHIVE.md|C22,`.:V20`
T38|x|ARCHIVED to SPEC-ARCHIVE.md|C22,C15,C16
T39|x|W3 SHOULD `docs/CONTRIBUTING.md`: run `hk check`, TDD order, commit format; model owner repos|C22,C17,C21
T40|x|W3 SHOULD `docs/CODE_OF_CONDUCT.md`: same text as owner repos|C22
T41|x|W3 SHOULD `docs/THIRD-PARTY-NOTICES.md`: Nix installer, nix-hk, xenolith, set-and-setting, cavekit (MIT)|C22,C12
T42|x|W3 SHOULD `docs/MODEL.md`: why probe/launcher default to Sonnet 5.5, dated prices, when to change; generalized from the owner's private seed repo `docs/MODEL.md`|C22,I.cmd
T43|.|W3 SHOULD `docs/EXAMPLE.md`: sherd from zero to green `cargo test` in cloud w/ real timings (devShell 34 s, tests 12.5 s, gate 2m45s); model rekall/pklith `EXAMPLE.md`|C22,C8
T44|.|W4 SHOULD `docs/CLI.md`: `domains`, `inputs`, `guide`, `probe` flags, exit codes, output; model pklith `CLI.md`|C22,I.cmd
T45|.|W4 SHOULD `docs/SESSION.md`: session lifecycle `claude --cloud` → VM → clone → setup script \| snapshot → SessionStart → Claude; why edits ⊥ reach running session; model nixos-poe2 `usage.md` boot flow|C22,C1,C8
T46|.|W4 SHOULD `docs/FORKING.md`: own cachix, domains, env name (C11 block); model nixos-poe2 `development.md`|C22,C11
T47|.|cloud permission prompts (seen 2026-10-03: "Allow Claude to use add repo (claude-code-remote)?" blocked the sherd #96 session until answered): find exact tool ids (`add_repo` under server `claude-code-remote`, likely `mcp__claude-code-remote__add_repo` ?) from a session transcript; document 3 ways in `docs/SETUP.md` + `docs/CONSUMER.md`: (a) target repo committed `.claude/settings.json` `permissions.allow` (read in 1-repo sessions; user `~/.claude` ⊥ reaches cloud), (b) permission mode chosen at session start (mode dropdown \| CLI flag ?), (c) answer in UI ("Always allow" scope ?). `apps.guide` offers to write (a) into the target repo as its own commit; ⊥ allow write access by default (least privilege)|C2,C9,I.cmd,`scripts:T26`,T8

## §B BUGS

id|date|cause|fix
