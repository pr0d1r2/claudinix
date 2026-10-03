# Runbook

Operational procedures for this repository and the cloud environment it
configures. Each section says whether the procedure is **automated** (a
workflow or script does it) or needs a **human**, and what is planned to
automate it.

The cloud environment itself lives in the claude.ai web UI and has no API
(`SPEC.md` C2), so every change to it is made by hand in the browser.
[`SETUP.md`](SETUP.md) has the exact clicks.

## Bump the pinned Nix version

**Automated, with a human review.** `just bump-nix <version>` does the
rewrite (`SPEC.md` T10); you review the diff, run the gate and commit.

The image already ships a Nix (2.34.6, measured 2026-10-03), and
`setup.sh` uses it whenever it is at least the floor `NIX_MIN_VERSION`
(2.34). The pinned version is installed only below that floor. So a bump
matters only when the image falls behind the floor, or when you raise the
floor on purpose.

1. Pick the version from [releases.nixos.org](https://releases.nixos.org/?prefix=nix/).
2. Run `just bump-nix <version>` (for example `just bump-nix 2.36.0`). It
   fetches `install.sha256` for that version from releases.nixos.org and
   rewrites `version=` and the default `sha256` in `setup.sh` together
   (`SPEC.md` V11), then prints
   `bump-nix: setup.sh now pins Nix <version>, installer sha256 <hash>`. It
   changes nothing else, and if it cannot fetch or parse the hash it leaves
   `setup.sh` unchanged and exits 1. A version without its hash, or the
   reverse, would make `setup.sh` refuse to run the installer, which is why
   the two are never edited by hand.
3. Review `git diff setup.sh`: two lines should change, and nothing else.
4. Run the gate (`hk check --all`), commit, push, and let CI go green.
5. Update the environment's setup script in the browser (see below), then
   start a new session and run `probe.sh` to see the new version.

## Update the setup script in the environment

**Human.** The environment holds one line, pinned to a commit SHA, so an
update is a new SHA and nothing else (`SPEC.md` T24, V20). Its fetch of
`setup.sh` from `raw.githubusercontent.com` has not yet been tried in a real
cloud session (`SPEC.md` T57).

1. Make sure the change is merged, pushed and CI on `main` is green. The line
   checks this too: `setup-line.sh` refuses a SHA whose newest `ci.yml` run on
   `main` is not completed and successful, because that run pushes the agent
   home to the cache (`SPEC.md` C19).
2. Print the new line from a checkout: `scripts/setup-line.sh`, or
   `scripts/setup-line.sh <rev>` for another commit (a full SHA needs no
   checkout). `--force` prints it despite a red or missing run, with a
   warning; use it only on purpose ([`CLI.md`](CLI.md)).
3. Follow "Updating the environment" in [`SETUP.md`](SETUP.md): open the
   `nix` environment's settings, select all of the old setup script, paste
   the new line over it, save.
4. Start a **new** session. A running session keeps its old VM.
5. Run `probe.sh` in that session and check every line.

A changed setup script rebuilds the snapshot on the next session, so expect
that start to be slower.

## Refill the binary cache

**Automated** on every push to `main`: the CI `gate` job pushes what it
built to `pr0d1r2.cachix.org`, and the `verify cache` job checks that each
output's narinfo answers HTTP 200.

**Human**, when the cache was garbage-collected or a push was lost:

1. Re-run the latest `main` workflow from the Actions tab. It rebuilds and
   pushes.
2. Or push by hand from a machine that holds the push token (never from a
   cloud VM, `SPEC.md` V6):

   ```sh
   nix build --no-link --print-out-paths .#devShells.x86_64-linux.default .#checks.x86_64-linux.xenolith
   cachix push pr0d1r2 <path>...
   ```

3. Confirm the push the same way CI does:

   ```sh
   bash scripts/ci/verify-cachix.sh .#checks.x86_64-linux.xenolith .#devShells.x86_64-linux.default
   ```

Target repositories fill the cache with their own locked inputs and dev
shells from their own CI (`SPEC.md` T6, T54).

## A probe comes back red

**Human.** Run `bash probe.sh` (from a checkout of this repository) inside
a session. Each line is one check; the exit status is 1 if any health
check failed. To start a probe session from your terminal instead, run
`nix run github:pr0d1r2/nix-claude-code-cloud#probe` in your project: it
prints the session's report ([`CLI.md`](CLI.md)). That launcher has not yet
been run end to end against a real cloud session.

| line | likely cause | fix |
|---|---|---|
| `nix-path: FAIL` | the setup script did not run, or failed before linking `nix` into `/usr/local/bin` | check the session is in the `nix` environment (`/remote-env`), then read the setup step in the session's checklist |
| `substituters: FAIL` | the managed block in `/etc/nix/nix.conf` is missing | the setup script did not finish; check the pasted line and start a new session |
| `cachix: FAIL HTTP 403` | `pr0d1r2.cachix.org` is not in the allowed domains | add it (see `allowlist.txt`), start a new session |
| `channels: FAIL HTTP 403` | `channels.nixos.org` or `releases.nixos.org` is not allowed | add both, start a new session (`SPEC.md` B1) |
| `cachix-input: FAIL HTTP 404` | the target repository's CI has not pushed that input | run the target's CI on its default branch (`SPEC.md` T54) |
| `github-fetch: refused` | expected: the GitHub proxy refuses `github:` archive fetches | nothing to fix here; see `SETUP.md` troubleshooting for target flakes |

Record anything new in [`FACTS.md`](FACTS.md) with the date, and in
`SPEC.md` `§B` through `/ck:spec`.

## Emergency stop of cloud spend

**Human.** Do these in order; the first two stop money leaving.

1. Open [claude.ai/settings/usage](https://claude.ai/settings/usage) and
   turn usage credits (metered overage) **OFF**. Sessions then stop when
   the plan or credit runs out instead of billing on.
2. Open [claude.ai/code](https://claude.ai/code) and stop every running
   session from the sidebar.
3. Disable any scheduled routine that starts sessions on this environment.
4. Check the usage page again a few minutes later, and note the numbers in
   [`FACTS.md`](FACTS.md) under "Cost".

## Clean up probe branches

**Human.** Planned: `nix run …#probe --cleanup` (`SPEC.md` T28).

A cloud session cannot delete branches, and every probe pushes one named
`claude/nix-probe-<suffix>`. From your own machine:

```sh
git fetch --prune origin
git branch -r --list 'origin/claude/nix-probe*'
git push origin --delete claude/nix-probe-<suffix>
```

Then archive the finished probe sessions from the sidebar at
[claude.ai/code](https://claude.ai/code).
