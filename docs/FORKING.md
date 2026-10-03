# Forking: your own cache, domains and names

You may not want to trust the owner's binary cache, or you may want sessions
to read a cache you control. This page lists what to change. It is honest
about one thing up front: the spec calls for all owner-specific values to sit in
one config block at the top of `setup.sh`, so that a fork edits only that block
(`SPEC.md` C11). That block does not exist yet. Today the values are spread
over a few files, and this page is the checklist until it does.

Read [`SECURITY.md`](SECURITY.md) first. What you are changing is whose cache
a root-run script trusts.

## What is the owner's

| value | what it is |
|---|---|
| `pr0d1r2.cachix.org` | the binary cache sessions read from |
| `pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=` | that cache's public signing key |
| `pr0d1r2/nix-claude-code-cloud` | this repository, in GitHub URLs |
| `github:pr0d1r2/...` flake inputs | the owner's tools: nix-hk, xenolith, itok, microlith, sherd, nixpkgs-lock |

The cache's public key is public on purpose. It is not a secret and appears in
`setup.sh`, `flake.nix` and `SPEC.md`.

## 1. Make your own cache

Create a cache at [cachix.org](https://www.cachix.org) (or any Nix binary
cache you control). You need two things from it: its host name, and its public
signing key. Cachix shows both on the cache's page. Keep the push token
(`CACHIX_AUTH_TOKEN`) for your CI secrets only. It never goes into a cloud
environment, an env var or a session VM (`SPEC.md` V6).

## 2. Replace the values

Find every use:

```sh
grep -rn "pr0d1r2" --exclude-dir=.git .
```

The ones that matter, as they stand today:

| file | change |
|---|---|
| [`setup.sh`](../setup.sh) | the `extra-substituters` and `extra-trusted-public-keys` lines in the managed `nix.conf` block |
| [`allowlist.txt`](../allowlist.txt) | the cache host |
| [`flake.nix`](../flake.nix) | `nixConfig`, the substituter and key |
| [`probe.sh`](../probe.sh) | the default `CACHIX_URL` |
| [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) | the cachix `name`, and the `CACHIX_AUTH_TOKEN` secret you add to your repository |
| [`scripts/ci/verify-cachix.sh`](../scripts/ci/verify-cachix.sh) | the default `CACHIX_URL` |
| `tests/unit/*.bats` | the bats tests that assert these values; the gate fails until they match |

You do not need to guess if you missed one: the bats tests check that
`allowlist.txt` names the hosts it should and that no value looks like a
secret, and `ci.yml` verifies a cache push with a narinfo request
([`INTEGRATION.md`](INTEGRATION.md)).

The `github:pr0d1r2/...` inputs in `flake.nix` are other people's tools, built
and cached by the owner's CI. If you keep them, your dev shell still
substitutes them from the owner's cache, so keep that substituter in the
dev-shell `nixConfig` or be ready to build them from source. If you replace
them, you own keeping them in step. Note that the cloud environment cannot
fetch `github:` inputs at all, so inputs the session builds must reach it
through a cache ([`CACHE-CI.md`](CACHE-CI.md)).

## 3. Set up the cloud environment as yours

1. Follow [`SETUP.md`](SETUP.md) with your edited `setup.sh` and
   `allowlist.txt`. The environment name `nix` is only a label in the browser;
   pick another if you like and tell your terminal with `/remote-env`.
2. The environment's allowed domains need your cache host in place of the
   owner's, and `github.com`, `cache.nixos.org`, `channels.nixos.org` and
   `releases.nixos.org` as they are now (`allowlist.txt`, probes 1-5).
3. Add the ecosystem hosts your targets need, such as `index.crates.io` and
   `static.crates.io` for Cargo ([`CONSUMER.md`](CONSUMER.md)). Planned: a
   `domains` command that lists them from lock files (`scripts/SPEC.md`
   T27).
4. Fill the cache: push to your cache from your CI on the default branch, and
   check that it answers ([`CACHE-CI.md`](CACHE-CI.md)).
5. Start a first session and run [`probe.sh`](../probe.sh). Every line should
   say `ok`; see [`RUNBOOK.md`](RUNBOOK.md) for what each failure means.

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
