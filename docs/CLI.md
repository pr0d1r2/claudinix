# The command line

This repository ships a few commands for the project you want to send to a
Claude Code cloud session. This page is their reference: flags, exit codes
and what they print. Each one is a bats-covered script under
[`scripts/`](../scripts), and the script's header comment is the source of
truth. If this page and a script disagree, the script is right and this page
has a bug.

| command | what it does | where it runs |
|---|---|---|
| [`inputs`](#inputs) | lists a flake's `github:` inputs as `cached` or `uncached` | your machine, in the project |
| [`domains`](#domains) | prints the allowed domains the environment needs | your machine, in the project |
| [`guide`](#guide) | walks the setup steps of [`SETUP.md`](SETUP.md) | your machine, in the project |
| [`probe`](#probe) | starts a billed cloud session that probes the project and prints its report | your machine, in the project's git checkout |
| [`cloud`](#cloud) | builds one task of this repository's spec in a billed cloud session | your machine, in the project's git checkout |
| [`rebase`](#rebase) | rebases one `claude/*` pull request onto `main` in a billed cloud session | your machine, in the project's git checkout |
| [`review`](#review) | reviews one pull request as one role, or as every role at once, in billed read-only cloud sessions | your machine, in the project's git checkout |
| [`config.sh`](#configsh) | reads and checks a project's optional [`.claudinix.toml`](CONFIG.md) | your machine or a session, in the project |
| [`nix-dev`](#nix-dev) | `nix develop` that survives the GitHub proxy | inside a cloud session |
| [`setup.sh`](#setupsh) | the environment's setup script | a cloud session's VM, through the setup line |
| [`setup-line.sh`](#setup-linesh) | prints the one-line setup script, for a commit whose CI is green | your machine; a checkout of this repository, or any directory with a full or short SHA |
| [`bump-nix.sh`](#bump-nixsh) | pins `setup.sh` to another Nix release | a checkout of this repository |
| [`release.sh`](#releasesh) | cuts a release in two steps: record the agent home, then publish | a checkout of this repository (maintainer) |
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
`guide` and `probe`; `nix-dev`, `setup.sh`, `setup-line.sh` and `bump-nix.sh` are not flake apps. Each
app is the script read verbatim, with its helper programs (`jq`, `curl` and
so on) put on its `PATH`, so the apps behave the same on any machine with
Nix.

In a checkout of this repository you can run the scripts directly
(`scripts/domains.sh`) or through [`just`](#just-recipes).

## Behaviour every command shares

- **Exit codes.** 0 when it did its job. 1 when it could not do it, or, for
  `inputs --check`, when an input is uncached. 2 for a usage error. A
  command that could not run never exits 0 and never prints a result as if it
  had.
- **Streams.** Results go to stdout. Diagnostics and refusals go to stderr,
  so output can be piped.
- **Nothing is written** to your project, to GitHub or to claude.ai, with
  one exception: `probe --cleanup` deletes the remote `claude/nix-probe*`
  branches. The commands read files, ask a binary cache a question, or
  start a session you asked for.
- **Run from the project.** The default directory is the current one.
- **One optional config file.** `domains`, `inputs`, `guide`, `probe`,
  `nix-dev` and `ci/verify-cachix.sh` read the project's
  [`.claudinix.toml`](CONFIG.md) for their defaults. A flag or an
  environment variable wins over it, and without the file nothing changes.
  A bad file stops the command with exit 2, naming the file and the key.

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
| `--check` | exit 1 when any input is uncached, so a script can gate on it |

| variable | meaning |
|---|---|
| `INPUTS_CACHES` | cache URLs to ask, space-separated; default `https://<cache.name>.cachix.org https://cache.nixos.org`, where `cache.name` comes from the `.claudinix.toml` in `FLAKE_DIR` and is `pr0d1r2` without one |
| `CLAUDINIX_SCRIPTS` | directory holding `inputs.jq` and `config.sh`; default the script's own |

Keys read from [`.claudinix.toml`](CONFIG.md): `cache.name`. A directory
without `config.sh` beside `inputs.sh` (an older `nix-dev` install) reads no
file and uses `pr0d1r2`.

It reads every `github` node of `flake.lock`, nested and deduplicated, asks
`nix flake archive --dry-run --json` for the store paths (this fetches
nothing), and asks each cache whether it has the path's narinfo. One line per
input, `owner/repo rev status`:

```text
NixOS/nixpkgs 774debe7a0d1b496e35677ad955a1011c6ff74f3 cached
pr0d1r2/sherd 3dc05605565777c731f7c7229deef5d77609e9a9 uncached
```

`cached` means a cache has the source. `uncached` means no cache has it, so a
session would have to fetch it from GitHub. When any input is uncached, one
line on stderr says what to do:

```text
inputs: uncached inputs come from GitHub: nix-dev fetches them over git, or rewrite each as git+https://github.com/<owner>/<repo> in flake.nix
```

Or push the input to your cache from CI ([`CACHE-CI.md`](CACHE-CI.md)).

| exit | meaning |
|---|---|
| 0 | the list was printed (with `--check`: every input is cached) |
| 1 | with `--check`, at least one input is `uncached`; or nothing could be checked: no such directory, no `flake.lock`, or `nix flake archive` failed |
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
3. each project's `network.extra_domains` from its own [`.claudinix.toml`](CONFIG.md) (with several project directories, each one's file), sorted in with 2;
4. with `--from-log`, hosts a session's proxy refused.

```text
usage: domains.sh [--why] [--from-log FILE]... [PROJECT_DIR...]
```

| argument | meaning |
|---|---|
| `PROJECT_DIR` | a project to scan; repeat it to merge several; default the current directory |
| `--why` | print `host`, a tab, and the source: `base`, the file that named the host, `config` (a `network.extra_domains` entry) or `log` |
| `--from-log FILE` | add the hosts named in a saved session log; repeatable. It reads `Host not in allowlist: <host>` lines and `CONNECT tunnel failed, response 403` lines that carry a URL |

| variable | meaning |
|---|---|
| `CLAUDINIX_ALLOWLIST` | base list; default `allowlist.txt` beside `scripts/` |
| `CLAUDINIX_CONFIG_JSON` | internal: a config a caller already read; used only when one project directory is given, so with several directories each project's own file is read |
| `CLAUDINIX_SCRIPTS` | directory holding the `domains/` detectors and `config.sh`; default the script's own |
| `CLIPBOARD_TOOLS` | clipboard programs to try in order; default `pbcopy wl-copy xclip` |

The plain output is paste-ready. When a clipboard program is on the machine
the list is also copied to the clipboard, and a note goes to stderr
(`domains: copied 6 hosts to the clipboard (pbcopy)`). It reads files only
and never uses the network. Keys read from `.claudinix.toml`:
`network.extra_domains`; a bad file exits 2.

Run in this repository with `--why`:

```text
pr0d1r2.cachix.org	base
cache.nixos.org	base
channels.nixos.org	base
releases.nixos.org	base
github.com	base
raw.githubusercontent.com	base
```

Run on a Cargo project with a refused host in a log:

```text
pr0d1r2.cachix.org	base
cache.nixos.org	base
channels.nixos.org	base
releases.nixos.org	base
github.com	base
raw.githubusercontent.com	base
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
settings, and the `github:` inputs no cache holds (through
[`inputs`](#inputs)). It writes nothing and reads no secret.

```text
usage: guide.sh [--force] [--[no-]agent-home] [--rev SHA] [--from STEP] [FLAKE_DIR] | guide.sh update [--force] [--[no-]agent-home] [--rev SHA] [FLAKE_DIR]
```

| argument | meaning |
|---|---|
| `FLAKE_DIR` | the project, default the current directory |
| `--from STEP` | resume at step 0 to 5; step 0 (protect your money) always runs first |
| `update` | the "Updating the environment" flow instead of steps 0 to 5 |
| `--rev SHA` | copy a line for this commit of claudinix instead of the release's, printed by [`setup-line.sh`](#setup-linesh) (needs `gh`, signed in); use it before the first release or to pin another commit. A full 40-character SHA or a short one of at least 7 (`c63d695`), which `setup-line.sh` looks up on GitHub |
| `--force` | with `--rev`, passed to [`setup-line.sh`](#setup-linesh), so the guide prints the setup line even when CI for that commit is not green |
| `--agent-home` | the line it copies ends in ` --agent-home`, exactly as [`setup-line.sh`](#setup-linesh) appends it, and opts in to the agent home (see the [README](../README.md#the-agent-home-is-opt-in)); without it the line installs Nix and `nix-dev` only |
| `--no-agent-home` | the opposite: the line has no ` --agent-home`, even when `session.agent_home` in `.claudinix.toml` is `true` |

| variable | meaning |
|---|---|
| `CLAUDINIX_CONFIG_JSON` | internal: `guide` sets it from the file it read, so the tools it calls do not read it again |
| `CLAUDINIX_SCRIPTS` | directory holding `guide-steps.tsv`, `inputs.sh`, `domains.sh`, `setup-line.sh` and `config.sh`; default the script's own |
| `CLAUDINIX_README` | the `README.md` whose setup-line block holds the release's line; default the one beside `scripts/` (the flake app sets it to the README of the commit it was built from) |
| `CLAUDINIX_SETUP_REV` | the maintainer path: a full or short SHA of this repository to print the line for with `setup-line.sh`, as `--rev` does; `--rev` wins over it; unset by default |
| `CLAUDINIX_MODEL_DOC` | the `MODEL.md` that step 5 reads prices from; default `docs/MODEL.md` beside `scripts/` |
| `CLAUDINIX_ENV_NAMES` | the `env-names.txt` to list; default the one beside `scripts/` |
| `CLAUDE_SETTINGS` | user settings to read; default `~/.claude/settings.json` |
| `CLIPBOARD_TOOLS` | clipboard programs to try in order; default `pbcopy wl-copy xclip` |
| `GUIDE_OPEN_TOOLS` | URL openers to try in order; default `open xdg-open` |
| `GH_BIN` | the GitHub CLI asked, read-only, for the newest green `main` commit before the first release; default `gh` |

Keys read from [`.claudinix.toml`](CONFIG.md) in `FLAKE_DIR`, before step 0:
`session.model` (the default answer in step 5), `session.agent_home` (the
default for `--agent-home`; `--agent-home` and `--no-agent-home` win) and
`devshell.installable` (the first check runs `nix-dev <installable> -c true`
instead of `nix-dev -c true`; the installable is shell-quoted when it needs it, so `.#ci` prints unchanged). A bad file stops the guide with exit 2.

Step titles and URLs come from
[`scripts/guide-steps.tsv`](../scripts/guide-steps.tsv), and a bats test keeps
the titles equal to the `SETUP.md` headings, so the two cannot drift. Step 0
asks two money questions. Each needs `y`, except the credit question, which
also accepts `none` if you were offered no credit; anything else stops the
guide. Step 3 asks for the environment's name; Enter keeps the project's name
(the name of its git top directory). Steps 4 and `update` use that name, and
step 4, after `/remote-env`, offers to pin the environment in the project's
`.claude/settings.local.json` (Enter accepts; other keys stay; a file that is
not a JSON object is left alone; it warns when git does not ignore the file).
That file is the only one the guide writes. guide. Step 5 asks which model to launch with (`sonnet`, the default, or
`opus`), lists the GitHub inputs no cache holds with what to do about them,
and prints the launch lines, with each model's price per million tokens read
from the price table in [`MODEL.md`](MODEL.md) (never a number of the
guide's own; if the file, the row or a dollar amount is missing it prints
`price: see docs/MODEL.md`). Output of step 5, after answering the two money
checks, for a project whose inputs are all cached:

```text
== 5. Run a first session and check that it works ==
Pick the session's model. It is fixed at launch: ANTHROPIC_MODEL on the environment does not set it (measured, see docs/FACTS.md).
  sonnet  Claude Sonnet 5.5, the default here: $2.00 input, $10.00 output per million tokens (docs/MODEL.md).
  opus    Claude Opus 5.5, for harder work: $4.00 input, $20.00 output per million tokens (docs/MODEL.md).
Model [sonnet/opus] (Enter: sonnet):
Before you launch: GitHub inputs no cache holds (a session must fetch them from GitHub):
  every github input is in a cache: nothing comes from GitHub.
Launch from a checkout of the project (/path/to/project), branch pushed (the task comes right after --cloud):
  claude --cloud "<task>" --model sonnet
First check, it works when the output shows a Nix version and DEVSHELL-OK:
  claude --cloud "Run: nix --version && nix-dev -c true && echo DEVSHELL-OK. Report the output." --model sonnet
In the browser, use the model picker when you start the session instead.
Which model ran: the Co-Authored-By trailer of the session's commits.
```

When some inputs are uncached, the second block instead lists them and says:

```text
  nix-dev fetches these over git, so start the dev shell with nix-dev;
  or rewrite each as git+https://github.com/<owner>/<repo> in flake.nix.
```

Without a clipboard program or an opener, the guide prints the values and
URLs and carries on.

The setup-script value that step 3 copies, and that `update` copies, is the
one line the release published in the README's setup-line block, not the
contents of `setup.sh`; reading it needs neither `gh` nor a clone. Before the
first release that block holds no line, and the guide stops with exit 1.
When `gh` can tell, it names the newest `main` commit whose CI passed, so
you can run it again with that `--rev`:

```text
guide: stop here -- no release yet, so there is no published setup line to copy. The newest green main commit is <sha12>: run the guide again with --rev <sha12> (needs gh signed in), or wait for the first release
```

Without `gh`, or when it does not answer, the stop reads:

```text
guide: stop here -- no release yet, so there is no published setup line to copy. Run the guide again after the first release, or pass --rev SHA (a claudinix commit CI passed; needs gh signed in) to print a line for that commit
```

If the README is missing, or its block holds neither a line nor the
placeholder, the guide stops with exit 1 and names the file:

```text
guide: stop here -- no README at <file> to copy the release's setup line from; copy the line from https://github.com/pr0d1r2/claudinix#readme, or pass --rev SHA (a claudinix commit CI passed; needs gh signed in)
guide: stop here -- no setup line in the setup-line block of <file>; copy the line from https://github.com/pr0d1r2/claudinix#readme, or pass --rev SHA (a claudinix commit CI passed; needs gh signed in)
```

With `--rev SHA` (or `CLAUDINIX_SETUP_REV`) the guide runs `setup-line.sh` for
that SHA instead. If it refuses because CI for that commit is not green (or
`gh` cannot answer), the guide stops with exit 1:

```text
guide: stop here -- no setup line for <sha> (see above); pick a SHA CI passed, or run the guide with --force
```

| exit | meaning |
|---|---|
| 0 | the steps ran to the end |
| 1 | stopped: a money check at step 0 was not accepted, there is no setup line to copy (no release yet, no README block, or with `--rev` CI not green and no `--force`), or the project directory does not exist (`guide: no directory <dir> -- nothing was checked`) |
| 2 | a usage error: an unknown flag, `--from` outside 0 to 5, `--rev` with anything but 7 to 40 hex characters (`guide: --rev wants a claudinix commit SHA (7 to 40 hex characters), got <value>`), or two directories |

## probe

Starts one cloud session that probes the project, then prints the report.
The session runs `probe.sh` and times the dev shell (through
[`nix-dev`](#nix-dev) when it is installed), then pushes a report on a
`claude/nix-probe` branch, to which the cloud adds a random suffix. **It
starts a billed session**, so it asks first.

```text
usage: probe-launch.sh [--model M] [--yes] [--cleanup]
```

| argument | meaning |
|---|---|
| `--model M` | the model alias, default `session.model` from `.claudinix.toml`, else `sonnet` (see [`MODEL.md`](MODEL.md)) |
| `--yes` | skip the y/N question; every other check still runs |
| `--cleanup` | delete every `claude/nix-probe*` branch on the remote and exit; a session cannot delete branches itself |

| variable | meaning |
|---|---|
| `PROBE_REMOTE` | the remote the session pushes to; default `origin` |
| `PROBE_POLL_SECONDS` | wait between branch checks; default `20` |
| `PROBE_POLL_TRIES` | checks before giving up; default `90`, which is 30 minutes |
| `PROBE_SCRIPT` | the `probe.sh` to send; default the one in this repository |
| `CLAUDINIX_SCRIPTS` | directory holding `probe-prompt.txt` and `config.sh`; default the script's own |

Keys read from [`.claudinix.toml`](CONFIG.md) (at the top level of the git
repository you run it in): `session.model`, `probe.branch_prefix` and
`devshell.installable`. `--model` wins. The installable and the branch prefix are quoted with `printf %q` before they go into the task text. The task text,
[`probe-prompt.txt`](../scripts/probe-prompt.txt), is a template with three
placeholders that the launcher fills before it sends the task:

| placeholder | becomes |
|---|---|
| `@NIX_DEV@` | `nix-dev`, or `nix-dev <installable>` when `devshell.installable` is not `.` |
| `@NIX_DEVELOP@` | `nix develop`, or `nix develop <installable>` |
| `@BRANCH_PREFIX@` | `probe.branch_prefix`, default `claude/nix-probe` |

A bad file exits 2 before anything starts. The branch the session pushes
and `--cleanup` match is `claude/nix-probe` unless the file changes it.

Before it starts a session it checks that the session can see what you see.
The session clones the GitHub copy of your branch, so the launcher refuses
when that copy is not there:

```text
probe: not inside a git work tree -- run it from the project the session clones
probe: no remote origin -- push the project to GitHub first
probe: HEAD is detached -- check out the branch the session should clone
probe: branch <branch> is not pushed (no upstream) -- push it first: git push -u origin <branch>
probe: branch <branch> is not up to date with <upstream> -- push (or pull) first
```

Then it asks:

```text
probe: this starts a billed Claude Code cloud session (model sonnet) from <branch>. Start it? [y/N]
```

Anything but `y`, `Y` or `yes` prints `probe: not started` and exits 1.

It runs `claude --cloud <task> --model <M>` with the task right after
`--cloud` (the other order fails with `--cloud requires a description`).
`claude` needs a terminal there, so it runs under `script`. After the session
starts it waits for a new `claude/nix-probe*` branch on the remote, fetches
it and prints `nix-probe-report.txt` from it:

```text
probe: branch claude/nix-probe-<suffix>
```

followed by the report. `--cleanup` prints `probe: deleted <branches>`, or
`probe: no claude/nix-probe* branch on origin`. Follow-ups to a running
session go through `claude -p MSG --cloud ID`.

The probe launcher has not yet been run end to end against a real cloud
session; its logic is tested with stubbed `claude` and `git`.

| exit | meaning |
|---|---|
| 0 | the report was printed; or `--cleanup` finished |
| 1 | a refusal above, or the answer was not yes; no new branch after the last check; or the branch has no `nix-probe-report.txt` |
| 2 | a usage error |

## cloud

Builds one task of this repository's spec in a fresh cloud session, started
from your terminal. **It starts a billed session**, so it asks first.

```text
usage: cloud-task.sh <node:Tn | Tn> [--model M] [--yes] [--dry-run]
```

Run it as `scripts/cloud-task.sh ...` or `just cloud ...`.

| argument | meaning |
|---|---|
| `Tn` or `node:Tn` | the task to build, for example `T100` or `scripts:T98` |
| `--model M` | the model alias; see the order below |
| `--yes` | skip the billed y/N question; every other check still runs |
| `--dry-run` | run the same checks, then print the command instead of asking or launching |

| variable | meaning |
|---|---|
| `CLOUD_TASK_REMOTE` | the remote that must hold the branch; default `origin` |
| `CLAUDINIX_SCRIPTS` | directory holding `cloud-task-prompt.txt` and `config.sh`; default the script's own |

**How a task is found.** Tasks live in the `§T` table of each node's
`SPEC.md`. A bare `Tn` is looked up in the root `SPEC.md` and in every node
that the root `§F` table lists. `node:Tn` looks only in that node's
`SPEC.md`; `root:Tn` and `.:Tn` mean the root. Exactly one row must match,
and its status must be `.` (open).

**The model.** `--model` wins, then `session.model` from
[`.claudinix.toml`](CONFIG.md), then `sonnet`. A bad file exits 2 before
anything starts.

**The refusals.** Each is printed on stderr and exits 1 (the task is shown
as you typed it):

```text
cloud: not inside a git work tree -- run it from the project the session clones
cloud: no SPEC.md at <top> -- the tasks live in the project's spec
cloud: no node <node> in SPEC.md §F (nodes: <list>)
cloud: no task <arg> in <node>/SPEC.md
cloud: no task <arg> in any node's SPEC.md (<list>)
cloud: <arg> is in more than one node (<nodes>) -- name one, e.g. <node>:<Tn>
cloud: <arg> is done (x) in <spec> -- nothing to build
cloud: <arg> is in progress (~) in <spec> -- finish or reset it first
cloud: <arg> has status <s> in <spec>, not . (open) -- nothing to build
cloud: no remote origin -- push the project to GitHub first
cloud: HEAD is detached -- check out the branch the session should clone
cloud: branch <branch> is not pushed (no upstream) -- push it first: git push -u origin <branch>
cloud: branch <branch> is not up to date with <upstream> -- push (or pull) first
```

A bad task argument exits 2 with `cloud: bad task <arg> -- want Tn or
node:Tn (e.g. T100, scripts:T98)`. An unknown flag, a missing task or a
second task exits 2 with `usage: cloud-task.sh <node:Tn | Tn> [--model M]
[--yes] [--dry-run]`. The session clones GitHub, not your disk, which is
why the branch must be pushed and equal to its upstream.

Then it asks:

```text
cloud: this starts a billed Claude Code cloud session (model sonnet) for <node>:<Tn> from <branch>. Start it? [y/N]
```

Anything but `y`, `Y` or `yes` prints `cloud: not started` and exits 1.

**`--dry-run`** prints one shell-quoted line you can paste, and launches
nothing:

```text
claude --cloud <prompt> --model <M>
```

**What the session is told.** The prompt is
[`cloud-task-prompt.txt`](../scripts/cloud-task-prompt.txt) with the task,
node, branch and the spec row filled in. It says: follow `AGENTS.md`, build
exactly this task (RED, GREEN, status flip), run the gate, push the branch,
open a pull request into `main` without merging it, and report. The session pushes `claude/<node>-<task>`, with `root` as the
node name for the root, for example `claude/scripts-T98` or
`claude/root-T103`. The harness may add a suffix. It then opens a pull request into `main`,
titled after its feat or fix commit, and never merges it.

**It does not wait.** After the session starts it prints:

```text
cloud: started <node>:<Tn>; it pushes claude/<node>-<Tn> (the harness may add a suffix) and opens a pull request -- follow it at claude.ai/code
```

A build outlasts a launcher, so follow the session at
[claude.ai/code](https://claude.ai/code).

Unattended runs may still hit permission prompts; see
[`FACTS.md`](FACTS.md) once measured.

| exit | meaning |
|---|---|
| 0 | the session was started, or `--dry-run` printed the command |
| 1 | a refusal above, or the answer was not yes |
| 2 | a usage error, a bad task argument, or a bad `.claudinix.toml` |

## rebase

Rebases one open `claude/*` pull request onto `main` in a fresh cloud
session, started from your terminal. Use it when a cloud agent's pull
request conflicts after `main` moved on. **It starts a billed session**,
so it asks first.

```text
usage: cloud-rebase.sh <PR# | URL> [--model M] [--yes] [--dry-run]
```

Run it as `scripts/cloud-rebase.sh ...` or `just rebase ...`, for example
`just rebase 8` or `just rebase https://github.com/pr0d1r2/claudinix/pull/8`.
`--model`, `--yes`, `--dry-run`, `CLOUD_TASK_REMOTE` and the model order
work as in [`cloud`](#cloud); `CLAUDINIX_SCRIPTS` holds
`cloud-rebase-prompt.txt`.

**The pull request.** `gh pr view` must find it open, on a `claude/*`
branch (the only branches a cloud session may push) and based on `main`.
Otherwise it exits 1 before a session starts:

```text
rebase: gh could not read pull request #<n> -- check the number and that gh is signed in
rebase: #<n> is <STATE>, not OPEN -- nothing to rebase
rebase: #<n>'s branch is <branch>; a cloud session may push only claude/* branches
rebase: #<n> targets <base>, not main -- rebase it by hand
```

The current branch must be pushed and equal to its upstream, as for
`cloud`, and the same y/N question comes before the billed session.

**What the session is told.** The prompt is
[`cloud-rebase-prompt.txt`](../scripts/cloud-rebase-prompt.txt) with the
pull request, its URL and branch filled in. The session rebases the branch
onto `main`. It takes either side of a conflict in a generated file and
re-writes it with `claudinix-dev badges|steps|notices --write`, rather than
merging generated lines by hand. A conflict that needs a decision makes it
abort the rebase and report, pushing nothing. Otherwise it runs the gate
and pushes with `git push --force-with-lease origin HEAD:<branch>`. It
opens no new pull request and merges nothing.

**It does not wait.** After the session starts it prints:

```text
cloud: started the rebase of #<n> (<branch>) onto main; it force-pushes <branch> with a lease -- follow it at claude.ai/code
```

| exit | meaning |
|---|---|
| 0 | the session was started, or `--dry-run` printed the command |
| 1 | a refusal above, or the answer was not yes |
| 2 | a usage error, a bad pull request argument, or a bad `.claudinix.toml` |

## review

Reviews one open pull request as one role, or as every role at once, in
fresh read-only cloud sessions started from your terminal. **Each session
is billed**, so it asks first.

```text
usage: cloud-review.sh <ROLE | all> <PR# | URL> [--model M] [--yes] [--dry-run]
```

Run it as `scripts/cloud-review.sh ...` or `just review ...`, for example
`just review security 8` or `just review all 8`. `--model`, `--yes`,
`--dry-run`, `CLOUD_TASK_REMOTE` and the model order work as in
[`cloud`](#cloud). `CLAUDINIX_SCRIPTS` holds `review/`,
`cloud-review-prompt.txt` and `config.sh`.

**The roles.** Each role is one file, `scripts/review/<role>.md`. Its first
line is a `# ` title, and the rest tells the reviewer what to look for. The
first roles are `correctness`, `maintainability`, `extensibility`,
`performance`, `security` and `architecture`. To add a role, add a file:
the launcher and its tests read the directory, so no code changes. A role
file may contain `@`, even a placeholder such as `@PR@`: it reaches the
session as written. `all` is not a role name. An unknown role
exits 2 and lists the roles:

```text
review: no role <role> -- roles: <list>, or all (each role is a file in scripts/review/)
```

**The pull request.** `gh pr view` must find it open; any head branch will
do, since the session pushes nothing. Otherwise it exits 1:

```text
review: gh could not read pull request #<n> -- check the number and that gh is signed in
review: #<n> is <STATE>, not OPEN -- nothing to review
```

Unlike `cloud`, it needs only the remote (`origin`, or `CLOUD_TASK_REMOTE`):
the session fetches the pull request's branch from GitHub, so the branch
checked out here may be unpushed, behind or detached.

**One role** asks:

```text
review: this starts a billed Claude Code cloud session (model sonnet) for a <role> review of #<n> (<branch>). Start it? [y/N]
```

**`all`** starts one session per role and asks once, naming the count:

```text
review: this starts 6 billed Claude Code cloud sessions at once (model sonnet), one per role, each reviewing #<n> (<branch>) and posting one comment:
  architecture
  correctness
  ...
Each session is billed on its own. Start all 6? [y/N]
```

Anything but `y`, `Y` or `yes` prints `review: not started`, exits 1 and
starts nothing. `--dry-run` prints one command per session.

**What each session is told.** The prompt is
[`cloud-review-prompt.txt`](../scripts/cloud-review-prompt.txt) with the
pull request and the role's file filled in. The session reads `AGENTS.md`,
the specs and the diff, and reviews as that role only. It reports findings
it can point at (file and line, what goes wrong, a fix), most severe first,
and posts them as one comment headed `Review: <role>`. If it cannot post,
the findings go in its report. It commits, pushes and edits nothing, and it
does not approve, request changes on or merge the pull request.

**It does not wait.** It prints, for one role or for `all`:

```text
cloud: started the <role> review of #<n> (<branch>); it comments on the pull request -- follow it at claude.ai/code
cloud: started 6 review sessions for #<n> (<branch>): <roles>; each comments on the pull request -- follow them at claude.ai/code
```

| exit | meaning |
|---|---|
| 0 | the sessions were started, or `--dry-run` printed the commands |
| 1 | a refusal above, or the answer was not yes |
| 2 | a usage error, an unknown role, a bad pull request argument, or a bad `.claudinix.toml` |

## config.sh

The one reader of a project's optional [`.claudinix.toml`](CONFIG.md); every
tool above goes through it. It is not a flake app and is installed beside
`nix-dev` by [`setup.sh`](#setupsh).

```text
usage: config.sh [--dir DIR] get TABLE.KEY | json | check
```

| argument | meaning |
|---|---|
| `--dir DIR` | read `.claudinix.toml` at the git top level of DIR, else in DIR itself; default `CLAUDINIX_CONFIG`, else the git top level of the current directory, else the current directory |
| `get TABLE.KEY` | print one value, for example `session.model`; a list prints one item per line |
| `json` | print the effective config (the file over the defaults) as JSON |
| `check` | print nothing; exit 0 when the file is valid or absent |

| variable | meaning |
|---|---|
| `CLAUDINIX_CONFIG_JSON` | internal: the effective config a calling tool already read (`json`'s output); used as it is after the same checks, with no file read and no `nix` call, and it comes before `--dir` |
| `CLAUDINIX_CONFIG` | the file to read when no `--dir` is given; it is not consulted with `--dir` |
| `CLAUDINIX_SCRIPTS` | directory holding `config.jq`; default the script's own |

Which tool reads which key:

| key | read by |
|---|---|
| `session.model` | `guide`, `probe` |
| `session.agent_home` | `guide` |
| `devshell.installable` | `nix-dev`, `guide`, `probe` |
| `network.extra_domains` | `domains` |
| `cache.name` | `inputs`, `ci/verify-cachix.sh` |
| `cache.push_sources` | nobody yet |
| `probe.branch_prefix` | `probe` |

`ci/verify-cachix.sh` builds its cache URL as `https://<cache.name>.cachix.org`
unless `CACHIX_URL` is set; it reads the file in the `--sources` directory
when that is a local directory, else the current repository's.

| exit | meaning |
|---|---|
| 0 | the value or the config was printed, or `check` passed |
| 1 | `jq` or `nix` is missing, or `jq` failed |
| 2 | a usage error, an unknown key, a missing directory, or an invalid file |

Keys, defaults, precedence and the error messages are in
[`CONFIG.md`](CONFIG.md).

## nix-dev

`nix develop` for the flake in the current directory, for a session whose
GitHub proxy returns 403 for `github:` inputs. It is installed in a session
by [`setup.sh`](#setupsh) as `/usr/local/bin/nix-dev`, so Claude's Bash
tool finds it. It is not a flake app.

```text
usage: nix-dev [INSTALLABLE] [ARGS...]   (as for `nix develop`)
```

A first argument that does not start with `-` is the installable (for example
`.#ci`); it goes to every tier and to the final `nix develop`, and the lock
of its flake directory is the one read. Everything else goes to the final
`nix develop`, for example `nix-dev --command cargo test` or
`nix-dev .#ci -c true`. It tries four tiers in order, logs each on stderr as
`nix-dev: ...`, and runs `nix develop` with the first tier that works:

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

Without an installable, `nix-dev` uses `devshell.installable` from the
project's [`.claudinix.toml`](CONFIG.md) (read at the top level of the git
repository), unless it is `.`, which is a bare `nix develop`. It logs the
choice, for example with `installable = ".#default"`:

```text
nix-dev: installable .#default from .claudinix.toml (devshell.installable)
```

An installable you give wins and logs nothing about the file. A bad file
does not stop `nix-dev`: it prints what is wrong, then warns and runs as if
there were no file:

```text
nix-dev: WARNING: /work/app/.claudinix.toml is invalid -- using defaults (the repo's gate refuses it at commit)
```

Without `jq`, or with an older install that has no `config.sh`,
no file is read.

Overrides are never written to `flake.lock`. A tier whose command an earlier
tier already ran is skipped, and a failed tier logs nix's first `error:` line.
Without a `flake.lock`, or with an installable that is not a local flake
directory, it runs plain `nix develop` and logs `tier 1`. Without `jq` there
is no failover at all, and it says so:

```text
nix-dev: WARNING: jq is not on PATH -- failover is off, running plain nix develop as tier 1 (install jq for the scripts:V13 tiers)
```

Log lines look like:

```text
nix-dev: tier 1 skipped: 2 github input(s) in no cache
nix-dev: using tier 2: github inputs as git+https at the locked rev
```

| variable | meaning |
|---|---|
| `CLAUDINIX_CONFIG_JSON` | internal: `nix-dev` sets it for `inputs.sh`, so the file is read once |
| `CLAUDINIX_SCRIPTS` | directory holding `nix-dev.jq`, `inputs.sh` and `config.sh`; default the script's own, symlinks followed |

| exit | meaning |
|---|---|
| (that of `nix develop`) | a tier worked, and its `nix develop` ran |
| 1 | every tier failed; the errors are above it |

`nix-dev` inside a real cloud session has not been run yet.

## setup-line.sh

Prints the one line to paste as the environment's setup script. Each release
publishes that line in the README and its release notes, so most users never
run this; it is for maintainers and for pinning another commit. The line
downloads `setup.sh` at a fixed commit into a fresh temporary directory and
runs it with the same SHA, which pins the agent home to that commit too.

```text
usage: setup-line.sh [--force] [--agent-home] [REV]
```

| argument | meaning |
|---|---|
| `REV` | the commit to pin, default `HEAD`; a full 40-hex SHA is used as given and needs no clone; a short SHA (7 to 39 hex) is looked up on GitHub in `pr0d1r2/claudinix`, never in the local checkout, which may be another project; anything else (`HEAD~1`, a branch) is resolved in the git checkout the script runs in |
| `--force` | print the line even when CI is not green, with a `WARNING` on stderr that says why it should not have |
| `--agent-home` | append `--agent-home` to the printed line, which opts in to the agent home |

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
setup-line: could not ask GitHub about CI for <sha>: <why> -- no line printed; pass --force to print it anyway
```

`<why>` says which: `gh is not installed`, `gh is not signed in to GitHub (run gh auth login)`,
`GitHub answered 404 for workflow ci.yml in pr0d1r2/claudinix (no such repo or workflow, or no access): ...`,
or `gh run list failed: ...` with gh's first error line.

The output is one line (the `<sha>` is the 40-hex commit id). With
`--agent-home` it ends in ` --agent-home`:

```text
d=$(mktemp -d) && curl -fsSL https://raw.githubusercontent.com/pr0d1r2/claudinix/<sha>/setup.sh -o "$d/setup.sh" && bash "$d/setup.sh" <sha>
```

| exit | meaning |
|---|---|
| 0 | the line was printed (with `--force`, possibly after a warning) |
| 1 | `REV` is not a commit (`setup-line: cannot resolve <REV> to a commit -- no line printed`), GitHub cannot resolve a short SHA (`setup-line: GitHub cannot resolve <REV> to one commit of pr0d1r2/claudinix -- no line printed; pass a longer or the full SHA`, or `cannot resolve short SHA <REV>: gh is not installed`), or CI is not green and `--force` was not given |
| 2 | a usage error: an unknown flag or more than one `REV` |

## session-start.sh

The project's SessionStart hook, run by Claude Code in a cloud session on this
repository; it is not run by hand. It does nothing unless
`CLAUDE_CODE_REMOTE=true`. It fetches the full history, enters the dev shell
once, and always exits 0.

| variable | meaning |
|---|---|
| `CLAUDINIX_SESSION_PERMISSIONS` | `1` to merge `nix/cloud-permissions.json` into the gitignored `.claude/settings.local.json`, a fallback to the agent home's route. Off by default |

Rules and keys already in that file stay. The agent home now also writes the
same list into `~/.claude/settings.json` before Claude starts (see the
[README](../README.md#the-agent-home-is-opt-in)). Whether the fallback applies
in the session that wrote it is not measured yet (experiment T104).

## setup.sh

The setup script itself, fetched and run by the setup line. It is not run by
hand.

```text
usage: setup.sh [SHA] [--agent-home] -- SHA is a full 40-hex commit id; --agent-home (or CLAUDINIX_AGENT_HOME=1) also activates the agent home
```

`SHA` is the commit the file was fetched at; it pins `nix-dev` and the agent
home to it. Anything that is not a full 40-hex id, or a second SHA, exits 2
with the usage line above. `--agent-home`, or `CLAUDINIX_AGENT_HOME=1`,
activates the agent home, which also writes the cloud permissions into
`~/.claude/settings.json`; without it setup stops after Nix and `nix-dev` and
prints:

```text
agent home: skipped -- opt in with setup.sh [SHA] --agent-home, or CLAUDINIX_AGENT_HOME=1
```

Everything owner-specific in it (`cache_host`, `cache_key` and `repo`) sits in
the fork config block at its top ([`FORKING.md`](FORKING.md)). Variables a
test or a fork may set:

| variable | meaning |
|---|---|
| `CLAUDINIX_AGENT_HOME` | `1` to activate the agent home, like `--agent-home` |
| `CLAUDINIX_LIB_DIR` | where `nix-dev` and its helpers are installed; default `/usr/local/lib/claudinix` |
| `CLAUDINIX_RAW_URL` | where those files are fetched from; default `raw.githubusercontent.com` for `repo` at the revision |
| `CLAUDINIX_REV` | the revision to fetch them at; default the SHA argument, else `main` |
| `NIX_CONF_DIR`, `BIN_DIR`, `SYSTEMD_DIR`, `NIX_DEFAULT_PROFILE`, `NIX_INSTALL_URL`, `NIX_INSTALL_SHA256`, `NIX_MIN_VERSION` | paths and installer settings, mostly for tests |
| `CLOUD_HOME_FLAKE`, `CLOUD_HOME_STOREPATH`, `CLOUD_HOME_MARKER` | agent home: the flake to build, the recorded store path file, and the marker file left when activation fails |

The fetch of `setup.sh` from `raw.githubusercontent.com` during a real cloud
session's setup has not been tried yet.

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

## release.sh

Cuts a release in two steps (maintainer). It never commits, tags or pushes;
it prints the commands and you run them. The released SHA must hold
`cloud-home.storepath` for its own agent home, so the path is recorded and
committed first, and the setup line pins that commit.

```text
usage: release.sh record [REV] | release.sh publish REV
```

1. `just release record REV` (`REV` defaults to `HEAD`) checks that CI on
   `main` is green for `REV` (through `setup-line.sh`, never `--force`) and
   that every input source and `REV`'s agent home are in the cache, then
   writes `cloud-home.storepath`. It prints `git add`, `git commit` and
   `git push` for it. Run them.
2. Wait for green CI on `main` for that commit.
3. `scripts/release.sh publish REV2 >notes.md` (`REV2` is that commit).
   Run it directly, not through `just`, so the redirect holds only the
   release notes; or use `just --quiet release publish REV2 >notes.md`. It
   checks that `REV2` holds `cloud-home.storepath`, that it equals the agent
   home evaluated at `REV2`, and that CI and the cache are good, then
   regenerates the README block. The notes go to stdout.
4. Run the printed `git add README.md`, `git commit`, `git push`,
   `git tag -a claudinix-<short> <sha>`, `git push origin claudinix-<short>`
   and `gh release create ... --verify-tag --notes-file notes.md`.

If `REV` already records its own agent home, `record` says so and prints the
`publish` command to run directly. A refusal ends `nothing was recorded` or
`nothing was published`. Exit 0 on success, 1 on a refusal, 2 on a usage
error.

## Repository tools (maintainers only)

`claudinix-dev` is not a command for your project. It is this repository's
own tooling: it writes the generated doc blocks and checks the docs for drift
(see [`CONTRIBUTING.md`](CONTRIBUTING.md#generated-docs)). It is built from
the `dev/` crate, is never published, is not a flake app and is never
installed in a session. Run it from this repository's dev shell. Exit 0 when
clean, 1 when a check finds drift or the changelog rule refuses a commit,
2 for a usage error or a source it cannot read.

| command | what it does |
|---|---|
| `claudinix-dev badges --write` or `--check` | the README badges |
| `claudinix-dev steps --write` or `--check` | the step counts in [`INTEGRATION.md`](INTEGRATION.md) |
| `claudinix-dev config --write` or `--check` | the key table in [`CONFIG.md`](CONFIG.md) |
| `claudinix-dev notices --write` or `--check` | the inputs table in [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md) |
| `claudinix-dev cli --check` | the `usage:` lines on this page against the scripts (check only) |
| `claudinix-dev facts --check` | counts and numbers quoted in prose (check only) |
| `claudinix-dev changelog MESSAGE-FILE` | the `commit-msg` changelog rule ([`CONTRIBUTING.md`](CONTRIBUTING.md#the-changelog-rule)) |

`badges`, `steps`, `config`, `notices`, `cli` and `facts` take
`--root DIR` to work on another checkout; the default is the current
directory.

## just recipes

The [`justfile`](../justfile) runs the same scripts on this repository.
Arguments pass through, and each recipe is one plain command.

| recipe | runs |
|---|---|
| `just inputs [args]` | `scripts/inputs.sh` |
| `just domains [args]` | `scripts/domains.sh` |
| `just guide [args]` | `scripts/guide.sh`; `just guide update` for the update flow |
| `just probe [args]` | `scripts/probe-launch.sh` |
| `just cloud <task> [args]` | `scripts/cloud-task.sh` |
| `just bump-nix <version>` | `scripts/bump-nix.sh` |
| `just release [args]` | `scripts/release.sh` (maintainer) |

`just` on its own (or `just --list`) lists them; it never runs one by default. There is no recipe for `nix-dev` or
`setup-line.sh`: run `scripts/setup-line.sh` directly.
