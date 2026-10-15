# SPEC

## §G GOAL

what the agent home puts in `~/.claude` \& how it behaves in a session: skills \& their toggles, rtk, caveman hooks, the cloud permission list's rules; wiring stays in `nix`.

## §N NAV

rel|path|lens
up|.|-
self|home|`~/.claude`: skills, rtk, caveman, permission rules
sib|scripts|repo shell: gate guards, hk runners, CI checks, target-project apps
sib|nix|flake outputs: dev shell, checks, agent home build, cachix push
sib|docs|plain-English docs: setup, facts, runbook, security, release
sib|experiments|cloud-session experiments \& results
sib|dev|`claudinix-dev`: generated badges \& doc numbers
sib|cloud|cloud launchers \& their prompts

## §C CONSTRAINTS

- C33: caveman terse mode = chat only (commits, PRs, docs keep AGENTS.md style); costs accepted: node per prompt, `nodejs-slim` (`nix:V16` exception).

## §I INTERFACES

## §V INVARIANTS

V35: every setting the agent home writes into `~/.claude` is checked in the GENERATED file's shape (`nix`'s `checks.x86_64-linux.cloud-home` runs the merge script \& reads `.permissions`), ⊥ trusting a module option's name (B11).
V45: home ⊥ ships a skill that competes with a gate rule (`caveman-commit` vs `commit-msg`).
V46: caveman hook \& `statusLine` commands: absolute interpreter, script in store, timeout ≥ 30.
V47: `~/.claude/skills` = exactly the enabled toggles of `nix/agent-home.toml` (cavekit as `ck-<n>`); ∀ skill: dir name = its `name:`; `/<v>` → `/ck-<v>` ⇔ `v` shipped (B50), ∀ `/ck-<v>` resolves; FORMAT.md too (B51).
V49: allowed push takes options before the remote only ∴ deny ∀ option after it (`Bash(git push * -*)` + rtk twin; no glob names every short-flag cluster, B58); older denies = 2nd layer.
V50: allowed push writes 1 ref: 1 refspec, `claude/` src ⊥ `:dst` (B59); `heads/main` denied (B60).

## §T TASKS

id|status|task|cites
T155|x|ARCHIVED to SPEC-ARCHIVE.md|V45,V46,V47,B50,B51

## §B BUGS

id|date|cause|fix
B11|2026-10-03|`programs.claude-code.permissions.{allow,deny}` writes flat keys Claude Code ignores; use freeform `settings.permissions` (pr0d1r2/nix-home-manager-claude-code#35)|V35
B46|2026-10-09|`caveman-commit` ("skip the body") in sessions; `commit-msg` refuses that|V45; skill dropped
B47|2026-10-09|check matched strings; moved `src/hooks` passed|V46: script must exist
B48|2026-10-09|`statusLine` ran `bash` from PATH|V46: absolute interpreter
B49|2026-10-09|hook timeout 5 vs upstream 30; slow start drops terse mode|V46: timeout ≥ 30
B50|2026-10-10|hardcoded verb list: dangling `/ck-x`, unpatched `/x`|V47: nix passes verbs; refs checked
B51|2026-10-10|FORMAT.md named `/spec`, `/build`: absent in home|V47: same rewrite, checked
B52|2026-10-12|rtk 0.51 rewrite of `git push origin claude/x` got no allow|`.:V44`
B54|2026-10-12|`push … HEAD:claude/x -f` matched `HEAD:*` allow (#28)|deny `-f` \& rtk twins
B55|2026-10-12|deny `*-f` refused `claude/review-f` (#29)|deny ` -f` as a word
B56|2026-10-12|`-uf`/`-fu` force-pushed past the deny (#29)|deny both as words; `-nf`… B58
B58|2026-10-12|`-nf`, `-vf`, `-d` after the refspec matched `HEAD:*` \& `claude/*` allows|V49
B59|2026-10-12|`claude/x:prod`, `claude/x rel` passed `claude/*`, `HEAD:*` allows (#32)|V50
B60|2026-10-12|`HEAD:heads/main` passed `HEAD:*`|V50
B71|2026-10-15|deny `gh pr merge *` missed `gh -R x pr merge`, `gh api …/merge`, MCP merge (C29)|V50: guard requires those denies
B75|2026-10-15|deny missed MCP file writes \& `gh api …/refs/heads/main`|V50: guard requires them
