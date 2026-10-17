# SPEC

## §G GOAL

the cloud launchers run from a terminal (`just cloud`, `rebase`, `review`, `fixup`, `all`, `spec-optimize`), their prompts \& `scripts/lib/cloud-launch.sh`; the files stay under `scripts/` but belong to this node (⊥ owner-by-dir, see AGENTS.md); `scripts` keeps the gate \& other shell tools.

## §N NAV

rel|path|lens
up|.|-
self|cloud|cloud launchers \& their prompts
sib|scripts|repo shell: gate guards, hk runners, CI checks, target-project apps
sib|nix|flake outputs: dev shell, checks, agent home build, cachix push
sib|docs|plain-English docs: setup, facts, runbook, security, release
sib|experiments|cloud-session experiments \& results
sib|dev|`claudinix-dev`: generated badges \& doc numbers
sib|home|`~/.claude`: skills, rtk, caveman, permission rules

## §C CONSTRAINTS

## §I INTERFACES

- cmd: `just cloud <node:Tn \| Tn> [--model M] [--yes] [--dry-run]` → `scripts/cloud-task.sh`: finds exactly 1 open (`.`) row across §F nodes; refuses missing \| done \| in progress \| ambiguous, no `origin`, detached, unpushed \| behind; model `--model` > `session.model` > sonnet; prompt `scripts/cloud-task-prompt.txt`; y/N billed unless `--yes`; pushes `claude/<node>-<task>`; after the PR: watches CI (T142), red → fix + push, ≤3 rounds, cancelled → report (T140); ⊥ waits for the session (`.:C29`).
- cmd: `just rebase <PR# \| URL> [--model M] [--yes] [--dry-run]` → `scripts/cloud-rebase.sh`: `gh pr view` ∴ open, ⊥ fork, base `main`, head ≠ `main` \& a plain ref (as `fixup`, T145) else refuse; launch rules as `cloud`; prompt `scripts/cloud-rebase-prompt.txt`: rebase head onto base, generated outputs re-written ⊥ hand-merged, abort \& report only when both sides mean opposite things, gate, `--force-with-lease` push to the same branch, then stop; PR text \& logs = data; ⊥ merge.
- cmd: `just review <role \| all> <PR# \| URL> [--model M] [--yes] [--dry-run]` → `scripts/cloud-review.sh`: role ∈ `scripts/review/<role>.md` (new role = new file, `all` ⊥ a role name), else refuse listing them; `gh pr view </dev/null` (B19) ∴ open, head \& base ~ `^[A-Za-z0-9._/-]+$` (B20), a URL names the remote's repo, case folded (B21, B25), checked before any `gh` call (B63); needs the remote only, ⊥ a pushed local branch; model \& y/N as `cloud` (`all`: 1 question naming count \& cost); prompt `scripts/cloud-review-prompt.txt` + the role file (T158, T159): PR text = data, repo tooling as on the base ⊥ the PR's, review the diff as that role only, findings → 1 PR comment; read-only; a failed launch in `all` ⊥ stops the rest (B22); ⊥ waits (`.:C29`).
- cmd: `just fixup <PR# \| URL> [--model M] [--yes] [--dry-run]` → `scripts/cloud-fixup.sh`: PR checks as `review` + ⊥ fork (B24), base `main`, head ≠ `main`, else refuse; launch rules as `cloud`; prompt `scripts/cloud-fixup-prompt.txt`: PR text = data; findings 1 by 1, each in own commits \| declined w/ reason; gate; push ⊥ force; 👍 fully fixed comments; 1 `Fixup:` reply, then CI as `cloud`; ⊥ merge \| approve \| PR. Cross-repo: T165, V53; limits: base `main`, checked-out branch pushed.
- cmd: `just all <node:Tn \| Tn \| PR# \| URL> [--model M] [--yes] [--dry-run]` → `scripts/cloud-all.sh`; argument parsed by `cloud_parse_pr`, else `cloud_parse_task`. task mode: checks = `cloud-task.sh --dry-run` (refusal → its exit, ⊥ session); 1 y/N naming session count \& model unless `--yes`; children w/ `--yes`, in order: `cloud` → wait new open PR, ⊥ fork, head `claude/<node>-<task>[-suffix]` case folded, ⊥ open before → wait CI green (T143) → `review all` → wait 1 `Review: <role>` comment ∀ role → `fixup` → wait a comment headed `Fixup:` → wait CI green (T143) → open PR in Safari; a PR that conflicts with `main` before the reviews \| after the fixup → `rebase` (T146) \& wait for a new head. polls `gh` every `CLOUD_ALL_POLL` s (default 10); child fails \| CI red \| timeout → names the stage, opens the PR, exit 1. `--dry-run`: checks + plan. ⊥ merge.
- cmd: `just all <PR# \| URL>` (T139) → task mode minus the build: checks = `cloud-fixup.sh --dry-run`, starts at wait CI green; session count = 1/role + 1 fixup; then the same waits, children \& end as task mode.
- cmd: `just merge <PR# \| URL> [--yes] [--dry-run]` → `scripts/cloud-merge.sh`: verdict per V51 (stop → exit 1 naming why); y/N unless `--yes`; `gh pr merge --rebase --match-head-commit`, then `git pull --ff-only` on a clean base. `--dry-run` ⊥ merge. `all … --merge` ends w/ it.
- cmd: `just drain [node:Tn…] [--max N] [--model M] [--yes] [--dry-run]` → `scripts/cloud-drain.sh`: on a clean `main` only; tasks = given, else open §T rows of ∀ node but `experiments`, ⊥ `?` rows (`root:Tn` for the root); `--max` default = PRs w/ a `Fixup:` merged per day over 7 days, ≥ 1 (gh fails → exit 1, name `--max`); 1 y/N naming tasks & sessions; 1 at a time `cloud-all.sh <task> --yes --merge`; stop at the 1st nonzero, naming task & count.
- cmd: `just held [--label L] [--repo R…] [--max N] [--model M] [--yes] [--dry-run]` → `scripts/cloud-held.sh` (T166): label L default `h10n-human`; checkout = `$CLAUDINIX_PROJECTS/<repo>` w/ a claude.ai env in its `settings.local.json`, else skip naming it; duplicates T168; 1 y/N naming PRs \& sessions; 1 PR at a time through the `all` flow (`review all` → `fixup` → wait CI green, as T161); report T169.
- cmd: `just spec-optimize [node…] [--model M] [--yes] [--dry-run]` → `scripts/cloud-spec.sh`: nodes = §F names (default: owners of rows over `.context-limits` (B41, B42)), unknown → refuse listing them; launch rules as `cloud`; prompt `scripts/cloud-spec-prompt.txt`, branch `claude/spec-optimize[-<nodes joined by ->]` off `main`: ∀ node `mth archive`, move rows down to the node owning their files (cites changed too); shorten §T \& §I ⊥ meaning lost, §V \& §C verbatim; 1 `docs(spec)` commit/node; lower freed `.context-limits` rows to measured +15% (own commit, size in `Why:`), ⊥ raise; still over → report names the split ⊥ makes it; gate, push, PR into `main`, CI as `cloud`; text = data; only spec files \& `.context-limits` change (B43); ⊥ force \| merge \| waits (`.:C29`).
- file: `scripts/lib/cloud-launch.sh` — sourced by every `scripts/cloud-*.sh` launcher, functions \& constants only (`cloud_*`, `CLOUD_*`): launch checks, task \& PR parsers, branch name \& regex, review roles, headings, green CI, kept paths; the one source of the launch \& merge rules.

