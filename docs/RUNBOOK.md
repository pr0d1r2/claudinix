# Runbook

Operational procedures for this repository and the cloud environment it
configures. Each section says whether the procedure is **automated** (a
workflow or script does it) or needs a **human**, and what is planned to
automate it.

The cloud environment itself lives in the claude.ai web UI and has no API
(`.:C2`), so every change to it is made by hand in the browser.
[`SETUP.md`](SETUP.md) has the exact clicks.

## Keep the environment and the files in step

**Human.** For the owner of the environment. The files in this repository
are the source of truth for what you paste in the browser: `setup.sh`
through the one-line setup script, [`allowlist.txt`](../allowlist.txt) for
the allowed domains, and [`env-names.txt`](../env-names.txt) for the
environment variables. Never change the environment in the browser without a
matching commit here, and never edit those files without updating the
environment afterwards. If the two disagree, that is a bug: fix the side that
is wrong and record it.

To change the allowed domains, edit `allowlist.txt`, commit, and paste the
new list into the environment ("Updating the environment" in
[`SETUP.md`](SETUP.md)). To change what the setup script does, edit
`setup.sh`, merge, wait for green CI on `main`, and publish a new setup line
(below). Users follow the line published with a release; they never edit
either file.

## Bump the pinned Nix version

**Automated, with a human review.** `just bump-nix <version>` does the
rewrite (`.:T10`); you review the diff, run the gate and commit.

The image already ships a Nix (2.34.6, measured 2026-10-03), and
`setup.sh` uses it whenever it is at least the floor `NIX_MIN_VERSION`
(2.34). The pinned version is installed only below that floor. So a bump
matters only when the image falls behind the floor, or when you raise the
floor on purpose.

1. Pick the version from [releases.nixos.org](https://releases.nixos.org/?prefix=nix/).
2. Run `just bump-nix <version>` (for example `just bump-nix 2.36.0`). It
   fetches `install.sha256` for that version from releases.nixos.org and
   rewrites `version=` and the default `sha256` in `setup.sh` together
   (`.:V11`), then prints
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
update is a new SHA and nothing else (`.:T24`, `.:V20`). Its fetch of
`setup.sh` from `raw.githubusercontent.com` has not yet been tried in a real
cloud session (`.:T57`).

1. Make sure the change is merged, pushed and CI on `main` is green. The line
   checks this too: `setup-line.sh` refuses a SHA whose newest `ci.yml` run on
   `main` is not completed and successful, because that run pushes the agent
   home to the cache (`.:C19`).
2. Cut the release in two steps with `scripts/release.sh` (`just release`
   runs the same script). The released SHA must hold
   `cloud-home.storepath` for its own agent home, so the path is recorded
   and committed first, and the line pins that commit. The script never
   commits, tags or pushes; it prints the commands and you run them.

   1. `just release record REV` (`REV` defaults to `HEAD`). It checks that CI
      on `main` is green for `REV` and that every input source and `REV`'s
      agent home are in the cache, then writes `cloud-home.storepath`. It
      prints a `git add cloud-home.storepath`, a `git commit` and a
      `git push`. Run them. If `REV` already records its own agent home, it
      says so and tells you to publish it directly.
   2. Wait until CI on `main` is green for that new commit.
   3. `scripts/release.sh publish REV2 >notes.md`, where `REV2` is the commit
      from step 1 (`git rev-parse HEAD`). Run it directly, not through
      `just`, so the redirect captures only the script's stdout (or use
      `just --quiet release publish REV2 >notes.md`). It checks that `REV2`
      holds `cloud-home.storepath`, that it equals the agent home evaluated
      at `REV2`, and that CI and the cache are still good. Then it
      regenerates the README block, writes the release notes to stdout and
      prints the commands to stderr.
   4. Run the printed commands: `git add README.md`, the `chore(release)`
      commit, `git push`, `git tag -a claudinix-<short> <sha>`,
      `git push origin claudinix-<short>` and
      `gh release create claudinix-<short> --verify-tag --title "claudinix <short>" --notes-file notes.md`.
3. To print a line for another commit without a release, use
   `scripts/setup-line.sh [REV]`; `--force` prints it despite a red or
   missing run, with a warning, and `--agent-home` appends the opt-in flag
   ([`CLI.md`](CLI.md)). The README block between the `setup-line` markers
   and the release notes hold the line that `publish` generated; users
   paste that one.
4. Follow "Updating the environment" in [`SETUP.md`](SETUP.md): open the
   `nix` environment's settings, select all of the old setup script, paste
   the new line over it, save.
5. Start a **new** session. A running session keeps its old VM.
6. Run `probe.sh` in that session and check every line.

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
   cloud VM, `.:V6`):

   ```sh
   nix build --no-link --print-out-paths .#devShells.x86_64-linux.default .#homeConfigurations.cloud.activationPackage
   cachix push pr0d1r2 <path>...
   scripts/ci/push-sources.sh pr0d1r2
   ```

   The first command builds the dev shell and the agent home, and the last
   pushes every eval-time input source (a session evaluates them before it
   builds, and cannot fetch `github:` inputs from GitHub).

3. Confirm the push the same way CI does:

   ```sh
   bash scripts/ci/verify-cachix.sh --sources . .#devShells.x86_64-linux.default .#homeConfigurations.cloud.activationPackage
   ```

   It exits 1, and says which path, when an output or an input source is in
   neither `pr0d1r2.cachix.org` nor the upstream `cache.nixos.org`.

Target repositories fill the cache with their own locked inputs and dev
shells from their own CI (`docs:T6`, `.:T54`).

## A probe comes back red

**Human.** Run `bash probe.sh` (from a checkout of this repository) inside
a session. Each line is one check; the exit status is 1 if any health
check failed. To start a probe session from your terminal instead, run
`nix run github:pr0d1r2/claudinix#probe` in your project: it
prints the session's report ([`CLI.md`](CLI.md)). That launcher has not yet
been run end to end against a real cloud session.

| line | likely cause | fix |
|---|---|---|
| `nix-path: FAIL` | the setup script did not run, or failed before linking `nix` into `/usr/local/bin` | check the session is in the `nix` environment (`/remote-env`), then read the setup step in the session's checklist |
| `substituters: FAIL` | the managed block in `/etc/nix/nix.conf` is missing | the setup script did not finish; check the pasted line and start a new session |
| `cachix: FAIL HTTP 403` | `pr0d1r2.cachix.org` is not in the allowed domains | add it (see `allowlist.txt`), start a new session |
| `channels: FAIL HTTP 403` | `channels.nixos.org` or `releases.nixos.org` is not allowed | add both, start a new session (`.:B1`) |
| `cachix-input: FAIL HTTP 404` | the target repository's CI has not pushed that input | run the target's CI on its default branch (`.:T54`) |
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

**Human.** `nix run github:pr0d1r2/claudinix#probe -- --cleanup`, run in the
project, deletes every `claude/nix-probe*` branch on the remote and prints
`probe: deleted <branches>` (`scripts:T28`).

A cloud session cannot delete branches, and every probe pushes one named
`claude/nix-probe-<suffix>`. To do it by hand, from your own machine:

```sh
git fetch --prune origin
git branch -r --list 'origin/claude/nix-probe*'
git push origin --delete claude/nix-probe-<suffix>
```

Then archive the finished probe sessions from the sidebar at
[claude.ai/code](https://claude.ai/code).
