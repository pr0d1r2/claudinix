# SPEC ARCHIVE

Task rows moved out of `SPEC.md` by `mth archive`. An id is never reused
(`V12`), so a citation to an archived row still resolves -- here.

This is a SINK, not a spec. The citations inside these rows point into
`SPEC.md`, so `mth check` on this file reports every one of them as dangling,
correctly and uselessly. The verb that reads it is `mth tasks`.

## §T TASKS

T6|x|target-repo CI snippet (doc only, targets adopt via own spec): on push to default branch `nix flake archive --json` + devShell closure → `cachix push pr0d1r2`; push token in CI secrets only, ⊥ VM; delivered as `docs/CACHE-CI.md`|`.:V8`,`.:V6`,C5,C6,C3
T8|x|`docs/CONSUMER.md` + SessionStart hook snippet for target repos (doc only, targets adopt via own spec): `github:` inputs not in cachix → `git+https://github.com/<o>/<r>?ref=main&shallow=1` (sherd #96); tools that read 3rd-party GitHub (zizmor online audit) → in cloud (`CLAUDE_CODE_REMOTE=true`) unset `GH_TOKEN`/`GITHUB_TOKEN` (placeholder `proxy-injected` ⇒ 401) \| offline, report "could not run" ⊥ "finding"; hook: `git fetch --unshallow` (tdd-order needs history), `nix develop -c hk install`; commit author in cloud = `Claude <noreply@anthropic.com>` + `Claude-Session:` trailer ∴ commit-msg hooks must accept it; branch names get random suffix|C3,`.:V7`,C9,C8
T9|x|`LICENSE` (MIT), `README.md` (what, paste steps, fork block C11, known limits); `.:V12` scan of tree \& history before 1st push|C10,C11,`.:V12`
T13|x|`docs/SETUP.md` for zero-knowledge user: money steps first (claim credit, usage credits OFF — before ∀ cloud session), then browser steps (selector → Add cloud environment → name, Network access Custom + default list + `allowlist.txt`, env vars from `env-names.txt`, Setup script = `setup.sh`), update flow, then terminal `/remote-env` \| `remote.defaultEnvironmentId`; prereqs, GitHub connect (App, select repos), first-session check, troubleshooting, cleanup|C2,`.:V10`,I.ext.env
T31|x|W1 MUST `AGENTS.md`: for AI agents working here (incl. cloud sessions): spec first, gate, atomic commits, RED/GREEN/REFACTOR, model default; model sherd/itok `AGENTS.md`|C22,C17,C21
T32|x|W1 MUST `docs/INTEGRATION.md`: every hk step, how to run each by hand, parallelism, "hk.pkl wins"; model itok/xenolith `INTEGRATION.md`|C22,C14,C18
T33|x|W1 MUST `docs/LLM-DISCLAIMER.md`: built by Claude in the open; what to check before trusting a root-run setup script; model sherd|C22,C10
T34|x|W2 MUST `docs/FACTS.md`: dated cloud VM facts per probe (user, image Nix, proxy 403s, git vs tarball, branch suffix, commit author, shallow clone, allowlist only for new sessions); stale assumption = visible by date|C22,C8,C13
T35|x|W2 MUST `docs/RUNBOOK.md`: each procedure marked automated\|human: bump Nix pin, rotate SHA in UI, refill cachix, red probe, emergency stop of cloud spend, probe branch cleanup; model nix-hk `RUNBOOK.md`|C22,`.:V20`,`.:V11`,C19
T36|x|W2 MUST `docs/SECURITY.md`: private reporting path + threat model (root setup script, cache trust, `accept-flake-config` (`.:V25`: any cloned repo's `nixConfig` applies), GitHub proxy, ⊥ secrets in env vars); model sherd|C22,`.:V6`,C5
T37|x|W2 MUST `CHANGELOG.md`: per release \& per UI-pinned SHA what changed, so users know before bumping the setup line|C22,`.:V20`
T38|x|W1 SHOULD `docs/linter-coverage.md`: file type → linter table (`.sh`, `.nix`, `.bats`, `.pkl`, `.yml`, `.md`, `.toml`); model nixos-poe2|C22,C15,C16
T39|x|W3 SHOULD `docs/CONTRIBUTING.md`: run `hk check`, TDD order, commit format; model owner repos|C22,C17,C21
T40|x|W3 SHOULD `docs/CODE_OF_CONDUCT.md`: same text as owner repos|C22
T41|x|W3 SHOULD `docs/THIRD-PARTY-NOTICES.md`: Nix installer, nix-hk, xenolith, set-and-setting, cavekit (MIT)|C22,`nix:C12`
T42|x|W3 SHOULD `docs/MODEL.md`: why probe/launcher default to Sonnet 5.5, dated prices, when to change; generalized from the owner's private consumer repo|C22,I.cmd
T43|x|W3 SHOULD `docs/EXAMPLE.md`: sherd from zero to green `cargo test` in cloud w/ real timings (devShell 34 s, tests 12.5 s, gate 2m45s); model rekall/pklith `EXAMPLE.md`|C22,C8
T44|x|W4 SHOULD `docs/CLI.md`: `domains`, `inputs`, `guide`, `probe` flags, exit codes, output; model pklith `CLI.md`|C22,I.cmd
T45|x|W4 SHOULD `docs/SESSION.md`: session lifecycle `claude --cloud` → VM → clone → setup script \| snapshot → SessionStart → Claude; why edits ⊥ reach running session; model nixos-poe2 `usage.md` boot flow|C22,C1,C8
T46|x|W4 SHOULD `docs/FORKING.md`: own cachix, domains, env name (C11 block); model nixos-poe2 `development.md`|C22,C11
T70|x|`docs/SETUP.md`: setup script = exact 1-line output of `scripts/setup-line.sh` (⊥ paste whole `setup.sh`); allowed domains = base `allowlist.txt` + `nix run …#domains` per target; refresh `docs/INTEGRATION.md` \& `docs/linter-coverage.md` for `just` step, `.jq`, `.tsv`, justfile; `CHANGELOG.md` ⊥ (lead)|`.:T24`,`.:T30`,C22
T72|x|rename to `claudinix` in every doc: README title + tagline "Claude in cloud on Nix" + name origin (claud = Claude \| cloud, "i nix" = Polish "and nix") + note: unofficial, ⊥ affiliated w/ \| endorsed by Anthropic; `nix run github:pr0d1r2/claudinix#…`; `CLAUDINIX_*` settings; CHANGELOG ⊥ (lead)|`.:C10`,`.:T71`,C22
T83|x|consumer-first docs: README = who/what/why + alpha line (`.:C26`) + release paste line block (`.:C25`) + agent home opt-in disclosure (`.:C24`) up top, name note at bottom; SETUP opens w/ `nix run github:pr0d1r2/claudinix#guide`, prereqs (local Nix w/ flakes, accept the cachix prompt), dialog fields in order, 1 remedy list (`nix-dev` first), `--model sonnet` on every launch line, owner-only steps → FORKING/RUNBOOK; ⊥ spec ids in user text; drop `ANTHROPIC_MODEL` advice (review R3-*)|C22,`.:C24`,`.:C25`,`.:C26`
T84|x|docs accuracy pass: every review R5 mismatch (planned→exists, fork tables, SECURITY unchecked downloads, SESSION steps, INTEGRATION checks, model defaults, ids form)|C22
T85|x|AGENTS.md: "Spec workflow here" (overrides cavekit defaults: Conventional Commits ⊥ `T<n>:`; status flip = own `docs(spec)` commit then `mth archive`; FORMAT.md at `~/.claude/FORMAT.md`; cloud skill names); federation rules (node owning the files, ids global = max over all `SPEC*.md` + 1, cite `.:C15` \| `docs:T13`, Refs example); gate pattern `hk check --all >log 2>&1; echo rc=$?`; app change → follow-up `docs:` commit (review R4-3,4,6,11,12,13)|C22,`.:C17`,`.:C21`
T89|x|`docs/CONSUMER.md` zizmor: replace "`--offline` everywhere" w/ the reference approach (pr0d1r2/sherd#101, merged 2026-10-03; shared step pr0d1r2/set-and-setting#561): verdict by exit code (0 clean, 10-14 finding, else "could not run: <reason>", still exit 1); online audit w/ tokens locally \& in CI; only when `CLAUDE_CODE_REMOTE=true` unset `GH_TOKEN`/`GITHUB_TOKEN`, then `--offline` if still failing; token-unset part ⊥ proven (401 seen once). + lesson: format checks must run pre-commit, ⊥ only in `hk check --all`|`.:C6`,`.:V18`,C22
