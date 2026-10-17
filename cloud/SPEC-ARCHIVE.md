# SPEC ARCHIVE

Task rows moved out of `SPEC.md` by `mth archive`. An id is never reused
(`V12`), so a citation to an archived row still resolves -- here.

This is a SINK, not a spec. The citations inside these rows point into
`SPEC.md`, so `mth check` on this file reports every one of them as dangling,
correctly and uselessly. The verb that reads it is `mth tasks`.

## §T TASKS

T124|x|cloud prompt step 6: after the push, open a PR to `main` (title = 1st commit subject; body: task row, commits, gate rc, session link) as the GitHub artifact; ⊥ merge (owner, 2026-10-04; PR #6 showed a session can)|I.cmd,`.:C29`
T126|x|`just rebase <PR>` (owner 2026-10-04: #8 conflicted only in README badges after #9): 1 cloud session rebases a `claude/*` PR onto `main`|I.cmd,`.:C29`,`nix:T127`
T129|x|`just review` (owner 2026-10-04): 6 roles to start, more to come; `all` = 1 session per role, 1 y/N naming count, model, roles \& per-session billing|I.cmd,`.:C29`,`docs:T130`
T132|x|`just fixup <PR>` (owner 2026-10-04): fix a PR's review findings 1 by 1 in separate commits, push, 👍 the originating comment; any branch but `main`|I.cmd,`.:C29`,`nix:T133`,`docs:T134`
T135|x|`just all <node:Tn>` (owner 2026-10-04): 1 command runs cloud → CI → review all → fixup → CI, waits for each, opens the PR in Safari|I.cmd,`.:C29`,`docs:T136`
T138|x|`just all` (owner 2026-10-05): 3 failed `gh` calls in a row in 1 wait → show gh's last stderr, name the step, open the PR if known, exit 1; a success resets the count|I.cmd,B32
T139|x|`just all <PR#\|URL>` (owner 2026-10-05): an existing PR (made by hand, e.g. a spec-only PR) gets the same CI → review all → fixup → CI → Safari steps, ⊥ build|I.cmd,`.:C29`,T135
T140|x|`cloud` \& `fixup` sessions watch CI after their push (owner 2026-10-05): red → read the failed log, fix in AGENTS order, gate, push again, ≤3 rounds, then report; cancelled ⊥ steps → report only; ⊥ weaken a check; `rebase` exempt: it resolves conflicts only \& pushes `--force-with-lease`, which the loop's ⊥ force forbids|I.cmd,`.:C29`
T141|x|`just all`: a cancelled check (a runner outage ∨ a superseded run) → "cancelled" ⊥ "failed", keeps waiting to the wait's limit, message names githubstatus.com \& ⊥ asserts a cause, said once per wait|I.cmd,B38,B37
T142|x|#19: CI-watch rules = 1 fragment `cloud-ci-watch-prompt.txt`, slot `@CI_WATCH@` in `cloud` \& `fixup`; logs = data; ⊥ edit CI-defining files; push `HEAD:<PR head>`; `fixup` replies first|I.cmd,V42,B36
T143|x|#19 `all`: red after the build \| fixup = pending (session fixes), ≤120 min; a PR's 1st CI strict|I.cmd,B35
T145|x|`just rebase` (owner 2026-10-06): any same-repo PR branch ≠ `main` (as `fixup`); mechanical conflicts resolved ⊥ abort: generated → rewrite, CHANGELOG \& table rows → keep both, a §id the PR shares w/ `main` → next free id over ∀ `SPEC*.md` + every cite of it, same commit; abort only when both sides mean opposite things; stops after the gate \& the push; CI is `all`'s wait (⊥ a 2nd watch, ⊥ a head that moves after the reviews start); the prompt names PR text, conflict hunks \& logs as data ⊥ instructions|I.cmd,`.:C29`,B40,`nix:T144`
T146|x|`just all`: PR `CONFLICTING` before the reviews \| the last CI → `rebase` (T145), wait for a new head within its own budget `minutes_rebase` (60, ⊥ the fixup's 180), go on; ⊥ new head → names the conflict, exit 1|I.cmd,T145
T148|x|`just spec-optimize` (owner 2026-10-06): brings spec nodes back under their ceilings, mechanics in `I.cmd`; ceilings raised repeatedly (`.context-limits`)|I.cmd,`.:C20`,`.:C29`,`docs:T149`
T156|x|`review` of any repo from its checkout (`<claudinix>/scripts/cloud-review.sh`): URL repo \& remote checked before `gh pr view` (B63); prompt reads AGENTS.md \& SPEC.md only if present, proves findings via the repo's own tooling when ⊥ flake dev shell; bats pins both|I.cmd,B21,B63,`docs:T157`
T158|x|`review` prompt: repo tooling (justfile, Makefile, package scripts) run only as it is on `origin/<base>`, ⊥ a script or target the PR adds \| changes, else a self-contained test in a scratch dir; a PR author ⊥ runs code in the session; bats pins it|I.cmd,T156
T159|x|`review` role files (`scripts/review/*.md`) ⊥ assume claudinix: each spec \| gate \| node rule reads "if the repository has …", as the prompt does; only `review` runs from a foreign checkout (`fixup`, `rebase`, `all` need AGENTS.md, SPEC.md \& the gate) said in CLI.md|I.cmd,T156,`docs:T157`
T160|x|`just merge`, `all --merge`, review `Findings: N`, C29 \& AGENTS, cloud deny `gh pr merge`|V51,I.cmd,`.:C29`
T161|x|`just drain`: serial `just all --merge` over a task list (I.cmd)|V51,I.cmd
T164|x|`fleet` review role `scripts/review/fleet.md`: find ∀ owner repo consuming the PR's repo (flake input, `uses: <owner>/<repo>/.github/workflows/…`, hook \| hk ref, `nix run …#app`, vendored copy) via `gh search code` \| local checkouts; per consumer: what the diff changes on its next pin bump (renamed \| removed output, option, default, workflow input, hook id), evidence = consumer file:line; ends `Findings: N`; `all` picks it up|I.cmd,V51
T165|x|cross-repo `fixup`: `just fixup <URL>` from the target repo's checkout, as `review` (T156); prompt follows the target's AGENTS.md, gate \& spec if present, ⊥ this repo's rules; a `fleet` finding → fixed in the PR (keep the old name \| a shim) \| named as a consumer change for the owner, ⊥ dropped|I.cmd,T164,`.:C29`
T166|x|`scripts/cloud-held.sh` selects PRs: open PRs labelled L across the owner's repos, oldest first; checkout lookup, skip naming it; hands each PR to the `all` flow (`cloud-all.sh <PR URL> --yes`, T139), ⊥ its own wait \| CI logic|I.cmd,V52,T161,V40,V41,T165,`.:C29`
