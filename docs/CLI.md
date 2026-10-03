# The command line

This repository ships a few commands for the project you want to send to a
Claude Code cloud session. This page is their reference: flags, exit codes
and what they print. Each one is a bats-covered script under
[`scripts/`](../scripts), and the script's header comment is the source of
truth. If this page and a script disagree, the script is right and this page
has a bug.

| command | what it does | where it runs |
|---|---|---|
| [`inputs`](#inputs) | lists a flake's `github:` inputs as `cached` or `attach` | your machine, in the project |
| [`domains`](#domains) | prints the allowed domains the environment needs | your machine, in the project |
| [`guide`](#guide) | walks the setup steps of [`SETUP.md`](SETUP.md) | your machine, in the project |
| [`probe`](#probe) | starts a cloud session that probes the project and prints its report | your machine, in the project's git checkout |
| [`nix-dev`](#nix-dev) | `nix develop` that survives the GitHub proxy | inside a cloud session |
| [`setup-line.sh`](#setup-linesh) | prints the one-line setup script, for a commit whose CI is green | your machine; a checkout of this repository, or any directory with a full SHA |
| [`bump-nix.sh`](#bump-nixsh) | pins `setup.sh` to another Nix release | a checkout of this repository |
| [`just` recipes](#just-recipes) | the same scripts, run on this repository | a checkout of this repository |

## How to run them

From your own project, run the flake apps straight from GitHub:

```sh
nix run github:pr0d1r2/claudinix#inputs
nix run github:pr0d1r2/claudinix#domains -- --why
nix run github:pr0d1r2/claudinix#guide -- --from 3
nix run github:pr0d1r2/claudinix#probe -- --model opus
```

Everything after `--` goes to the command. The apps are `inputs`, `domains`,
`guide` and `probe`; `nix-dev`, `setup-line.sh` and `bump-nix.sh` are not flake apps. Each
app is the script read verbatim, with its helper programs (`jq`, `curl` and
so on) put on its `PATH`, so the apps behave the same on any machine with
Nix.

In a checkout of this repository you can run the scripts directly
(`scripts/domains.sh`) or through [`just`](#just-recipes).

## Behaviour every command shares

- **Exit codes.** 0 when it did its job. 1 when it could not do it, or, for
  `inputs --check`, when an input must be attached. 2 for a usage error. A
  command that could not run never exits 0 and never prints a result as if it
  had.
- **Streams.** Results go to stdout. Diagnostics and refusals go to stderr,
  so output can be piped.
- **Nothing is written** to your project, to GitHub or to claude.ai. The
  commands read files, ask a binary cache a question, or start a session you
  asked for.
- **Run from the project.** The default directory is the current one.

## inputs

Which of a flake's `github:` inputs a cloud session can get without GitHub.
A `github:` input is fetched as an archive tarball that the session's GitHub
proxy refuses unless the repository is attached to the session. An input
whose source is already in a binary cache is substituted by its hash and
never touches GitHub (see [`FACTS.md`](FACTS.md)).

```text
usage: inputs.sh [--check] [FLAKE_DIR]
```

| argument | meaning |
|---|---|
| `FLAKE_DIR` | the flake to read, default the current directory; it needs a `flake.lock` |
| `--check` | exit 1 when any input must be attached, so a script can gate on it |

| variable | meaning |
|---|---|
| `INPUTS_CACHES` | cache URLs to ask, space-separated; default `https://pr0d1r2.cachix.org https://cache.nixos.org` |

It reads every `github` node of `flake.lock`, nested and deduplicated, asks
`nix flake archive --dry-run --json` for the store paths (this fetches
nothing), and asks each cache whether it has the path's narinfo. One line per
input, `owner/repo rev status`:

```text
NixOS/nixpkgs 774debe7a0d1b496e35677ad955a1011c6ff74f3 cached
pr0d1r2/sherd 3dc05605565777c731f7c7229deef5d77609e9a9 attach
```

`cached` means a cache has the source. `attach` means attach the repository
to the session or routine, or push the input to your cache from CI
([`CACHE-CI.md`](CACHE-CI.md)).

| exit | meaning |
|---|---|
| 0 | the list was printed (with `--check`: every input is cached) |
| 1 | with `--check`, at least one input is `attach`; or nothing could be checked: no such directory, no `flake.lock`, or `nix flake archive` failed |
| 2 | a usage error |

The refusals name what they were given, so a typo is easy to spot, for
example `inputs: no directory /nonexistent -- nothing was checked`.

## domains

The Allowed domains a cloud environment needs. The session proxy refuses
every host not on the list. `domains` prints, one per line and each once:

1. the base list, [`allowlist.txt`](../allowlist.txt) (the Nix hosts and
   `github.com`), in its order;
2. the hosts your projects' files name, sorted. One detector per ecosystem:
   Cargo (`index.crates.io`, `static.crates.io` and git or registry hosts),
   Nix (substituters in `nixConfig`, non-`github` inputs of `flake.lock`),
   git submodules, npm (hosts packages are `resolved` from), Python
   (`pypi.org`, `files.pythonhosted.org` and any other index), Ruby (the
   `remote:` hosts of `Gemfile.lock`) and Go (`proxy.golang.org`,
   `sum.golang.org`);
3. with `--from-log`, hosts a session's proxy refused.

```text
usage: domains.sh [--why] [--from-log FILE]... [PROJECT_DIR...]
```

| argument | meaning |
|---|---|
| `PROJECT_DIR` | a project to scan; repeat it to merge several; default the current directory |
| `--why` | print `host`, a tab, and the source: `base`, the file that named the host, or `log` |
| `--from-log FILE` | add the hosts named in a saved session log; repeatable. It reads `Host not in allowlist: <host>` lines and `CONNECT tunnel failed, response 403` lines that carry a URL |

| variable | meaning |
|---|---|
| `CLAUDINIX_ALLOWLIST` | base list; default `allowlist.txt` beside `scripts/` |
| `CLIPBOARD_TOOLS` | clipboard programs to try in order; default `pbcopy wl-copy xclip` |

The plain output is paste-ready. When a clipboard program is on the machine
the list is also copied to the clipboard, and a note goes to stderr
(`domains: copied 5 hosts to the clipboard (pbcopy)`). It reads files only
and never uses the network.

Run in this repository with `--why`:

```text
pr0d1r2.cachix.org	base
cache.nixos.org	base
channels.nixos.org	base
releases.nixos.org	base
github.com	base
```

Run on a Cargo project with a refused host in a log:

```text
pr0d1r2.cachix.org	base
cache.nixos.org	base
channels.nixos.org	base
releases.nixos.org	base
github.com	base
example.org	log
index.crates.io	p/Cargo.toml
static.crates.io	p/Cargo.toml
```

| exit | meaning |
|---|---|
| 0 | the list was printed |
| 1 | the base list, a project directory or a log could not be read |
| 2 | a usage error |

## guide

Walks the steps of [`SETUP.md`](SETUP.md) from the terminal. The cloud
environment can only be created in the browser, so for each step the guide
says what to do and where, opens the URL, copies the value you paste to the
clipboard, waits for you, and checks locally what it can: the claude.ai
sign-in (`claude auth status`), `remote.defaultEnvironmentId` in your user
settings, and the `github:` inputs to attach (through [`inputs`](#inputs)).
It writes nothing and reads no secret.

```text
usage: guide.sh [--force] [--from STEP] [FLAKE_DIR] | guide.sh update [--force] [FLAKE_DIR]
```

| argument | meaning |
|---|---|
| `FLAKE_DIR` | the project, default the current directory |
| `--from STEP` | resume at step 0 to 5; step 0 (protect your money) always runs first |
| `update` | the "Updating the environment" flow instead of steps 0 to 5 |
| `--force` | passed to [`setup-line.sh`](#setup-linesh), so the guide prints the setup line even when CI for that commit is not green |

| variable | meaning |
|---|---|
| `CLAUDINIX_SCRIPTS` | directory holding `guide-steps.tsv`, `inputs.sh`, `domains.sh` and `setup-line.sh`; default the script's own |
| `CLAUDINIX_SETUP_REV` | the full SHA of this repository to pin the setup line to; default `HEAD` of the clone the guide runs from |
| `CLAUDINIX_MODEL_DOC` | the `MODEL.md` that step 5 reads prices from; default `docs/MODEL.md` beside `scripts/` |
| `CLAUDINIX_ENV_NAMES` | the `env-names.txt` to list; default the one beside `scripts/` |
| `CLAUDE_SETTINGS` | user settings to read; default `~/.claude/settings.json` |
| `CLIPBOARD_TOOLS` | clipboard programs to try in order; default `pbcopy wl-copy xclip` |
| `GUIDE_OPEN_TOOLS` | URL openers to try in order; default `open xdg-open` |

Step titles and URLs come from
[`scripts/guide-steps.tsv`](../scripts/guide-steps.tsv), and a bats test keeps
the titles equal to the `SETUP.md` headings, so the two cannot drift. Step 0
asks you to type `y` for each money check; anything else stops the guide.
Step 5 asks which model to launch with (`sonnet`, the default, or `opus`) and
prints the launch form, with each model's price per million tokens read from
the price table in [`MODEL.md`](MODEL.md) (never a number of the guide's own;
if the file, the row or a dollar amount is missing it prints
`price: see docs/MODEL.md`). Output of step 5, after answering the two money
checks:

```text
== 5. Run a first session and check that it works ==
Pick the session's model. It is fixed at launch: ANTHROPIC_MODEL on the environment does not set it (probe 6).
  sonnet  Claude Sonnet 5.5, the default here: $2.00 input, $10.00 output per million tokens (docs/MODEL.md).
  opus    Claude Opus 5.5, for harder work: $4.00 input, $20.00 output per million tokens (docs/MODEL.md).
Model [sonnet/opus] (Enter: sonnet):
Launch from a checkout of the project, branch pushed (the task comes right after --cloud):
  claude --cloud "<task>" --model sonnet
First check, it works when the output shows a Nix version and DEVSHELL-OK:
  claude --cloud "Run: nix --version && nix develop -c true && echo DEVSHELL-OK. Report the output." --model sonnet
In the browser, use the model picker when you start the session instead.
Which model ran: the Co-Authored-By trailer of the session's commits.
```

Without a clipboard program or an opener, the guide prints the values and
URLs and carries on.

The setup-script value that step 3 copies, and that `update` copies, is the
one line from [`setup-line.sh`](#setup-linesh), not the contents of
`setup.sh`. The guide runs `setup-line.sh` for `CLAUDINIX_SETUP_REV`, else for
`HEAD` of the clone it runs from. If neither gives a revision, or
`setup-line.sh` refuses it because CI for that commit is not green, the guide
stops with exit 1 (`guide: stop here -- ...`); pick a commit CI passed, or
run the guide with `--force`.

| exit | meaning |
|---|---|
| 0 | the steps ran to the end |
| 1 | stopped: a money check at step 0 was not `y`, or there is no setup line to print (no revision, or CI not green and no `--force`) |
| 2 | a usage error: an unknown flag, `--from` outside 0 to 5, or two directories |

## probe

Starts one cloud session that probes the project, then prints the report.
The session runs `probe.sh` and times the dev shell (through
[`nix-dev`](#nix-dev) when it is installed), then pushes a report on a
`claude/nix-probe` branch, to which the cloud adds a random suffix.

```text
usage: probe-launch.sh [--model M] [--cleanup]
```

| argument | meaning |
|---|---|
| `--model M` | the model alias, default `sonnet` (see [`MODEL.md`](MODEL.md)) |
| `--cleanup` | delete every `claude/nix-probe*` branch on the remote and exit; a session cannot delete branches itself |

| variable | meaning |
|---|---|
| `PROBE_REMOTE` | the remote the session pushes to; default `origin` |
| `PROBE_POLL_SECONDS` | wait between branch checks; default `20` |
| `PROBE_POLL_TRIES` | checks before giving up; default `90`, which is 30 minutes |
| `PROBE_SCRIPT` | the `probe.sh` to send; default the one in this repository |

It runs `claude --cloud <task> --model <M>` with the task right after
`--cloud` (the other order fails with `--cloud requires a description`).
`claude` needs a terminal there, so it runs under `script`. Run it from a
git checkout of the project, with your branch pushed, because the session
clones the GitHub copy. After the session starts it waits for a new
`claude/nix-probe*` branch on the remote, fetches it and prints
`nix-probe-report.txt` from it:

```text
probe: branch claude/nix-probe-<suffix>
```

followed by the report. `--cleanup` prints `probe: deleted <branches>`, or
`probe: no claude/nix-probe* branch on origin`.

The probe launcher has not yet been run end to end against a real cloud
session; its logic is tested with stubbed `claude` and `git`.

| exit | meaning |
|---|---|
| 0 | the report was printed; or `--cleanup` finished |
| 1 | not inside a git work tree; no new branch after the last check; or the branch has no `nix-probe-report.txt` |
| 2 | a usage error |

## nix-dev

`nix develop` for the flake in the current directory, for a session whose
GitHub proxy returns 403 for `github:` inputs. It is installed in a session
by [`setup.sh`](../setup.sh) as `/usr/local/bin/nix-dev`, so Claude's Bash
tool finds it. It is not a flake app.

```text
usage: nix-dev [ARGS...]    (ARGS as for `nix develop`)
```

For example `nix-dev --command cargo test`. It tries four tiers in order,
logs each on stderr as `nix-dev: ...`, and runs `nix develop` with the first
tier that works, your arguments after it:

1. **Locked inputs from a cache.** Tried only when every `github` input is
   cached ([`inputs`](#inputs) decides).
2. **Uncached `github` inputs as `git+https://github.com/<owner>/<repo>`**
   at the locked revision, shallow. A git read passes the proxy. nixpkgs is
   left out, because it is too big for it.
3. **`github:` as locked.** Works only for repositories attached to the
   session. Warns.
4. **Tier 2, plus nixpkgs from its channel tarball** on
   `channels.nixos.org`: the lock's `nixos-<version>`, `nixos-unstable` or
   `nixpkgs-unstable` ref, else `nixpkgs-unstable`. Degraded: the revision
   differs from the lock. Warns.

Overrides are never written to `flake.lock`. A tier whose command an earlier
tier already ran is skipped. Without a `flake.lock` or without `jq`, it runs
plain `nix develop` and logs `tier 1`. Log lines look like:

```text
nix-dev: tier 1 skipped: 2 github input(s) in no cache
nix-dev: using tier 2: github inputs as git+https at the locked rev
```

| variable | meaning |
|---|---|
| `CLAUDINIX_SCRIPTS` | directory holding `nix-dev.jq` and `inputs.sh`; default the script's own, symlinks followed |

| exit | meaning |
|---|---|
| (that of `nix develop`) | a tier worked, and its `nix develop` ran |
| 1 | every tier failed; the errors are above it |

`nix-dev` inside a real cloud session has not been run yet.

## setup-line.sh

Prints the one line to paste as the environment's setup script. The line
downloads `setup.sh` at a fixed commit into a fresh temporary directory and
runs it with the same SHA, which pins the agent home to that commit too.

```text
usage: setup-line.sh [--force] [REV]    (default: HEAD)
```

| argument | meaning |
|---|---|
| `REV` | the commit to pin, default `HEAD`; a full 40-hex SHA is used as given and needs no clone, anything else is resolved in the git checkout the script runs in |
| `--force` | print the line even when CI is not green, with a `WARNING` on stderr that says why it should not have |

| variable | meaning |
|---|---|
| `GH_BIN` | the GitHub CLI to ask about CI; default `gh`. It is used read-only |

It needs `git`, `jq` and a signed-in `gh`. The CI rule: only a commit whose
newest `ci.yml` run on `main` is `completed` with conclusion `success` gets a
line, because that run is what pushes the agent home to the binary cache. No
run, a run still going, a failed run, or a `gh` that cannot answer all
refuse, so wait for green CI on `main` before you print the line. The
refusals read:

```text
setup-line: no CI run on main for <sha> (is it pushed and merged?) -- no line printed; pass --force to print it anyway
setup-line: CI on main for <sha> is not green (newest run: <status> <conclusion>) -- no line printed; pass --force to print it anyway
setup-line: could not ask GitHub about CI for <sha> (is gh installed and signed in?) -- no line printed; pass --force to print it anyway
```

The output is one line (the `<sha>` is the 40-hex commit id):

```text
d=$(mktemp -d) && curl -fsSL https://raw.githubusercontent.com/pr0d1r2/claudinix/<sha>/setup.sh -o "$d/setup.sh" && bash "$d/setup.sh" <sha>
```

| exit | meaning |
|---|---|
| 0 | the line was printed (with `--force`, possibly after a warning) |
| 1 | `REV` is not a commit (`setup-line: cannot resolve <REV> to a commit -- no line printed`), or CI is not green and `--force` was not given |
| 2 | a usage error: an unknown flag or more than one `REV` |

`setup.sh` itself is `setup.sh [SHA]`: the one optional argument must be a
full 40-hex commit id, or it exits 2 with
`usage: setup.sh [SHA] -- SHA is a full 40-hex commit id`. Everything
owner-specific in it (`cache_host`, `cache_key` and `repo`) sits in the fork
config block at its top ([`FORKING.md`](FORKING.md)). The fetch of `setup.sh`
from `raw.githubusercontent.com` during a real cloud session's setup has not
been tried yet.

## bump-nix.sh

Pins `setup.sh` to another Nix release. It fetches the installer hash that
releases.nixos.org publishes for the version, and rewrites `version=` and the
default installer `sha256` together, so they only ever change in one commit.
It runs nothing else: you review the diff, run the gate and commit
([`RUNBOOK.md`](RUNBOOK.md)).

```text
usage: bump-nix.sh VERSION   (MAJOR.MINOR.PATCH, e.g. 2.36.0)
```

| variable | meaning |
|---|---|
| `BUMP_SETUP` | the `setup.sh` to rewrite; default the one in the repository root |
| `NIX_RELEASES_URL` | where releases are fetched from; default `https://releases.nixos.org/nix` |

On success it prints `bump-nix: setup.sh now pins Nix <version>, installer sha256 <hash>`.
A refusal prints `bump-nix: <reason> -- setup.sh not changed`: the file needs
exactly one `version=` line and one default `sha256` line, the fetch failed,
or the answer was not one 64-hex hash.

| exit | meaning |
|---|---|
| 0 | `setup.sh` was rewritten |
| 1 | it could not be rewritten, and `setup.sh` is unchanged |
| 2 | a usage error: not exactly one argument, or a version that is not `MAJOR.MINOR.PATCH` |

## just recipes

The [`justfile`](../justfile) runs the same scripts on this repository.
Arguments pass through, and each recipe is one plain command.

| recipe | runs |
|---|---|
| `just inputs [args]` | `scripts/inputs.sh` |
| `just domains [args]` | `scripts/domains.sh` |
| `just guide [args]` | `scripts/guide.sh`; `just guide update` for the update flow |
| `just probe [args]` | `scripts/probe-launch.sh` |
| `just bump-nix <version>` | `scripts/bump-nix.sh` |

`just --list` shows the five. There is no recipe for `nix-dev` or
`setup-line.sh`: run `scripts/setup-line.sh` directly.
