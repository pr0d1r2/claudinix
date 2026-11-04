# E1 skills survive (2026-11-04)

Task `experiments:T56`. Observed in the cloud session that built T56
(Sonnet 5.5, root, `HOME=/root`), whose environment had run the agent home.
The setup script did not run in this session: its files are dated the day
before.

| check | result |
|---|---|
| `~/.claude/settings.json` | present, root, 1588 B, born 2026-11-03 17:22; holds the `permissions` allow and deny lists from `nix/cloud-permissions.json` |
| `~/.claude/skills/{backprop,build,caveman,check,spec}` | present, born 2026-11-03 17:22; each `SKILL.md` is a symlink into the home-manager files; `build/SKILL.md` reads (frontmatter `name: build`) |
| `~/.claude/skills` itself | mtime 2026-11-04 20:12: re-stamped at session start, entries inside kept |
| `session-start-hook` | harness skill, present, also from 2026-11-03 17:22 |
| `synced/<id>/` | account skills, new at 2026-11-04 20:12 (not from the snapshot) |
| session skill list | shows backprop, build, caveman, check, spec |

## Verdict

Skills and `settings.json` placed by the setup script survive the session
start: the harness re-stamps the directories but does not remove entries,
and the session lists and reads them. The files were a day old; snapshot
reuse is not proven by this experiment. Account-synced skills arrive separately under `synced/` and
sit beside them.

## Decision

Keep the agent-home design (`nix:T16`, `.:T17`): it writes `~/.claude` at
setup and needs no account sync. Account-synced skills stay an extra source,
not a dependency.

## Not shown

- A purpose-made test skill was not placed: setup had already run. The real
  agent-home skills answer the same question.
- Whether the permission rules in `settings.json` apply without a prompt is
  `experiments:T104`.
- The files being a day old suggests the snapshot was reused, but one
  session cannot prove it (`experiments:T55`).
