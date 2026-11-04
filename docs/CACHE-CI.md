# Filling the binary cache from a target repository's CI

A cloud session cannot fetch `github:` flake inputs (they fail with a 403,
[`FACTS.md`](FACTS.md), "GitHub"), so the repository you send to the cloud
should have every locked input and its dev shell already sitting in a binary
cache the session can read. Nix then substitutes each one by its `narHash`
and never contacts GitHub. This page shows the CI job that does that.

This is a document, not a tool. A target repository adopts it through its own
spec and its own workflow file. Nothing here runs from this repository for
you.

## What the job has to do

On every push to the default branch:

1. Build the dev shell, so its closure exists in the runner's store.
2. Push the dev shell closure to the cache.
3. Push every locked input of the flake, found with `nix flake archive`, to the
   cache.
4. Check that the cache answers for them. A push that exits 0 proves nothing.

The session side needs the cache host in the environment's allowed domains
(`allowlist.txt`) and in the environment's `nix.conf`, which `setup.sh`
already does for `pr0d1r2.cachix.org`. If you use your own cache, see
[`FORKING.md`](FORKING.md).

## The token stays in CI

The push token (`CACHIX_AUTH_TOKEN`) is a repository secret in the target
repository, used only by the CI job. It is never put in the cloud
environment, never in a session's environment variables, and never on a VM:
from the VM the cache is read-only, and a cloud session never needs to push.
Pull requests from forks get no secrets, so they can read the cache but not
fill it. The job below pushes from the default branch only.

## The workflow

Adapted from this repository's own
[`ci.yml`](../.github/workflows/ci.yml). Actions are pinned to commit SHAs
because tags are mutable; take the current SHAs from that file or pin your
own.

```yaml
name: cache

on:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  push-cache:
    runs-on: ubuntu-latest
    env:
      CACHE: pr0d1r2
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - uses: cachix/install-nix-action@630ae543ea3a38a9a4166f03376c02c50f408342 # v31.11.0

      # The action pushes what the later steps build. `name` is your cache.
      - uses: cachix/cachix-action@38b082610b782e7e93e209c35fd730d399dee866 # v17
        with:
          name: ${{ env.CACHE }}
          authToken: ${{ secrets.CACHIX_AUTH_TOKEN }}

      # 1 and 2: the dev shell, built so its closure is pushed.
      - run: nix build --no-link .#devShells.x86_64-linux.default

      # 3: every locked input, from the flake's own lock file.
      - run: bash scripts/ci/push-sources.sh "$CACHE"

      # 4: prove it. See below.
      - run: >-
          bash scripts/ci/verify-cachix.sh --sources .
          .#devShells.x86_64-linux.default
        env:
          CACHIX_URL: https://${{ env.CACHE }}.cachix.org
```

Step 3 pushes sources from the target's own CI. A central job that pushes
them instead is planned (`SPEC.md` T93, for repos whose `.claudinix.toml` sets
`push_sources = true`); once it exists, such a repo skips step 3 and keeps
steps 1, 2 and 4, so only one writer pushes its sources.

Set `CACHE` to the name of the cache you push to; the three uses follow it. The `x86_64-linux`
system is the one cloud sessions run on ([`FACTS.md`](FACTS.md), 2026-10-03).

## The two scripts

Keep the shell in script files rather than inline in the workflow. If your
repository uses xenolith, it requires that anyway. Copy both from this
repository at one claudinix commit, and note that commit in your copy so a
stale copy is easy to spot:

- [`scripts/ci/push-sources.sh`](../scripts/ci/push-sources.sh) `CACHE
  [FLAKE]` pushes every input path that `nix flake archive --json` reports.
  That command prints a JSON tree: a `path` for the flake itself and, under
  `inputs`, the same for each input, nested. It fails when the list is empty
  or the push fails, so a push that did nothing is red.
- [`scripts/ci/verify-cachix.sh`](../scripts/ci/verify-cachix.sh) takes flake
  attributes, evaluates each to a store path, asks the cache for that path's
  narinfo, and fails on anything but HTTP 200. With `--sources FLAKE` it
  checks every input source of the flake too, but accepts a source found in
  either your cache or `UPSTREAM_URL` (default `https://cache.nixos.org`), so
  it does not prove each source is in your cache. Pass it the dev shell:

```sh
bash scripts/ci/verify-cachix.sh --sources . .#devShells.x86_64-linux.default
```

Both need `jq`. `verify-cachix.sh` works in a copy only with `CACHIX_URL` set
(for example `https://pr0d1r2.cachix.org`) in the verify step. Without it,
the script runs `../config.sh` next to itself to read the cache name from
`.claudinix.toml`. A copy that lacks that file fails with an error.

## Checking it worked

From any machine, with the locked input's store path:

```sh
curl -s -o /dev/null -w '%{http_code}\n' https://<cache>/<hash>.narinfo
```

`<hash>` is the part of the store path between `/nix/store/` and the first
dash. `200` means the cache has it. A `404` after a green push step means the
push did not do what you thought, which is the failure the verify step exists
to catch.

Then check from the cloud side. Run [`probe.sh`](../probe.sh) in a session
with `PROBE_STOREPATH` set to one input's store path; its `cachix-input` line
reports `ok` or `FAIL`. See [`RUNBOOK.md`](RUNBOOK.md), "A probe comes back
red".

## Not yet adopted

Both scripts and the workflow are this repository's own, and its CI runs them.
No target repository has adopted the page yet. Try it on a branch of the
first one and confirm the narinfo check passes before you rely on it.
