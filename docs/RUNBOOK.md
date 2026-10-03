# Runbook

Operational procedures for this repository and the cloud environment it
configures. Each section says whether the procedure is **automated** (a
workflow or script does it) or needs a **human**, and what is planned to
automate it.

The cloud environment itself lives in the claude.ai web UI and has no API
(`SPEC.md` C2), so every change to it is made by hand in the browser.
[`SETUP.md`](SETUP.md) has the exact clicks.

## Bump the pinned Nix version

**Human.** Planned: `just bump-nix <version>` (`SPEC.md` T10).

The image already ships a Nix (2.34.6, measured 2026-10-03), and
`setup.sh` uses it whenever it is at least the floor `NIX_MIN_VERSION`
(2.34). The pinned version is installed only below that floor. So a bump
matters only when the image falls behind the floor, or when you raise the
floor on purpose.

1. Pick the version from [releases.nixos.org](https://releases.nixos.org/?prefix=nix/).
2. Fetch the installer's published hash:

   ```sh
   curl -fsSL https://releases.nixos.org/nix/nix-<version>/install.sha256
   ```

3. In `setup.sh`, change `version=` and the default `sha256` together, in
   one commit (`SPEC.md` V11). A version without its hash, or the reverse,
   makes `setup.sh` refuse to run the installer.
4. Run the gate (`hk check --all`), push, and let CI go green.
5. Update the environment's setup script in the browser (see below), then
   start a new session and run `probe.sh` to see the new version.

## Update the setup script in the environment

**Human.** Planned: a one-line setup script pinned to a commit SHA, so an
update is a new SHA and nothing else (`SPEC.md` T24, V20).

Today the environment holds a pasted copy of the whole `setup.sh`:

1. Make sure the change is merged and CI is green.
2. Follow "Updating the environment" in [`SETUP.md`](SETUP.md): open the
   `nix` environment's settings, select all of the old setup script, paste
   the new one over it, save.
3. Start a **new** session. A running session keeps its old VM.
4. Run `probe.sh` in that session and check every line.

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
check failed. Planned: `nix run …#probe` launches a probe session from
your terminal (`SPEC.md` T28).

| line | likely cause | fix |
|---|---|---|
| `nix-path: FAIL` | the setup script did not run, or failed before linking `nix` into `/usr/local/bin` | check the session is in the `nix` environment (`/remote-env`), then read the setup step in the session's checklist |
| `substituters: FAIL` | the managed block in `/etc/nix/nix.conf` is missing | the setup script did not finish; re-paste it and start a new session |
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
