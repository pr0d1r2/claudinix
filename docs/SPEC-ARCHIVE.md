# SPEC ARCHIVE

Task rows moved out of `SPEC.md` by `mth archive`. An id is never reused
(`V12`), so a citation to an archived row still resolves -- here.

This is a SINK, not a spec. The citations inside these rows point into
`SPEC.md`, so `mth check` on this file reports every one of them as dangling,
correctly and uselessly. The verb that reads it is `mth tasks`.

## §T TASKS

T13|x|`docs/SETUP.md` for zero-knowledge user: money steps first (claim credit, usage credits OFF — before ∀ cloud session), then browser steps (selector → Add cloud environment → name, Network access Custom + default list + `allowlist.txt`, env vars from `env-names.txt`, Setup script = `setup.sh`), update flow, then terminal `/remote-env` \| `remote.defaultEnvironmentId`; prereqs, GitHub connect (App, select repos), first-session check, troubleshooting, cleanup|C2,`.:V10`,I.ext.env
T31|x|W1 MUST `AGENTS.md`: for AI agents working here (incl. cloud sessions): spec first, gate, atomic commits, RED/GREEN/REFACTOR, model default; model sherd/itok `AGENTS.md`|C22,C17,C21
T32|x|W1 MUST `docs/INTEGRATION.md`: every hk step, how to run each by hand, parallelism, "hk.pkl wins"; model itok/xenolith `INTEGRATION.md`|C22,C14,C18
T33|x|W1 MUST `docs/LLM-DISCLAIMER.md`: built by Claude in the open; what to check before trusting a root-run setup script; model sherd|C22,C10
T34|x|W2 MUST `docs/FACTS.md`: dated cloud VM facts per probe (user, image Nix, proxy 403s, git vs tarball, branch suffix, commit author, shallow clone, allowlist only for new sessions); stale assumption = visible by date|C22,C8,C13
T35|x|W2 MUST `docs/RUNBOOK.md`: each procedure marked automated\|human: bump Nix pin, rotate SHA in UI, refill cachix, red probe, emergency stop of cloud spend, probe branch cleanup; model nix-hk `RUNBOOK.md`|C22,`.:V20`,`.:V11`,C19
T36|x|W2 MUST `docs/SECURITY.md`: private reporting path + threat model (root setup script, cache trust, `accept-flake-config` (`.:V25`: any cloned repo's `nixConfig` applies), GitHub proxy, ⊥ secrets in env vars); model sherd|C22,`.:V6`,C5
T37|x|W2 MUST `CHANGELOG.md`: per release \& per UI-pinned SHA what changed, so users know before bumping the setup line|C22,`.:V20`
T38|x|W1 SHOULD `docs/linter-coverage.md`: file type → linter table (`.sh`, `.nix`, `.bats`, `.pkl`, `.yml`, `.md`, `.toml`); model nixos-poe2|C22,C15,C16
