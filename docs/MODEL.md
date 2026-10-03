# Model choice for cloud sessions

Which model this repository's tools start cloud sessions on, how to choose
another, and what should make you change it. Every price and fact carries the
date it was read. Prices change, so an old date is a warning.

## Current configuration

| setting | value | as of |
|---|---|---|
| Default model | Claude Sonnet 5.5 (`claude-sonnet-5-5`) | 2026-10-03 |
| How it is chosen | at launch: `claude --cloud "<task>" --model sonnet`, or the model picker when you start a session in the browser | 2026-10-03 (probe 7) |
| What does not choose it | the `ANTHROPIC_MODEL` environment variable on the cloud environment | 2026-10-03 (probe 6) |
| When to pick another | design, spec writing, ambiguous bugs, cross-repository changes: Claude Opus 5.5 (`claude-opus-5-5`) | 2026-10-03 |

The probe launcher planned in `scripts/SPEC.md` T28 passes `--model sonnet` by
default. It does not exist yet; until it does, pass the flag yourself.

## How to choose, and how to check

The task text must come first, and `--model` after it:

```sh
claude --cloud "<task>" --model sonnet
```

Putting `--model` before the task fails with `--cloud requires a description`
(probe 7, 2026-10-03).

Setting `ANTHROPIC_MODEL=claude-sonnet-5-5` on the environment is not enough.
In probe 6 (2026-10-03) the environment had it set and the session still ran
on Claude Opus 5.5: the model is fixed when the session is created. For that
reason `env-names.txt` marks the line as one that does not choose the model.

To see which model a session really ran on, read the `Co-Authored-By` trailer
of a commit it made. In probe 7 the configured model, the served model and the
trailer all said Sonnet 5.5.

## Why Sonnet 5.5 is the default

1. **Price per token decides how much work a dollar buys.** Sonnet 5.5 costs
   half of Opus 5.5 per token (table below).
2. **The work is mostly mechanical:** flake input changes, gate fixes, test
   runs and probes. A session that runs `nix develop` and reports the output
   does not need the strongest model.
3. **The measure is cost per finished task, not per token.** A cheaper model
   that needs extra attempts is not cheaper. If Sonnet 5.5 keeps failing a
   kind of task, move that kind of task up.
4. **Do not use an older Opus to save money.** Claude Opus 4.6 costs more per
   token than Opus 5.5 in the table below.

## Prices this rests on

Anthropic first-party API rates, US dollars per million tokens. Source: the
model table in the Claude API skill bundled with Claude Code 2.1.288, which
dates its own copy 2026-09-25. Read again on 2026-10-03. This is a cache of
Anthropic's price list, not the list itself: check
Anthropic's pricing page before you
budget.

| model | input | output |
|---|---|---|
| Claude Opus 5.5 | $4.00 | $20.00 |
| Claude Opus 4.6 | $5.00 | $25.00 |
| Claude Sonnet 5.5 | $2.00 | $10.00 |
| Claude Haiku 4.5 | $1.00 | $5.00 |

For scale only: a job that reads 2 million tokens and writes 200 thousand
costs about $6 on Sonnet 5.5 and $12 on Opus 5.5, at these rates.

## What a session costs

One measured figure, and it is a rough one. Eight short sessions (seven probes
and one job, seven of them on Opus 5.5) cost about $7 in total, roughly $0.90
per session, read from the usage page on 2026-10-03 (`FACTS.md`, "Cost"). The
split between sessions is not measured, so do not read it as a price for any
one kind of session.

## Not verified

- **How cloud sessions are billed.** Whether a session is charged at exactly
  the API rates above, or against your plan quota, depends on your plan and on
  any credit your account holds. Compare the balance on
  [claude.ai/settings/usage](https://claude.ai/settings/usage) before and after
  a session to see what yours does. Keep usage credits OFF (`SETUP.md`, step 0)
  so a surprise cannot reach your card.
- **Effort settings.** Sessions started with `--cloud` use whatever effort the
  model defaults to. This repository has not measured whether another level
  changes cost or quality.

## When to change it

- **A price changes, or a new model appears.** Update the table with the date
  and redo the comparison.
- **The default keeps failing a kind of task** so that retries cost more than
  one run on a stronger model.
- **Your spend per session goes up** compared with your own earlier readings
  of the usage page.
- **The cloud platform changes how the model is chosen.** Re-run a probe
  session and update `FACTS.md`.

## Change log

Newest first. Add a row whenever the configuration or a price changes.

| date | change | reason |
|---|---|---|
| 2026-10-03 | Measured about $0.90 per short session over 8 sessions. | First real figure; probes are short. |
| 2026-10-03 | Verified that `--model sonnet` after the task runs the session on Sonnet 5.5. | Probe 7. |
| 2026-10-03 | Found that `ANTHROPIC_MODEL` on the environment does not choose the model. | Probe 6 ran on Opus 5.5 with it set. |
| 2026-09-25 | Prices above first cached in the Claude API skill. | Baseline. |