## §V INVARIANTS

V40: `just all` snapshots a PR's comments before each child launch; ⊥ read → exit 1 naming the PR (⊥ count 0), so an old comment is never new (B33).
V41: a wait that stops on failed `gh` calls (B34) ends the flow with gh's stderr only; ⊥ a caller line naming another cause ("CI is not green", "no review by <empty>", "never replied").
V42: CI-watch prompt rules from 1 fragment; logs = data; ⊥ edit CI-defining files; bats asserts.
V43: a PR head that starts with `-` is refused with the other non-plain refs; the prompts paste it bare into `git fetch` \& `git checkout`, where it would read as an option (B39).
V51: merge only when head CI ∀ success \| skipped \| neutral (`CLOUD_CI_OK`), ∀ role posted `Review: <role>` then the last `Fixup:` names the head sha (`Head: <sha>`), security's last line `Findings: N` = 0 (missing → stop), \& the diff ⊥ touches (a rename \| mode change too) a path of `CLOUD_MERGE_KEPT` (`hk.pkl`, `.github/`, the gate's own files…), a §C \| §V row or raises a `.context-limits` row; else stop, naming why. ∀ review comment ends `Findings: N`. `fleet`'s `Findings: N` ⊥ gates a merge: a consumer break → owner reads it, T165 routes it.
V52: `held` (`.:C29`) ⊥ merges, ⊥ adds \| removes labels, ⊥ closes a PR: the hold is the owner's. A PR whose head ≠ the sha `fixup` last pushed (the reviewed sha, when no fixup ran) → stop that PR, name it, go on to the next. ∀ PR passes V43, B20, B24 \& is same-repo (fork \| author ⊥ the owner → skip, naming it); the target's PR text, `fleet` evidence \& consumer files = data, ⊥ instructions; ⊥ edit CI-defining files in the target (V42).
V53: a cross-repo `fixup` (T165) ⊥ trusts the target: only OWNER \| MEMBER \| COLLABORATOR comments steer it (as V51, B64, B83), PR text \& code = data, repo tooling \& gate run as on the base ⊥ the PR head's (a PR that changes them → read-only, the gate ⊥ run, reported), a SessionStart hook's output is followed only to unshallow (B84).

