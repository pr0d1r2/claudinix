# SPEC

## §G GOAL

what the agent home puts in `~/.claude` \& how it behaves in a session: skills \& their toggles, rtk, caveman hooks, the cloud permission list's rules; wiring stays in `nix`. Staged: the skill, hook & toggle invariants stay in `nix` until T155.

## §N NAV

rel|path|lens
up|.|-
self|home|`~/.claude` content: skills \\& toggles, rtk, caveman hooks, cloud permission rules
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
V45: home ⊥ ships a skill that competes with a gate rule (`caveman-commit` vs `commit-msg`).
V46: caveman hook \& `statusLine` commands: absolute interpreter, script in store, timeout ≥ 30.
V47: `~/.claude/skills` = exactly the enabled toggles of `nix/agent-home.toml` (cavekit as `ck-<n>`); ∀ skill: dir name = its `name:`; `/<v>` → `/ck-<v>` ⇔ `v` shipped (B50), ∀ `/ck-<v>` resolves; FORMAT.md too (B51).

## §T TASKS

id|status|task|cites
T155|x|move the `nix` skill, hook & toggle invariants (V45-V47) & their bugs (B50, B51) here; archived tasks T151, T153, T154 stay in `nix`, history|B46,B47,B48,B49

## §B BUGS

id|date|cause|fix
B11|2026-10-03|nix-home-manager-claude-code `programs.claude-code.permissions.{allow,deny}` writes flat `"permissions.allow"` keys Claude Code ignores; workaround: freeform `programs.claude-code.settings.permissions` (pr0d1r2/nix-home-manager-claude-code#35)|V35
B46|2026-10-09|`caveman-commit` ("skip the body") in sessions; `commit-msg` refuses that|V45; skill dropped
B47|2026-10-09|check matched strings only; moved `src/hooks` passed|V46: script must exist
B48|2026-10-09|`statusLine` ran `bash` from PATH|V46: absolute interpreter
B49|2026-10-09|hook timeout 5 vs upstream 30; slow start drops terse mode|V46: timeout ≥ 30
B50|2026-10-10|hardcoded verb list: toggle off/new skill → dangling `/ck-x`, unpatched `/x`; 2 passes missed `/a,/b,/c`|V47: nix passes verbs; refs checked
B51|2026-10-10|FORMAT.md named `/spec`, `/build`: absent in home|V47: same rewrite, checked
B52|2026-10-12|rtk 0.51 rewrites `git push origin claude/x` to `rtk git push …` w/o an allow decision; unattended push waits on a prompt|`.:V44`
B54|2026-10-12|`-f` ⊥ denied: `push … HEAD:claude/x -f` matched `HEAD:*` allow (#28)|deny `-f` \& rtk twins
B55|2026-10-12|deny `*-f` refused branch `claude/review-f` (#29)|deny ` -f` as a word
B56|2026-10-12|`-uf`/`-fu` force-pushed past the deny (#29)|deny both as words; `-nf`… open
