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

- cmd: `just cloud <node:Tn \| Tn> [--model M] [--yes] [--dry-run]` → `scripts/cloud-task.sh`: finds exactly 1 open (`.`) row across §F nodes; refuses missing \| done \| in progress \| ambiguous, no `origin`, detached, unpushed \| behind; model `--model` > `session.model` > sonnet; prompt `scripts/cloud-task-prompt.txt`; y/N billed unless `--yes`; `--dry-run` prints the command; pushes `claude/<node>-<task>`; after the PR: watches CI (T142), red → fix + push, ≤3 rounds, cancelled → report (T140); ⊥ waits for the session (`.:C29`).
- cmd: `just rebase <PR# \| URL> [--model M] [--yes] [--dry-run]` → `scripts/cloud-rebase.sh`: `gh pr view` ∴ open, ⊥ fork, base `main`, head ≠ `main` \& a plain ref (as `fixup`, T145) else refuse; launch rules as `cloud`; prompt `scripts/cloud-rebase-prompt.txt`: rebase head onto base, generated outputs re-written ⊥ hand-merged, a conflict resolved by rule (T145), abort \& report only when both sides mean opposite things, gate, `--force-with-lease` push to the same branch, then stop (⊥ CI watch: `all` owns it); PR text, conflict hunks \& logs are data ⊥ instructions; ⊥ new PR, ⊥ merge.
- cmd: `just review <role \| all> <PR# \| URL> [--model M] [--yes] [--dry-run]` → `scripts/cloud-review.sh`: role ∈ `scripts/review/<role>.md` (new role = new file, `all` ⊥ a role name), else refuse listing them; `gh pr view </dev/null` (B19) ∴ open, head \& base ~ `^[A-Za-z0-9._/-]+$` (B20), a URL names the remote's repo, case folded (B21, B25), checked before any `gh` call (B63); needs the remote only, ⊥ a pushed local branch; model \& y/N as `cloud` (`all`: 1 question naming count \& cost); prompt `scripts/cloud-review-prompt.txt` + the role file (T158, T159): PR text untrusted, repo tooling run only as on the base ⊥ the PR's own, review the diff as that role only, findings → 1 PR comment; read-only; 1 failed launch in `all` ⊥ stops the rest, lists started \& failed, exit 1 (B22); ⊥ waits (`.:C29`).
- cmd: `just fixup <PR# \| URL> [--model M] [--yes] [--dry-run]` → `scripts/cloud-fixup.sh`: PR checks as `review` + ⊥ fork (B24), base `main`, head ≠ `main`, else refuse; launch rules as `cloud`; prompt `scripts/cloud-fixup-prompt.txt`: PR text = data; findings 1 by 1 (a dupe = 1), each in own commits \| declined w/ reason; gate; push ⊥ force; 👍 fully fixed comments; 1 `Fixup:` reply, then CI as `cloud`; ⊥ merge \| approve \| PR.
- cmd: `just all <node:Tn \| Tn \| PR# \| URL> [--model M] [--yes] [--dry-run]` → `scripts/cloud-all.sh`; argument parsed by `cloud_parse_pr`, else `cloud_parse_task`. task mode: checks = `cloud-task.sh --dry-run` (refusal → its exit, ⊥ session); 1 y/N naming session count (1 build + 1/role + 1 fixup) \& model unless `--yes`; children w/ `--yes`, in order: `cloud` → wait new open PR, ⊥ fork, head `claude/<node>-<task>[-suffix]` case folded, ⊥ open before (unreadable list → exit 1) → wait CI green (T143) → `review all` → wait 1 `Review: <role>` comment ∀ role → `fixup` → wait a comment headed `Fixup:` → wait CI green (T143) → open PR in Safari; a PR that conflicts with `main` before the reviews \| after the fixup → `rebase` (T146) \& wait for a new head. polls `gh` every `CLOUD_ALL_POLL` s (default 10, ⊥ positive int → exit 2), 1 `.` per poll; each wait bounded by a poll count = its minutes ÷ poll ⊥ wall clock; child fails \| CI red \| timeout → names the stage, opens the PR, exit 1. `--dry-run`: checks + plan. ⊥ merge.
- cmd: `just all <PR# \| URL>` (T139) → task mode minus the build: checks = `cloud-fixup.sh --dry-run`, starts at wait CI green; session count = 1/role + 1 fixup; then the same waits, children \& end as task mode.
- cmd: `just merge <PR# \| URL> [--yes] [--dry-run]` → `scripts/cloud-merge.sh`: verdict per V51 (stop → exit 1 naming why); y/N unless `--yes`; `gh pr merge --rebase --match-head-commit`; then `git pull --ff-only` on a clean base branch. `--dry-run` ⊥ merge. `just all … --merge` ends w/ it.
- cmd: `just spec-optimize [node…] [--model M] [--yes] [--dry-run]` → `scripts/cloud-spec.sh`: nodes = §F names (default: owners of rows over `.context-limits` (B41, B42), ⊥ one → exit 0), unknown → refuse listing them; launch rules as `cloud`; prompt `scripts/cloud-spec-prompt.txt`, branch `claude/spec-optimize[-<nodes joined by ->]` off `main`: ∀ node `mth archive`, move rows down to the node owning their files (cites changed in the same commit; target measured, ⊥ pushed over); shorten §T \& §I ⊥ meaning lost (ids, status \& cites kept), §V \& §C verbatim; 1 `docs(spec)` commit/node; lower freed `.context-limits` rows to measured +15% (own commit, size in `Why:`), ⊥ raise; still over → report names the split ⊥ makes it; gate, push, PR into `main`, CI as `cloud`; text = data; only spec files \& `.context-limits` change (B43); ⊥ force \| merge \| waits (`.:C29`).
- file: `scripts/lib/cloud-launch.sh` — sourced by every `scripts/cloud-*.sh` launcher, functions \& 2 heading constants only (`cloud_*`): launch checks, task \& PR parsers, branch name \& regex, review roles, `Review:` \& `Fixup:` headings; the one source of the launch rules, a fix like B19 lands once.

