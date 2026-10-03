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
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - uses: cachix/install-nix-action@630ae543ea3a38a9a4166f03376c02c50f408342 # v31.11.0

      # The action pushes what the later steps build. `name` is your cache.
      - uses: cachix/cachix-action@38b082610b782e7e93e209c35fd730d399dee866 # v17
        with:
          name: pr0d1r2
          authToken: ${{ secrets.CACHIX_AUTH_TOKEN }}

      # 1 and 2: the dev shell, built so its closure is pushed.
      - run: nix build --no-link .#devShells.x86_64-linux.default

      # 3: every locked input, from the flake's own lock file.
      - run: bash scripts/ci/push-inputs.sh

      # 4: prove it. See below.
      - run: bash scripts/ci/verify-cache.sh
```

Replace `pr0d1r2` with the name of the cache you push to. The `x86_64-linux`
system is the one cloud sessions run on ([`FACTS.md`](FACTS.md), 2026-10-03).

## The two scripts

Keep the shell in script files rather than inline in the workflow. If your
repository uses xenolith, it requires that anyway.

`scripts/ci/push-inputs.sh` pushes every input path that
`nix flake archive --json` reports. That command prints a JSON tree: a `path`
for the flake itself and, under `inputs`, the same for each input, nested.

```sh
#!/usr/bin/env bash
set -euo pipefail

paths="$(nix flake archive --json | jq -r '.. | .path? // empty')"
# shellcheck disable=SC2086 # one store path per word
cachix push "${CACHE_NAME:-pr0d1r2}" $paths
```

`scripts/ci/verify-cache.sh` can be this repository's
[`verify-cachix.sh`](../scripts/ci/verify-cachix.sh) copied as it is. It takes
flake attributes, evaluates each to a store path, asks the cache for that
path's narinfo, and fails on anything but HTTP 200. Pass it the dev shell:

```sh
bash scripts/ci/verify-cachix.sh .#devShells.x86_64-linux.default
```

It reads the cache from `CACHIX_URL` and defaults to
`https://pr0d1r2.cachix.org`, so set that for your own cache.

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

## What this snippet has not been proven on

The workflow and `verify-cachix.sh` are this repository's own, and its CI runs
them. The `push-inputs.sh` script above is a sketch written for this page and
has not been run in a target repository yet. Try it on a branch first and
confirm the narinfo check passes before you rely on it.