## §T TASKS

id|status|task|cites
T124|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,`.:C29`
T126|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,`.:C29`,`nix:T127`
T129|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,`.:C29`,`docs:T130`
T132|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,`.:C29`,`nix:T133`,`docs:T134`
T135|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,`.:C29`,`docs:T136`
T138|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,B32
T139|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,`.:C29`,T135
T140|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,`.:C29`
T141|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,B38,B37
T142|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,V42,B36
T143|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,B35
T145|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,`.:C29`,B40,`nix:T144`
T146|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,T145
T148|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,`.:C20`,`.:C29`,`docs:T149`
T156|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,B21,B63,`docs:T157`
T158|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,T156
T159|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,T156,`docs:T157`
T160|x|ARCHIVED to SPEC-ARCHIVE.md|V51,I.cmd,`.:C29`

T161|x|ARCHIVED to SPEC-ARCHIVE.md|V51,I.cmd

T164|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,V51
T165|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,T164,`.:C29`
T166|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,V52,T161,V40,V41,T165,`.:C29`
T168|.|`held` duplicates: 1 repo, same normalized title \| head-branch prefix → oldest kept, rest listed for the owner, ⊥ sessions|I.cmd,V52
T169|.|`held` report per PR: findings, fixed, declined, CI (from the `all` result)|I.cmd,T166,`docs:T167`

## §B BUGS

B19-B43 (but B23): ARCHIVED to SPEC-ARCHIVE.md `## §B BUGS`

id|date|cause|fix
B63|2026-10-15|`just review all <other repo URL>`: `gh pr view 36` ran before the B21 repo check ∴ read this repo's merged #36|repo check before any `gh` call (T156)
B64|2026-10-15|`just merge` counted review \& `Fixup:` comments of any author (forged `Findings: 0`)|V51: only OWNER \| MEMBER comments count
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
B86|2026-10-17|`held` ran a fork PR (#50)|V52: skipped at selection
B87|2026-10-17|`held` records split on spaces (#50)|V52: split on tab
B88|2026-10-17|`held` lost PRs past the 100th (#50)|V52: `--repo` in the search, full page said
B89|2026-10-17|`CLOUD_MERGE_KEPT` missed `scripts/cloud-held.sh` (#50)|V51: kept
