# claudinix

*Claude in cloud on Nix.*

> **Unofficial.** claudinix is a community project. It is not affiliated
> with, endorsed by, or sponsored by Anthropic. "Claude" and "Claude Code"
> are trademarks of Anthropic.

Read [LLM-DISCLAIMER](docs/LLM-DISCLAIMER.md) first.

**Nix inside a Claude Code cloud session, before Claude starts.** A Claude
Code cloud environment lets you paste one setup script that runs as root on a
fresh VM. This repository is that script, plus what you need to trust it,
check it and fork it: a pinned and hash-checked Nix, a read-only binary cache,
and the facts about what a cloud session allows, each measured and dated.

The problem in one sentence: a cloud session is an Ubuntu VM with no
toolchain for your repository, a network proxy that refuses hosts you did not
list, and a GitHub proxy that returns a 403 for the archive downloads Nix
uses for `github:` flake inputs. Getting `nix develop` to work there took
seven probe sessions, and the results are in [`docs/FACTS.md`](docs/FACTS.md)
so you do not have to repeat them.

## The name

"claud" reads as Claude or as cloud. "i nix" is Polish for "and nix". The
working name was `nix-claude-code-cloud`; the git history keeps it.

## What you get

- **A setup script** ([`setup.sh`](setup.sh)). It uses the Nix the image
  already ships (2.34.6 when measured on 2026-10-03) and installs the pinned
  2.35.2 only if the image falls below the floor of 2.34. The installer runs
  only after its sha256 matches. It writes one managed block into
  `/etc/nix/nix.conf` (flakes on, `accept-flake-config = true`, the read-only
  cache `pr0d1r2.cachix.org`) and links `nix` into `/usr/local/bin`, so the
  Bash tool finds it without sourcing a profile. It also installs `nix-dev`
  and tries to activate the agent home (below).
  In the environment dialog you paste one line, pinned to a commit SHA, that
  `scripts/setup-line.sh` prints; the line downloads `setup.sh` at that
  commit and runs it.
- **Commands for your project** ([`docs/CLI.md`](docs/CLI.md)), run from
  the project you will send to the cloud with
  `nix run github:pr0d1r2/claudinix#<app>`:
  `inputs` lists which of your flake's `github:` inputs a session can get
  from a binary cache and which must be attached; `domains` prints the
  allowed domains your project needs; `guide` walks you through the setup
  steps and checks what it can; `probe` starts a cloud session that probes
  your project and prints its report. Inside a session, `nix-dev` is
  `nix develop` with a failover for the GitHub proxy.
- **An agent home** (`homeConfigurations.cloud`). The setup script activates
  it before Claude starts, so the spec skills are in `~/.claude` at launch.
  Agent-level only: no language toolchain, which stays with your repository's
  own dev shell.
- **The environment as files.** [`allowlist.txt`](allowlist.txt) is the list
  of allowed domains and [`env-names.txt`](env-names.txt) the environment
  variables. The claude.ai environment dialog has no API, so you paste from
  these files by hand and the files stay the source of truth.
- **A probe** ([`probe.sh`](probe.sh)). Run it inside a session to print the
  session facts and the health of Nix, one line per check.
- **The facts** ([`docs/FACTS.md`](docs/FACTS.md)): uid, network, proxy
  behaviour, timings and cost, each with the date it was measured.
- **A gate** ([`hk.pkl`](hk.pkl)) that checks all of the above on every
  commit, and the same gate in CI.

What it deliberately does not do is install your repository's toolchain. That
is your repository's own flake dev shell (`nix develop`), not an apt step
here. [`docs/CONSUMER.md`](docs/CONSUMER.md) says what your repository should
do.

## Set it up

The full walkthrough, with every click, is [`docs/SETUP.md`](docs/SETUP.md).
In short:

