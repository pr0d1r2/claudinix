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
T172|.|cloud list denies the PR verbs `merge`, `close`, `edit` from ONE verb list in the `cloud-permissions` guard: the guard derives the plain, rtk \& `gh -R x` forms from it \& checks `nix/cloud-permissions.json` against it ∴ a new verb = 1 line|`.:C29`,`cloud:V52`,B71

## §B BUGS

B46-B49, B52, B54-B56: ARCHIVED to SPEC-ARCHIVE.md `## §B BUGS`

id|date|cause|fix
B11|2026-10-03|`programs.claude-code.permissions.{allow,deny}` writes flat keys Claude Code ignores; use freeform `settings.permissions` (pr0d1r2/nix-home-manager-claude-code#35)|V35
B50|2026-10-10|hardcoded verb list: dangling `/ck-x`, unpatched `/x`|V47: nix passes verbs; refs checked
B51|2026-10-10|FORMAT.md named `/spec`, `/build`: absent in home|V47: same rewrite, checked
B58|2026-10-12|`-nf`, `-vf`, `-d` after the refspec matched `HEAD:*` \& `claude/*` allows|V49
B59|2026-10-12|`claude/x:prod`, `claude/x rel` passed `claude/*`, `HEAD:*` allows (#32)|V50
B60|2026-10-12|`HEAD:heads/main` passed `HEAD:*`|V50
B71|2026-10-15|deny `gh pr merge *` missed `gh -R x pr merge`, `gh api …/merge`, MCP merge (C29)|V50: guard requires those denies
B75|2026-10-15|deny missed MCP file writes \& `gh api …/refs/heads/main`|V50: guard requires them
