# SPEC

## §G GOAL

what the agent home puts in `~/.claude` \& how it behaves in a session: skills \& their toggles, rtk, caveman hooks, the cloud permission list's rules; wiring stays in `nix`.

## §N NAV

rel|path|lens
up|.|-
self|agent-home|`~/.claude` content: skills \\& toggles, rtk, caveman hooks, cloud permission rules
sib|scripts|repo shell: gate guards, hk runners, CI checks, target-project apps (`nix-dev`, `inputs`, `domains`, `guide`)
sib|nix|flake outputs: dev shell, checks, agent home build, cachix push
sib|docs|plain-English docs: setup, facts, runbook, security, release
sib|experiments|cloud-session experiments \\& dated results, fed to `docs/FACTS.md`
sib|dev|`claudinix-dev`: repo-only Rust tool for generated badges \\& doc numbers

## §C CONSTRAINTS

- C33: caveman terse mode = chat only (commits, PRs, docs keep AGENTS.md style); costs accepted: node per prompt, `nodejs-slim` (`nix:V16` exception).

## §I INTERFACES


## §V INVARIANTS

V35: every setting the agent home writes into `~/.claude` is checked in the GENERATED file's shape (`nix`'s `checks.x86_64-linux.cloud-home` runs the merge script \& reads `.permissions`), ⊥ trusting a module option's name (B11).

## §T TASKS

id|status|task|cites

## §B BUGS

id|date|cause|fix
B11|2026-10-03|nix-home-manager-claude-code `programs.claude-code.permissions.{allow,deny}` writes flat `"permissions.allow"` keys Claude Code ignores; workaround: freeform `programs.claude-code.settings.permissions` (pr0d1r2/nix-home-manager-claude-code#35)|V35
B46|2026-10-09|`caveman-commit` ("skip the body") in sessions; `commit-msg` refuses that|`nix:V45`; skill dropped
B47|2026-10-09|check matched strings only; moved `src/hooks` passed|`nix:V46`: script must exist
B48|2026-10-09|`statusLine` ran `bash` from PATH|`nix:V46`: absolute interpreter
B49|2026-10-09|hook timeout 5 vs upstream 30; slow start drops terse mode|`nix:V46`: timeout ≥ 30