1. **Protect your money.** Claim any cloud credit and check that usage
   credits (metered overage) are OFF at
   [claude.ai/settings/usage](https://claude.ai/settings/usage), before any
   session.
2. **Prerequisites.** A claude.ai plan with cloud sessions, Claude Code signed
   in with that account, your repository on GitHub, a Nix flake with a
   committed `flake.lock`, and your branch pushed.
3. **Connect GitHub** to your claude.ai account (once).
4. **Create the environment** at [claude.ai/code](https://claude.ai/code):
   name `nix`, network access **Custom** with the default package-manager
   list included, as allowed domains every non-comment line of
   `allowlist.txt` plus your project's hosts from
   `nix run github:pr0d1r2/claudinix#domains`, and as the setup
   script the one line `scripts/setup-line.sh` prints once CI on `main` is
   green for the commit (not the contents of `setup.sh`).
5. **Choose it in your terminal** with `/remote-env` (once per machine).
6. **Run a first session** and look for a Nix version and `DEVSHELL-OK`:

   ```sh
   claude --cloud "Run: nix --version && nix develop -c true && echo DEVSHELL-OK. Report the output."
   ```

The model is chosen when you start the session, not in the environment, and
the task text must come first:

```sh
claude --cloud "<task>" --model sonnet
```

Setting `ANTHROPIC_MODEL` on the environment does not choose it. See
[`docs/MODEL.md`](docs/MODEL.md). For a worked run on a real repository, with
timings, see [`docs/EXAMPLE.md`](docs/EXAMPLE.md).

## Fork it

Three things are specific to the owner of this repository: the binary cache
host `pr0d1r2.cachix.org`, its public signing key, and the repository's own
name in GitHub URLs. To use your own cache, change them everywhere they
appear. [`docs/FORKING.md`](docs/FORKING.md) has the full walkthrough.

In [`setup.sh`](setup.sh) they sit in one fork config block at the top
(`cache_host`, `cache_key` and `repo`), and a fork edits only that block
there (`SPEC.md` C11). They also appear in these files:

| file | what to change |
|---|---|
| [`allowlist.txt`](allowlist.txt) | the cache host |
| [`flake.nix`](flake.nix) | `nixConfig` |
| [`probe.sh`](probe.sh) | the `CACHIX_URL` default |
| [`scripts/ci/verify-cachix.sh`](scripts/ci/verify-cachix.sh) | the `CACHIX_URL` default |
| [`scripts/setup-line.sh`](scripts/setup-line.sh) | the `repo=` line |
| [`.github/workflows/ci.yml`](.github/workflows/ci.yml) | the cachix cache name and the `CACHIX_AUTH_TOKEN` secret |

The bats tests assert these values too and need the same change.

Your cache needs a push token, and that token lives only in your CI secrets.
It is never put on a session VM; from the VM the cache is read-only.

## Known limits

Each limit has a source, and the dates matter, because Anthropic can change
the platform at any time.

- **Platform.** Ubuntu 24.04 on x86_64, one root shell, no systemd (measured
  2026-10-03).
- **`github:` flake inputs fail with a 403** unless the repository is
  attached to the session. Use a binary cache for large inputs such as
  nixpkgs, or write small inputs as `git+https://github.com/<owner>/<repo>`.
  See [`docs/SETUP.md`](docs/SETUP.md) and [`docs/CONSUMER.md`](docs/CONSUMER.md).
- **Allowlist edits reach new sessions only.** A running session keeps the
  network rules it started with.
- **The snapshot is cached only if setup finishes in about five minutes.**
  Whether a second session really skips the setup script is not measured yet
  (`SPEC.md` T55).
- **Skills placed in `~/.claude/skills` by the setup script** may or may not
  survive the session start. Not measured yet (`SPEC.md` T14).
- **Not yet run in a real cloud session:** the agent home activation, `nix-dev`
  inside a session, the `probe` launcher from start to finish, and the setup
  line's fetch of `setup.sh` from `raw.githubusercontent.com` during setup.
  Each is built and covered by bats tests with stubs, but treat it as
  untested where it counts until a probe says otherwise (`SPEC.md` T57 for
  the fetch).
- **Trust.** `accept-flake-config = true` lets any repository's `nixConfig`
  apply, and the setup script runs as root. Use the environment only with
  repositories you trust, and read [`docs/SECURITY.md`](docs/SECURITY.md).
- **Built by an LLM.** Read [`docs/LLM-DISCLAIMER.md`](docs/LLM-DISCLAIMER.md)
  and check the script you paste, at the commit you paste it from.

## Documentation

| doc | what is in it |
|---|---|
| [`docs/SETUP.md`](docs/SETUP.md) | browser and terminal steps, updating, troubleshooting |
| [`docs/CLI.md`](docs/CLI.md) | the commands: flags, exit codes, output |
| [`docs/CONSUMER.md`](docs/CONSUMER.md) | what your repository does to work well in a session |
| [`docs/CACHE-CI.md`](docs/CACHE-CI.md) | the CI job that fills the binary cache from your repository |
| [`docs/EXAMPLE.md`](docs/EXAMPLE.md) | a real repository from zero to a green test run, with timings |
| [`docs/SESSION.md`](docs/SESSION.md) | what happens between `claude --cloud` and the first prompt |
| [`docs/FACTS.md`](docs/FACTS.md) | what a cloud session looks like, measured and dated |
| [`docs/MODEL.md`](docs/MODEL.md) | which model sessions use and how to choose |
| [`docs/FORKING.md`](docs/FORKING.md) | running this with your own cache and names |
| [`docs/RUNBOOK.md`](docs/RUNBOOK.md) | bump Nix, update the script, refill the cache, stop spend |
| [`docs/SECURITY.md`](docs/SECURITY.md) | reporting, and what the attack surface is |
| [`docs/INTEGRATION.md`](docs/INTEGRATION.md) | the gate, step by step |
| [`docs/linter-coverage.md`](docs/linter-coverage.md) | which checks reach which files |
| [`docs/LLM-DISCLAIMER.md`](docs/LLM-DISCLAIMER.md) | how this was built and how to check it |
| [`docs/THIRD-PARTY-NOTICES.md`](docs/THIRD-PARTY-NOTICES.md) | other people's work this depends on |
| [`SPEC.md`](SPEC.md) | the spec and the backlog |
| [`AGENTS.md`](AGENTS.md) | the working guide for agents and humans |
| [`CHANGELOG.md`](CHANGELOG.md) | what changes inside the session VM |

## Reading the specs

`SPEC.md` files are caveman-encoded: the symbols carry meaning.

```
→ leads to    ∴ therefore    ∀ for all    ! must
⊥ never       ? open/optional ≤ at most    ∈ in
```

Sections run `§G` goal, `§F` federation, `§C` constraints, `§I` interfaces,
`§V` invariants, `§T` tasks and `§B` bugs.

## Contributing

- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md): setup, the loop, and the one
  hard rule
- [docs/CODE_OF_CONDUCT.md](docs/CODE_OF_CONDUCT.md)
- [AGENTS.md](AGENTS.md): the working guide, for agents and humans alike

## Security

The setup script runs as root on every fresh session VM. Report problems
privately, as [`docs/SECURITY.md`](docs/SECURITY.md) describes.

## License

MIT, see [`LICENSE`](LICENSE).

Two things this repository depends on are acknowledged in
[`docs/THIRD-PARTY-NOTICES.md`](docs/THIRD-PARTY-NOTICES.md).
