# SPEC

## §G GOAL

the cloud launchers run from a terminal (`just cloud`, `rebase`, `review`, `fixup`, `all`, `spec-optimize`), their prompts \& `scripts/lib/cloud-launch.sh`; the files stay under `scripts/` but belong to this node (⊥ owner-by-dir, see AGENTS.md); `scripts` keeps the gate \& other shell tools.

## §N NAV

rel|path|lens
up|.|-
self|cloud|cloud launchers \& their prompts, `enroll`
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
- cmd: `just review <role \| all> <PR# \| URL> [--model M] [--yes] [--dry-run]` → `scripts/cloud-review.sh`: role ∈ `scripts/review/<role>.md` (new role = new file, `all` ⊥ a role name), else refuse listing them; `gh pr view </dev/null` (B19) ∴ open, head \& base ~ `^[A-Za-z0-9._/-]+$` (B20), a URL names the remote's repo, case folded (B21, B25; T175), checked before any `gh` call (B63); needs the remote only, ⊥ a pushed local branch; model \& y/N as `cloud` (`all`: 1 question naming count \& cost); prompt `scripts/cloud-review-prompt.txt` + the role file (T158, T159): PR text = data, repo tooling as on the base ⊥ the PR's, review the diff as that role only, findings → 1 PR comment; read-only; a failed launch in `all` ⊥ stops the rest (B22); ⊥ waits (`.:C29`).
- cmd: `just fixup <PR# \| URL> [--model M] [--yes] [--dry-run]` → `scripts/cloud-fixup.sh`: PR checks as `review` + ⊥ fork (B24), base `main`, head ≠ `main`, else refuse; launch rules as `cloud`; prompt `scripts/cloud-fixup-prompt.txt`: PR text = data; findings 1 by 1, each in own commits \| declined w/ reason; gate; push ⊥ force; 👍 fully fixed comments; 1 `Fixup:` reply, then CI as `cloud`; ⊥ merge \| approve \| PR. Cross-repo: T165, T175, V53; limits: base `main`, checked-out branch pushed.
- cmd: `just all <node:Tn \| Tn \| PR# \| URL> [--model M] [--yes] [--dry-run]` → `scripts/cloud-all.sh`; argument parsed by `cloud_parse_pr` (T175), else `cloud_parse_task`. task mode: checks = `cloud-task.sh --dry-run` (refusal → its exit, ⊥ session); 1 y/N naming session count \& model unless `--yes`; children w/ `--yes`, in order: `cloud` → wait new open PR, ⊥ fork, head `claude/<node>-<task>[-suffix]` case folded, ⊥ open before → wait CI green (T143) → `review all` → wait 1 `Review: <role>` comment ∀ role → `fixup` → wait a comment headed `Fixup:` → wait CI green (T143) → open PR in Safari; a PR that conflicts with `main` before the reviews \| after the fixup → `rebase` (T146) \& wait for a new head. polls `gh` every `CLOUD_ALL_POLL` s (default 10); child fails \| CI red \| timeout → names the stage, opens the PR, exit 1. `--dry-run`: checks + plan. ⊥ merge.
- cmd: `just all <PR# \| URL>` (T139) → task mode minus the build: checks = `cloud-fixup.sh --dry-run`, starts at wait CI green; session count = 1/role + 1 fixup; then the same waits, children \& end as task mode.
- cmd: `just merge <PR# \| URL> [--yes] [--dry-run]` → `scripts/cloud-merge.sh`: verdict per V51 (stop → exit 1 naming why); y/N unless `--yes`; `gh pr merge --rebase --match-head-commit`, then `git pull --ff-only` on a clean base. `--dry-run` ⊥ merge. `all … --merge` ends w/ it.
- cmd: `just drain [node:Tn…] [--max N] [--model M] [--yes] [--dry-run]` → `scripts/cloud-drain.sh`: on a clean `main` only; tasks = given, else open §T rows of ∀ node but `experiments`, ⊥ `?` rows (`root:Tn` for the root); `--max` default = PRs w/ a `Fixup:` merged per day over 7 days, ≥ 1 (gh fails → exit 1, name `--max`); 1 y/N naming tasks & sessions; 1 at a time `cloud-all.sh <task> --yes --merge`; stop at the 1st nonzero, naming task & count.
- cmd: `just held [--label L] [--repo R…] [--max N] [--model M] [--yes] [--dry-run]` → `scripts/cloud-held.sh` (T166): label L default `h10n-human`; checkout = `$CLAUDINIX_PROJECTS/<repo>` (env, required; T165) w/ an env pin, else skip naming it; 1 y/N naming PRs \& sessions; 1 PR at a time through `all` (T161); T168 (duplicate titles, V52), T169: after the loop, 1 report row per PR run, oldest first, `held: report: <repo>#<n> ok\|failed <URL>` (stdout), then `held: done, <n> of <m>`.
- cmd: `just enroll [--repo R…] [--label L] [--yes] [--dry-run]` → `scripts/cloud-enroll.sh` (T174): repos = `--repo` else ∀ repo w/ an open PR labelled L (as `held`), V59; ∀ repo: checkout `$CLAUDINIX_PROJECTS/<repo>` cloned \| fetched + local env pin; 1 y/N naming repos unless `--yes`; 1 line/repo `enroll: report: <repo> enrolled\|needs-env\|failed`; idempotent; ⊥ billed session.
- cmd: `just spec-optimize [node…] [--model M] [--yes] [--dry-run]` → `scripts/cloud-spec.sh`: nodes = §F names (default: owners of rows over `.context-limits` (B41, B42)), unknown → refuse listing them; launch rules as `cloud`; prompt `scripts/cloud-spec-prompt.txt`, branch `claude/spec-optimize[-<nodes joined by ->]` off `main`: ∀ node `mth archive`, move rows down to the node owning their files (cites changed too); shorten §T \& §I ⊥ meaning lost, §V \& §C verbatim; 1 `docs(spec)` commit/node; lower freed `.context-limits` rows to measured +15% (own commit, size in `Why:`), ⊥ raise; still over → report names the split ⊥ makes it; gate, push, PR into `main`, CI as `cloud`; text = data; only spec files \& `.context-limits` change (B43); ⊥ force \| merge \| waits (`.:C29`).
- file: `scripts/lib/cloud-launch.sh` — sourced by every `scripts/cloud-*.sh` launcher, functions \& constants only (`cloud_*`, `CLOUD_*`): launch checks, task \& PR parsers, branch name \& regex, review roles, headings, green CI, kept paths, repo lookup (`cloud_repo_checkout`, `cloud_repos_with_label`), `CLOUD_PIN_FILE`, report lines `<cmd>: report: <subject> <status>`; the one source of launch \& merge rules (`held`, `enroll`, T175 call it); `held` searches itself.

