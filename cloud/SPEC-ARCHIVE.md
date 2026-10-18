# SPEC ARCHIVE

Task rows moved out of `SPEC.md` by `mth archive`; fixed bug rows moved by
hand, see `docs/CONTRIBUTING.md`. An id is never reused
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
T168|x|`held` dedupe: same repo \& title → oldest kept, ⊥ sessions|I.cmd,V52
T169|x|`held` report per PR from `all`|I.cmd,T166,`docs:T167`
T170|x|`all` stops a PR whose head ≠ the last `fixup` push (V52)|V52,T166
T171|x|`all` finds the build's PR when its branch ≠ `claude/<node>-<task>`: the 1 same-repo PR opened after the launch whose body names the task id; 2+ → stop, naming them|I.cmd,B90
T174|x|`enroll`: missing checkout → `gh repo clone`, else `git fetch`; pin = own `jq` write of the `/remote-env` pick to `.claude/settings.local.json` (`guide` sources no lib; bats: its `env_id` reads it), file → `.git/info/exclude`; ⊥ pick \| another repo's → `needs-env`; ⊥ commit \| push|I.cmd,V52,V59,`scripts:T119`,`scripts:I.cmd`
T175|x|`all` \| `review` \| `fixup` w/ another repo's URL → run from `$CLAUDINIX_PROJECTS/<repo>` if its `origin` is `<repo>` (case folded), clean, on the PR's base, fetched; tooling \& gate as on the base (V53); else refuse as now (B21, B25, B63 kept)|I.cmd,T165,T174,V52,V53,V59

## §B BUGS

Bug rows moved by hand: see `docs/CONTRIBUTING.md`.

