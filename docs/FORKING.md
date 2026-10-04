# Forking: your own cache, domains and names

You may not want to trust the owner's binary cache, or you may want sessions
to read a cache you control. This page lists what to change. It is honest
about one thing up front: the owner-specific values of `setup.sh` sit in one
config block at its top, so that for that file a fork edits only that block
(`.:C11`). Some values live outside `setup.sh`, and this page lists them.

Read [`SECURITY.md`](SECURITY.md) first. What you are changing is whose cache
a root-run script trusts.

## What is the owner's

| value | what it is |
|---|---|
| `pr0d1r2.cachix.org` | the binary cache sessions read from |
| `pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=` | that cache's public signing key |
| `pr0d1r2/claudinix` | this repository, in GitHub URLs |
| `pr0d1r2/...` flake inputs | the owner's tools: nix-hk, xenolith, itok, microlith, sherd, nixpkgs-lock, and for the agent home nix-home-manager-claude-code and set-and-setting (the owner's claude-code module and rules) |

The cache's public key is public on purpose. It is not a secret and appears in
`setup.sh`, `flake.nix` and `SPEC.md`.

## 1. Make your own cache

Create a cache at [cachix.org](https://www.cachix.org) (or any Nix binary
cache you control). You need two things from it: its host name, and its public
signing key. Cachix shows both on the cache's page. Keep the push token
(`CACHIX_AUTH_TOKEN`) for your CI secrets only. It never goes into a cloud
environment, an env var or a session VM (`.:V6`).

## 2. Replace the values

Find every use:

```sh
grep -rn "pr0d1r2" --exclude-dir=.git .
```

In [`setup.sh`](../setup.sh), edit only the fork config block between
`# BEGIN fork config (SPEC C11)` and `# END fork config (SPEC C11)`:

| variable | change it to |
|---|---|
| `cache_host` | your cache's host name |
| `cache_key` | your cache's public signing key |
| `repo` | `<you>/<your fork>`, used in the raw and `git+https` URLs |

Nothing else in `setup.sh` names the owner. These values live outside it, and
each needs the same change:

| file | change |
|---|---|
| [`allowlist.txt`](../allowlist.txt) | the cache host |
| [`flake.nix`](../flake.nix) | `nixConfig`, the substituter and key |
| [`probe.sh`](../probe.sh) | the default `CACHIX_URL` |
| [`scripts/ci/verify-cachix.sh`](../scripts/ci/verify-cachix.sh) | nothing, when `cache.name` is set (below); its `CACHIX_URL` default is built from `cache.name` |
| [`scripts/inputs.sh`](../scripts/inputs.sh) | the fallback `name=` line, used when an old `nix-dev` install has no `config.sh`; the default cache is built from `cache.name` (below) |
| [`scripts/config.jq`](../scripts/config.jq) | the default `cache.name` in `defaults` |
| [`scripts/nix/record-storepath.sh`](../scripts/nix/record-storepath.sh) | the default `CACHIX_URL` |
| [`scripts/ci/push-sources.sh`](../scripts/ci/push-sources.sh) and [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) | the cachix cache name: `ci.yml` has it in the cachix action's `name` and in the `push-sources.sh` call; and add the `CACHIX_AUTH_TOKEN` secret to your repository |
| [`scripts/setup-line.sh`](../scripts/setup-line.sh) | its `repo=` line, which sets the raw URL it prints and the repository whose CI it asks about |
| `tests/unit/**/*.bats` | the bats tests that assert these values (for example `tests/unit/setup.bats`, `tests/unit/scripts/setup-line.bats`); the gate fails until they match |

### Set `cache.name` in `.claudinix.toml`

`inputs` and `ci/verify-cachix.sh` build their cache URL as
`https://<cache.name>.cachix.org`. A fork can set `name` under `[cache]` in
its own [`.claudinix.toml`](CONFIG.md) and those tools use it with no code
change:

```toml
version = 1

[cache]
name = "your-cache"
```

The built-in default is `pr0d1r2`. It lives in
[`scripts/config.jq`](../scripts/config.jq), and the fallback for an old
`nix-dev` install without the reader is in
[`scripts/inputs.sh`](../scripts/inputs.sh); change both if you want your
name as the default for everyone who runs your copy of the tools.
`INPUTS_CACHES` and `CACHIX_URL` still win over the file.

The grep above also finds `pr0d1r2/...` in comments and docs; change the
code ones with the tables.

You do not need to guess if you missed one: the bats tests check that
`allowlist.txt` names the hosts it should and that no value looks like a
secret, and `ci.yml` verifies a cache push with a narinfo request
([`INTEGRATION.md`](INTEGRATION.md)).

The `pr0d1r2/...` inputs in `flake.nix` are other people's tools, built
and cached by the owner's CI (and `nix-home-manager-claude-code` and
`set-and-setting`, which carry the agent home's claude-code module and
rules: replacing them changes how Claude behaves in an agent-home session). If you keep them, your dev shell still
substitutes them from the owner's cache, so keep that substituter in the
dev-shell `nixConfig` or be ready to build them from source. If you replace
them, you own keeping them in step. Note that the cloud environment cannot
fetch `github:` inputs at all, so inputs the session builds must reach it
through a cache ([`CACHE-CI.md`](CACHE-CI.md)).

## 3. Set up the cloud environment as yours

1. Follow [`SETUP.md`](SETUP.md) with your edited `setup.sh` and
   `allowlist.txt`. The setup script is the line `scripts/setup-line.sh`
   prints, and that script has its own `repo=` line. Change it to your fork
   first, or the line fetches the owner's `setup.sh`, not yours, and asks
   about the owner's CI. It prints a line only for a commit whose CI on
   `main` is green, so your fork's CI must run `ci.yml` on `main` first. The
   environment name `nix` is only a label in the browser;
   pick another if you like and tell your terminal with `/remote-env`.
2. The environment's allowed domains need your cache host in place of the
   owner's, and `github.com`, `cache.nixos.org`, `channels.nixos.org`,
   `releases.nixos.org` and `raw.githubusercontent.com` as they are now (`allowlist.txt`, probes 1-5).
3. Add the ecosystem hosts your targets need, such as `index.crates.io` and
   `static.crates.io` for Cargo ([`CONSUMER.md`](CONSUMER.md)). The `domains`
   command lists them from your lock files: run
   `nix run github:<you>/<fork>#domains` in each target
   ([`CLI.md`](CLI.md)).
4. Keep the environment and your files in step: `setup.sh` (through the
   setup line) and `allowlist.txt` are what you paste into the browser, so
   never change the environment without a matching commit, and never edit
   either file without updating the environment afterwards
   ([`RUNBOOK.md`](RUNBOOK.md)). Your users paste the line you publish and
   edit nothing.
5. Fill the cache: push to your cache from your CI on the default branch, and
   check that it answers ([`CACHE-CI.md`](CACHE-CI.md)).
6. Start a first session and run [`probe.sh`](../probe.sh). No line should
   say `FAIL`; see [`RUNBOOK.md`](RUNBOOK.md) for what each failure means.

## 4. Keep the gate green

You inherit the gate. Run `hk check --all` in the dev shell after your edits
([`INTEGRATION.md`](INTEGRATION.md)) and fix what it says. Do not weaken a
check to get past it ([`CONTRIBUTING.md`](CONTRIBUTING.md)).

## 5. Say whose it is

[`LICENSE`](../LICENSE) is MIT with the original copyright line. Keep it, and
add yours. Keep [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md). Change the
reporting address in [`SECURITY.md`](SECURITY.md) and
[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) to yours, because reports to the
owner's address are not yours to receive.