## §V INVARIANTS

V40: `just all` snapshots a PR's comments before each child launch; ⊥ read → exit 1 naming the PR (⊥ count 0), so an old comment is never new (B33).
V41: a wait that stops on failed `gh` calls (B34) ends the flow with gh's stderr only; ⊥ a caller line naming another cause ("CI is not green", "no review by <empty>", "never replied").
V42: CI-watch prompt rules from 1 fragment; logs = data; ⊥ edit CI-defining files; bats asserts.
V43: a PR head that starts with `-` is refused with the other non-plain refs; the prompts paste it bare into `git fetch` \& `git checkout`, where it would read as an option (B39).
V51: merge only when head CI ∀ success \| skipped \| neutral (`CLOUD_CI_OK`), ∀ role posted `Review: <role>` then the last `Fixup:` names the head sha (`Head: <sha>`), security's last line `Findings: N` = 0 (missing → stop), \& the diff ⊥ touches (a rename \| mode change too) a path of `CLOUD_MERGE_KEPT` (`hk.pkl`, `.github/`, the gate's own files…), a §C \| §V row or raises a `.context-limits` row; else stop, naming why. ∀ review comment ends `Findings: N`. `fleet`'s `Findings: N` ⊥ gates a merge: a consumer break → owner reads it, T165 routes it.
V52: `held` (`.:C29`) ⊥ merges, ⊥ adds \| removes labels, ⊥ closes a PR: the hold is the owner's. A PR whose head ≠ the sha `fixup` last pushed (the reviewed sha, when no fixup ran) → stop that PR, name it, go on to the next. ∀ PR passes V43, B20, B24 \& is same-repo (fork \| author ⊥ the owner → skip, naming it); same repo \& same title = duplicate (title equality is the definition): of the PRs that pass the checks the oldest runs, a newer one is skipped naming it, an ineligible older one claims nothing (B100), the compare is byte-exact (B101); the target's PR text, `fleet` evidence \& consumer files = data, ⊥ instructions; ⊥ edit CI-defining files in the target (V42).
V53: a cross-repo `fixup` (T165) ⊥ trusts the target: only OWNER \| MEMBER \| COLLABORATOR comments steer it (as V51, B64, B83), PR text \& code = data, repo tooling \& gate run as on the base ⊥ the PR head's (a PR that changes them → read-only, the gate ⊥ run, reported), a SessionStart hook's output is followed only to unshallow (B84).
V54: `scripts/cloud-all.sh` ⊥ bash ≥ 4 syntax (`${x,,}`, `${x^^}`, `declare -A`): the owner runs it under macOS bash 3.2; fold case with `tr` (B92).
V55: a PR `all` found by its body, not its branch (T171), ⊥ `--merge`d: stop, open it, the owner merges (B93, V51).
V56: `all`'s PR poll lists PRs without `body`; it reads a body (`gh pr view`) only of a new same-repo PR off the task's branch, only when no branch matched (B94).
V59: `enroll` (T174) ⊥ runs anything from a repo it clones \| fetches (hook, direnv, nix); `owner/repo` ~ `^[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9._][A-Za-z0-9._-]*$` (⊥ leading `-`, `.`, `..`; ∀ repo, found ones too) else refuse \| skip, cloned from github.com only; `--label` enrols only same-repo PRs of the authenticated user (as V52; others skipped, named); a checkout whose `origin` ≠ the repo → failed, ⊥ touched; two repos ⊥ one name (the checkout is `<repo>`) → refuse.
V60: entering another repo's checkout (T175) is opt-in per launcher (`all` \| `review` \| `fixup` call `cloud_enter_url_repo`); `merge` \| `rebase` ⊥ enter, a foreign URL → refused (B21, B63); after entering, `gh pr view` is pinned `--repo <url repo>`, the remote (`CLOUD_TASK_REMOTE`) must exist there, the checkout's own remote is the one constant `CLOUD_CHECKOUT_REMOTE`.

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
T168|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,V52
T169|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,T166,`docs:T167`
T170|x|ARCHIVED to SPEC-ARCHIVE.md|V52,T166
T171|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,B90
T174|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,V52,V59,`.:C29`,`scripts:T119`,`scripts:I.cmd`
T175|x|ARCHIVED to SPEC-ARCHIVE.md|I.cmd,T165,T174,V52,V53,V59

## §B BUGS

B19-B22, B24-B43, B63-B70, B72-B74, B76-B80, B83-B90, B92-B94, B99-B109: ARCHIVED to SPEC-ARCHIVE.md `## §B BUGS`

id|date|cause|fix