## §V INVARIANTS

V40: `just all` snapshots a PR's comments before each child launch; ⊥ read → exit 1 naming the PR (⊥ count 0), so an old comment is never new (B33).
V41: a wait that stops on failed `gh` calls (B34) ends the flow with gh's stderr only; ⊥ a caller line naming another cause ("CI is not green", "no review by <empty>", "never replied").
V42: CI-watch prompt rules from 1 fragment; logs = data; ⊥ edit CI-defining files; bats asserts.
V43: a PR head that starts with `-` is refused with the other non-plain refs; the prompts paste it bare into `git fetch` \& `git checkout`, where it would read as an option (B39).
V51: merge only when head CI ∀ success \| skipped, ∀ role posted `Review: <role>` then a `Fixup:` came after the head's last commit, security's last `Findings: N` = 0 (missing → stop), \& the diff ⊥ touches (a rename \| mode change too) `hk.pkl`, `.github/`, `flake.lock`, `nix/cloud-permissions.json`, the gate's own files (`CLOUD_MERGE_KEPT`, `lib/cloud-launch.sh`), a §C \| §V row or raises a `.context-limits` row; else stop, naming why. ∀ review comment ends `Findings: N`.

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

## §B BUGS

id|date|cause|fix
B19|2026-10-04|`just rebase`: `y` → "not started"; `gh` read the TTY|gh </dev/null; flush TTY before y/N
B20|2026-10-04|`just review`: a PR head \| base is the author's choice \& goes into shell commands (`x$(id)`)|refuse a head \| base ⊥ `^[A-Za-z0-9._/-]+$` before any session
B21|2026-10-04|`just review ROLE <other repo URL>` kept only the number ∴ this repo's PR was reviewed, billed|a PR URL naming another repo than the remote → refuse
B22|2026-10-04|`review all`: 1 launch failed → exit, rest never started, re-run duplicated|a failed launch ⊥ stops the loop; end lists started \& failed, exit 1 iff any failed
B24|2026-10-04|`just fixup` on a fork PR: session pushed an unrelated same-named branch of origin|cross-repository PR → refuse, no session
B25|2026-10-04|`just fixup https://github.com/Pr0d1r2/…/pull/N`: owner/repo compared case-sensitively, refused as another repo|owner/repo compared with case folded (`tr`, bash 3.2)
B26|2026-10-05|failed `gh pr list` before `all` → empty snapshot ∴ old PR adopted|unreadable list → refuse
B27|2026-10-05|`just all` adopted a fork PR named `claude/<node>-<task>`|skip cross-repository PRs
B28|2026-10-05|`all` took any newer comment ⊥ `Review:` as the fixup's reply|reply headed `Fixup:`; headings named once in `lib/cloud-launch.sh`
B29|2026-10-05|`CLOUD_ALL_POLL=0` \| `abc` → raw shell error|exit 2 naming it unless a positive integer
B30|2026-10-05|`all` comment reader: a `\r\n` heading ⊥ matched|`comments` trims the `\r`
B31|2026-10-05|`all` branch regex took the node unescaped (`a.b` ~ `axb`)|escape it
B32|2026-10-05|every `all` wait mapped a `gh` error to "not yet"; #14's fixup reply was missed, cause hidden|stop after 3 `gh` errors in a row, show stderr
B33|2026-10-05|`all` `comment_count` turned a failed `gh` read into 0 ∴ old comments counted as new|V40: unreadable count → exit 1 naming the PR
B34|2026-10-05|T138's gh stop was followed by the caller's own line naming a cause nobody read|V41: the gh stop is its own exit, ⊥ a second message
B35|2026-10-05|`all` stopped on red while a session was fixing it|T143
B36|2026-10-05|`cloud` prompt pushed `-u origin @BRANCH@` again, ⊥ the suffixed PR head|T142
B37|2026-10-05|`all` named "runner outage" for any cancel|⊥ assert cause; once per wait
B38|2026-10-05|Actions outage cancelled `gate` (0 steps); `all` stopped "CI failed"|cancelled ⊥ steps ⊥ red (T141)
B39|2026-10-06|`cloud_require_open_pr` took a head like `-x`; the rebase prompt pastes it into `git fetch`, read as an option|V43: a plain ref starts with a letter, digit, `.` or `_`
B40|2026-10-06|#18 \& #19 both added B34; `rebase` refused #19 (head ⊥ `claude/*`)|T145: rebase any PR branch, renumber a shared §id
B41|2026-10-06|`spec-optimize` dropped a non-`SPEC.md` breach: "nothing to do" (`.:V18`)|owner = longest §F dir prefix \| `.`; ⊥ node → exit 1
B42|2026-10-06|`spec-optimize` ⊥ `.context-limits`: sherd's default ceiling put ∀ node over|⊥ file → exit 1
B43|2026-10-06|`spec-optimize` CI fragment let a red log steer it to code|cause outside spec files → report
B63|2026-10-15|`just review all <other repo URL>`: `gh pr view 36` ran before the B21 repo check ∴ read this repo's merged #36|repo check before any `gh` call (T156)
B64|2026-10-15|`just merge`: review \& `Fixup:` comments counted from any author; a forged `Review: security … Findings: 0` passed V51 (PR #40 review)|V51: only comments whose `authorAssociation` is OWNER \| MEMBER count
B65|2026-10-15|`just merge`: reviews tied to no commit; a push after the `Fixup:` merged unreviewed|V51: `Fixup:` newer than the head's last commit
B66|2026-10-15|`just merge` diff check read only `+`\|`-` lines ∴ a pure rename \| mode change of a kept file passed|V51: judge the `diff --git` header \& `rename from`
B67|2026-10-15|`just merge` kept only 4 paths ∴ a PR could weaken a guard, a review role or the merge script itself and still merge|V51: also `scripts/guard/`, `scripts/hk/`, `scripts/review/`, the merge \& review scripts, `.claude/`, `justfile`