id|date|cause|fix
B19|2026-10-04|`just rebase`: `y` → "not started"; `gh` read the TTY|gh </dev/null; flush TTY before y/N
B20|2026-10-04|`just review`: a PR head \| base is the author's choice \& goes into shell commands (`x$(id)`)|refuse a head \| base ⊥ `^[A-Za-z0-9._/-]+$` before any session
B21|2026-10-04|`just review ROLE <other repo URL>` kept only the number ∴ this repo's PR was reviewed, billed|a PR URL naming another repo than the remote → refuse
B22|2026-10-04|`review all`: 1 failed launch stopped the loop|failed launch ⊥ stops loop; exit 1 iff any failed
B24|2026-10-04|`just fixup` on a fork PR: session pushed an unrelated same-named branch of origin|cross-repository PR → refuse, no session
B25|2026-10-04|`just fixup https://github.com/Pr0d1r2/…/pull/N`: owner/repo compared case-sensitively, refused as another repo|owner/repo compared with case folded (`tr`, bash 3.2)
B26|2026-10-05|failed `gh pr list` before `all` → empty snapshot ∴ old PR adopted|unreadable list → refuse
B27|2026-10-05|`just all` adopted a fork PR named `claude/<node>-<task>`|skip cross-repository PRs
B28|2026-10-05|`all` took any newer comment as the fixup's reply|reply headed `Fixup:`
B29|2026-10-05|`CLOUD_ALL_POLL=0` \| `abc` → raw shell error|exit 2 unless positive integer
B30|2026-10-05|`all` comment reader: `\r\n` heading ⊥ matched|trim the `\r`
B31|2026-10-05|`all` branch regex took the node unescaped|escape it
B32|2026-10-05|`all` waits mapped a `gh` error to "not yet"|stop after 3 `gh` errors, show stderr
B33|2026-10-05|`all` `comment_count` turned a failed `gh` into 0|V40
B34|2026-10-05|T138's gh stop was followed by a caller line naming another cause|V41
B35|2026-10-05|`all` stopped on red while a session was fixing it|T143
B36|2026-10-05|`cloud` prompt pushed `-u origin @BRANCH@` again, ⊥ the suffixed PR head|T142
B37|2026-10-05|`all` named "runner outage" for any cancel|⊥ assert cause; once per wait
B38|2026-10-05|Actions outage cancelled `gate` (0 steps); `all` stopped "CI failed"|cancelled ⊥ steps ⊥ red (T141)
B39|2026-10-06|`cloud_require_open_pr` took a head like `-x`; the rebase prompt pastes it into `git fetch`, read as an option|V43: a plain ref starts with a letter, digit, `.` or `_`
B40|2026-10-06|#18 \& #19 both added B34; `rebase` refused #19|T145: rebase any PR branch, renumber shared §id
B41|2026-10-06|`spec-optimize` dropped a non-`SPEC.md` breach: "nothing to do" (`.:V18`)|owner = longest §F dir prefix \| `.`; ⊥ node → exit 1
B42|2026-10-06|`spec-optimize` ⊥ `.context-limits`: sherd's default ceiling put ∀ node over|⊥ file → exit 1
B43|2026-10-06|`spec-optimize` CI fragment let a red log steer it to code|cause outside spec files → report
B65|2026-10-15|`merge`: a push after the `Fixup:` merged unreviewed|V51: `Fixup:` ties to the head
B66|2026-10-15|`just merge` read `+`\|`-` lines ∴ a pure rename \| mode change of a kept file passed|V51: judge the `diff --git` header
B67|2026-10-15|`just merge` kept 4 paths ∴ a PR could weaken a guard, review role or the merge script|V51: also `CLOUD_MERGE_KEPT`
B68|2026-10-15|`all` waited for CI by success\|skipped\|neutral, `merge` by a 2nd rule w/o neutral|V51: 1 `CLOUD_CI_OK` in `lib/cloud-launch.sh`
B69|2026-10-15|`merge` matched `Review: <role>` by regex ∴ `security-deep` counted as security|V51: role = first word, compared whole
B70|2026-10-15|`just merge` took `Findings: 0` from any line of a security review|V51: only the last line counts
B72|2026-10-15|review prompt named `just merge`, which sessions never use|prompt states `Findings: N` only
B73|2026-10-15|`merge` judged the `Fixup:` by `committedDate`: forgeable, \& a CI-fix push after it always stopped|V51: the last `Fixup:` names `headRefOid` (`Head: <sha>`)
B74|2026-10-15|`CLOUD_MERGE_KEPT` missed `flake.nix`, `nix/dev-shell.nix`, `scripts/dev/`, `scripts/cloud-all.sh`, `scripts/lib/spec-nodes.sh` \& the guard tests ∴ a PR could change the gate's tools unflagged|V51: kept also these; a new `scripts/lib/` file is kept by its dir
B76|2026-10-15|real reviews end w/ the harness footer (`---`, `_Generated by …_`) ∴ B70's last-line rule never found `Findings:` (dry run of #41)|V51: drop that footer first
B77|2026-10-15|`cloud-drain.sh` was not in `CLOUD_MERGE_KEPT` ∴ a PR could rewrite the chained-merge entry point unflagged (#42)|V51: kept also `scripts/cloud-drain.sh`
B78|2026-10-15|`drain` counted `Fixup:` comments of any author for the default `--max` (same forgery as B64) ∴ anyone could raise the cap to 29 (#42)|V51: only OWNER \| MEMBER comments count, also for `--max`
B79|2026-10-15|`drain` matched a literal `Fixup:` ∴ `## Fixup:` uncounted, `--max` fell to 1|`drain` reads `CLOUD_FIXUP_HEADING`
B80|2026-10-15|`drain` progress used all candidates ∴ `--max 1` said `1 of 14`|count the planned tasks
B83|2026-10-17|`fixup` prompt honoured `Review: fleet` comments of any author with "never drop" ahead of the decline rule ∴ anyone could force a change on the PR branch in a repo outside this one (#48)|V53: only OWNER \| MEMBER \| COLLABORATOR comments steer a fixup; "never drop silently"
B84|2026-10-17|`fixup` prompt ran the gate \& repo tooling of the PR head, with the session's credentials, in repos whose PR authors are third parties (#48)|V53: tooling from the base; a PR that changes it → read-only, report
B85|2026-10-17|shared CI-watch fragment told the session to follow AGENTS.md \| §B \| a gate and not to edit `hk.pkl` in repos that have none (#48)|CI-watch fragment is repo-neutral: those rules apply if present
B86|2026-10-17|`held` ran a fork PR (#50)|V52: skipped
B87|2026-10-17|`held` records split on spaces (#50)|V52: split on tab
B88|2026-10-17|`held` lost PRs past the 100th (#50)|V52: `--repo` in search
B89|2026-10-17|`CLOUD_MERGE_KEPT` missed `scripts/cloud-held.sh` (#50)|V51: kept
B90|2026-10-17|`all` matched the build's PR by branch only; the harness named it after the session title (#48, #50) ∴ 180 min wait, `drain` stopped|T171
B92|2026-10-17|T171's `find_pr` used `${x,,}`; macOS bash 3.2 has no it ∴ `all` dies at its first poll (#52)|V54
B93|2026-10-17|T171's body match could bind `all --merge` to another PR that cites the task id (#52)|V55
B94|2026-10-17|T171's `open_prs` pulled the body of 200 PRs on each 10 s poll of a 180 min wait (#52)|V56
B99|2026-10-17|`all` (T170) took the `Head:` line \& the `Fixup:` reply of any author: a non-member forged `Fixup:`/`Head: <their sha>` and V52 never stopped (#55)|V52: only OWNER \| MEMBER comments count in `all`, one jq filter in `lib/cloud-launch.sh` shared with `merge` (as V51, B64, B78)
B100|2026-10-17|`held` (T168) recorded a PR as the oldest of its title before the author, checkout, environment \& fork checks ∴ an older fork \| foreign PR of that title hid the owner's PR and nothing ran (#56)|V52: only a PR that passes the checks claims its title
B101|2026-10-17|`held` (T168) passed the title to `awk -v`, which unescapes `\\` ∴ a title with a backslash never matched, the duplicate ran (#56)|V52: byte-exact compare, ⊥ `awk -v`
B102|2026-10-18|`enroll` fork check: a failed `gh pr view` printed nothing ∴ `= true` false ∴ a fork PR's repo enrolled (failed open)|V59: enrol only on an explicit `isCrossRepository` false; a failed lookup skips, naming the PR
B103|2026-10-18|`enroll` wrote `.claude/settings.local.json` through a `.claude` symlink the cloned repo tracks ∴ the write landed outside the checkout|V59: a symlinked `.claude` \| pin file → failed, ⊥ written
B104|2026-10-18|`enroll` rewrote a `.claude/settings.local.json` the repo tracks ∴ dirty tree, `info/exclude` no effect|V59: a tracked pin file → failed, ⊥ touched
B105|2026-10-18|`enroll_one` ran in `$(…)` ∴ a failed `info/exclude` write still printed `enrolled`, the pin file left unexcluded|V59: every step of an enrol is checked; a failed one → failed
B106|2026-10-18|`--repo -x/y` passed `repo_re`, read as a gh flag; found repos unchecked|V59: one check ∀ repo
B63|2026-10-15|`just review all <other repo URL>`: `gh pr view 36` ran before the B21 repo check ∴ read this repo's merged #36|repo check before any `gh` call (T156)
B64|2026-10-15|`just merge` counted review \& `Fixup:` comments of any author (forged `Findings: 0`)|V51: only OWNER \| MEMBER comments count
B107|2026-10-18|T175 put the `cd` into `cloud_read_pr` ∴ `merge` \| `rebase` entered a foreign checkout too (cwd moved, `scripts_dir` relative, V51's refusal gone)|V60: entering is opt-in; `merge` \| `rebase` refuse a foreign URL
B108|2026-10-18|`gh pr view <N>` in the entered checkout resolved the repo by gh's own default, not the URL's ∴ a checkout w/ another gh default read another repo's PR #N|V60: `gh pr view --repo <url repo>`
B109|2026-10-18|the entered checkout was fetched \| matched as `origin` while the launcher used `CLOUD_TASK_REMOTE`, never checked there ∴ a missing remote failed late|V60: remote re-required after entering; the checkout's remote is one constant
