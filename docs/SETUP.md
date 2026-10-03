# Setup

**Fastest path:** in your project, run

```sh
nix run github:pr0d1r2/claudinix#guide
```

The guide walks the steps below in your terminal, opens the pages you need,
copies each value you have to paste, and checks what it can. This page is the
same walkthrough written out, for when you want to see every click or do it
by hand. It takes you from nothing to a Claude Code cloud session that can
run `nix develop` in your repository, and it assumes no earlier experience
with Claude Code cloud sessions.

Most of the work happens in your terminal. Two parts happen in the browser,
because Claude Code has no API or CLI for them: account settings and the
cloud environment itself.

Steps at a glance:

0. Protect your money (browser, before anything else).
1. Check the prerequisites.
2. Connect GitHub (browser, once).
3. Create the environment (browser, once).
4. Choose the environment in your terminal (once per machine).
5. Run a first session and check that it works.

If you run this repository yourself (your own cache, your own names), the
owner-side steps are in [`FORKING.md`](FORKING.md) and
[`RUNBOOK.md`](RUNBOOK.md), not here.

## 0. Before your first cloud session: protect your money

> **Important:** do both steps before you start any cloud session,
> including a test or probe session. Skipping them can spend your plan
> quota or charge your card.

1. **Claim any cloud credit first.** If your account was offered
   promotional credit for cloud sessions, claim it before the first
   session: run `/claim-credit` in Claude Code, or claim it at
   claude.ai. Then open
   [claude.ai/settings/usage](https://claude.ai/settings/usage) and check
   that it shows the credit amount and its expiry date. Credit has a
   claim deadline; unclaimed credit is lost, and sessions run before the
   claim use your plan quota instead.
2. **Check that usage credits are OFF.** On the same page,
   [claude.ai/settings/usage](https://claude.ai/settings/usage), make
   sure the usage credits (metered overage) toggle is OFF. When it is
   ON, cloud sessions and routines that go past your credit or plan
   limits are billed to your card. Check it again before you add a
   routine or run more sessions in parallel, and once a week while you
   use cloud sessions.

## 1. Prerequisites

- **Nix with flakes on your own machine.** The guide and the other
  commands run with `nix run`. The first `nix run github:pr0d1r2/claudinix#...`
  asks whether to trust the extra binary cache `pr0d1r2.cachix.org` (the
  `extra-substituters` setting of this flake): answer `y`, or pass
  `--accept-flake-config`.
- **A claude.ai plan with cloud sessions**: Pro, Max, Team, or
  Enterprise with a Claude Code seat.
- **The `claude` CLI, signed in with that claude.ai account.**
  Run `claude auth login` (or `/login` inside Claude Code). An API key
  is not enough: `claude --cloud` needs a claude.ai sign-in.
- **Your repository on GitHub.** Cloud sessions clone from GitHub and
  push back to it.
- **Your repository is a Nix flake** with a `devShell` and a committed
  `flake.lock` that pins every input. Run `nix flake lock` locally and
  commit the result if you are not sure.
- **Your branch is pushed.** A session clones the GitHub copy of your
  current branch, not your local checkout, so local commits it should
  see must be pushed first.
- **The GitHub CLI `gh`, signed in, only to print a setup line for a
  commit of your choosing** (`guide --rev SHA`). It asks GitHub whether CI
  passed for that commit. The guide copies the line the release published
  in the [README](../README.md) without it (see step 3).

## 2. Connect GitHub (browser, once)

Sessions reach GitHub through a proxy that keeps your GitHub credentials
outside the session's VM. You connect GitHub to your claude.ai account
in one of two ways:

- **Claude GitHub App (recommended).** Install it from the
  [GitHub App page](https://github.com/apps/claude), or follow the
  prompt during onboarding at [claude.ai/code](https://claude.ai/code).
  When GitHub asks which repositories it may access, pick **Only select
  repositories** and list only the ones you want cloud sessions to
  change. You can change the list later at
  [github.com/settings/installations](https://github.com/settings/installations).
- **`/web-setup` in your terminal.** This sends your local `gh` CLI token
  to your claude.ai account. It is quicker, but sessions can then reach
  every repository that token can, so prefer the App when you want to
  limit access.

To check: open [claude.ai/code](https://claude.ai/code) and confirm your
repository appears in the repository picker.

## 3. Create the environment (browser, once)

A cloud environment is a saved configuration: network access,
environment variables, and a setup script that runs before Claude starts
in each new VM. This repository's environment installs Nix.

1. Open [claude.ai/code](https://claude.ai/code) and stay on the start
   page with the empty message box. Inside an open session the selector
   is not shown.
2. Select the cloud icon showing the current environment's name, in the
   row above the message box. There is no settings page or direct URL
   for it. In the Desktop app, the same selector is in the prompt box
   once you choose **Cloud**.
3. Select **Cloud**, then **Add cloud environment**.
4. Fill in the dialog, field by field, in this order:
   - **Name**: `nix`. It is only a label; pick another if you like, and
     choose that one in step 4.
   - **Network access**: **Custom**.
     - Check **Also include default list of common package managers**.
       It does not cover everything Nix needs, so you add hosts below.
     - In **Allowed domains**, enter one domain per line:
       - The base list: every non-comment line of
         [`allowlist.txt`](../allowlist.txt): `pr0d1r2.cachix.org`,
         `cache.nixos.org`, `channels.nixos.org`, `releases.nixos.org` and
         `github.com`. The default list does **not** cover the nixos.org
         hosts: the proxy refused `cache.nixos.org` and `channels.nixos.org`
         until they were named (probes 1-3, [`FACTS.md`](FACTS.md)).
       - Your project's own hosts (`index.crates.io` for Cargo, PyPI, npm
         and so on). Run the `domains` app inside your project:
         `nix run github:pr0d1r2/claudinix#domains`. It prints the base
         list followed by the hosts your project's files name, each once,
         and copies them to the clipboard when a clipboard tool is
         available. `--why` shows which file named each host. See
         [`CLI.md`](CLI.md).
   - **Environment variables**: none are required. One is optional:
     `BASH_DEFAULT_TIMEOUT_MS=600000`. A Bash command that runs past 120
     seconds in a session moves to the background and keeps running, and
     its real exit status arrives only with the completion notice. A
     timeout of 600000 ms (10 minutes) means fewer long runs are
     backgrounded. It is not a secret. Anyone who can use the environment
     can read these values, so never put secrets here.
   - **Setup script**: the one line published for the release you chose,
     in the [README](../README.md) and in that release's notes. Paste that
     line, not the contents of [`setup.sh`](../setup.sh). It looks like
     this (`<sha>` is the commit the release is pinned to):

     ```text
     d=$(mktemp -d) && curl -fsSL https://raw.githubusercontent.com/pr0d1r2/claudinix/<sha>/setup.sh -o "$d/setup.sh" && bash "$d/setup.sh" <sha>
     ```

     The line downloads `setup.sh` at exactly that commit and runs it with
     the same SHA, so the same line always gives the same VM. Each release
     publishes a SHA whose CI was green and whose binary cache is filled;
     do not make up a SHA. The guide (`guide`, step 3) copies the
     release's line from the README to your clipboard for you. Until the first
     release there is no published line: the guide says there is no release
     yet and stops. Maintainers and testers can run `guide --rev SHA` or
     `scripts/setup-line.sh SHA` (needs `gh`) to get a line for a commit CI
     passed.

     By default the script installs Nix and `nix-dev` only. To also install
     the agent home (the owner's Claude rules and skills; it changes how
     Claude behaves, see the [README](../README.md#the-agent-home-is-opt-in)),
     add ` --agent-home` at the end of the line (`guide --agent-home` does
     that for you).

     Maintainers, or anyone pinning another commit, can print a line with
     [`scripts/setup-line.sh`](../scripts/setup-line.sh) (see
     [`CLI.md`](CLI.md)); it needs `gh`, because it refuses a commit whose
     CI on `main` is not green.
5. Select **Create environment**.

The setup script runs as root on the first session in the environment.
When it finishes within about five minutes, the VM's filesystem is
snapshotted and later sessions start from that snapshot without
running the script again, so the first session is the slow one.

### GitHub repositories your flake fetches

A session can read from GitHub only the repositories attached to it. Any
other `github:` flake input, even a public one, fails with a 403 that says
GitHub access to the repository "is not enabled for this session". Nix
downloads a `github:` input as an archive tarball
(`https://github.com/<owner>/<repo>/archive/<rev>.tar.gz`), and the proxy
refuses it. Plain git reads of public repositories do pass
(`git ls-remote https://github.com/<owner>/<repo>` works). Attaching a
public repository with `add_repo` read access does not help: it answers
"read access is already available" and attaches nothing. Evidence and dates:
probes 1, 2 and 5 in [`FACTS.md`](FACTS.md).

`nix run github:pr0d1r2/claudinix#inputs`, run in your project, lists every
`github:` input of its `flake.lock` and whether it is `cached` (a binary
cache has it, so a session never contacts GitHub) or `uncached` (a session
would have to fetch it from GitHub). For every `uncached` input, use one of
these, best first:

1. **`nix-dev`.** Setup installs it in the session. Run `nix-dev` where you
   would run `nix develop` (`nix-dev -c cargo test`). It fetches uncached
   inputs over git at the locked revision and never writes `flake.lock`, so
   your flake needs no change. It logs which tier it used.
2. **Cache the inputs.** Push the locked input and everything built from it
   to your binary cache from CI ([`CACHE-CI.md`](CACHE-CI.md)). Nix then
   substitutes it by `narHash` and never contacts GitHub. Do this for large
   repositories such as `NixOS/nixpkgs`.
3. **Fetch the input with git.** Write it as
   `git+https://github.com/<owner>/<repo>` instead of
   `github:<owner>/<repo>`. Fine for small repositories; avoid it for
   `NixOS/nixpkgs`, whose history is huge.
4. **Last resort for nixpkgs:** point it at a nixos.org tarball,
   `https://channels.nixos.org/<channel>/nixexprs.tar.xz`. The default
   network list does not allow that host; it is in `allowlist.txt`, so it
   works with the base list above. The revision then differs from your
   lock; `nix-dev` does this as its last tier and warns.

Attaching `NixOS/nixpkgs` to the session is not a fix: the session would
clone the whole repository.

## 4. Choose the environment in your terminal (once per machine)

Run `/remote-env` in Claude Code and pick `nix`. This saves the choice
as `remote.defaultEnvironmentId` in your user settings
(`~/.claude/settings.json`), and `claude --cloud` uses it from then on
in every project. Without this step, sessions run in the **Default**
environment, which has no Nix.

A repository can pin the environment for everyone who works in it by
setting the same key in its committed `.claude/settings.json`. Copy the
`env_...` ID from your user settings after running `/remote-env`:

```json
{
  "remote": {
    "defaultEnvironmentId": "env_..."
  }
}
```

## 5. Run a first session and check that it works

From a checkout of your repository, with your branch pushed. The task text
comes right after `--cloud`, and the model after it:

```sh
claude --cloud "Run: nix --version && nix-dev -c true && echo DEVSHELL-OK. Report the output." --model sonnet
```

The model is fixed when the session starts, and the environment cannot
choose it. Sessions started without `--model` ran on Opus (measured
2026-10-03); see [`MODEL.md`](MODEL.md) for the models and their prices. In
the browser, use the model picker when you start a session.

While the VM starts, the terminal shows a checklist of setup steps,
including the setup script. Expect the first start to take a few
minutes. The command prints a link to the session; open it, or pull the
session into your terminal with `claude --teleport <session-id>`.

It works when the output shows a Nix version and `DEVSHELL-OK`.

To steer a running session from the terminal, send a follow-up:

```sh
claude -p "<message>" --cloud <session-id>
```

## Updating the environment (after a change here)

When a new release publishes a new setup line, or your project needs other
hosts:

1. Open the environment selector as in step 3: start page of
   [claude.ai/code](https://claude.ai/code), cloud icon above the message
   box, then **Cloud**.
2. Hover over `nix` and select the settings (gear) icon on the right.
3. Change only what changed:
   - **Setup script**: select all of the old script and paste the new
     line over it (the one published in the [README](../README.md) and the
     release notes; `guide update` pastes a line for you). An update is a
     new SHA in that line and nothing else.
   - **Allowed domains**: one domain per line; run
     `nix run github:pr0d1r2/claudinix#domains` in your project for the
     full list.
   - **Environment variables**: the optional
     `BASH_DEFAULT_TIMEOUT_MS=600000`, if you use it.
4. Save, then check the change in a **new** session (see below).

A change to the setup script or the allowed domains rebuilds the
snapshot on the next new session. A session that is already running
keeps its old VM; start a new session to pick up the change.

## Troubleshooting

- **The session fails to start, or stops during setup.** The setup
  script exited with an error. The setup checklist in your terminal
  shows which step failed. Check that you pasted the whole line, that the SHA
  in it is a commit pushed to GitHub, and that **Also include default list of
  common package managers** is checked.
- **`nix: command not found`.** The session ran in another environment.
  Run `/remote-env`, pick `nix`, and start a new session.
- **Downloads fail with a network or proxy error** such as
  `CONNECT tunnel failed, response 403`. The host is not allowed. Add
  it to **Allowed domains** in the environment dialog, and start a new
  session.
- **`warning: ignoring untrusted flake configuration setting
  'extra-substituters'`.** Nix ignores the caches your flake declares in
  `nixConfig` unless told to trust them. The setup script sets
  `accept-flake-config = true` in `/etc/nix/nix.conf`; only use
  environments with repositories whose flake settings you trust. On your own
  machine, answer `y` to the prompt, or pass `--accept-flake-config`.
- **`nix develop` fails while fetching a `github:` input** with a 403
  saying the repository isn't enabled for this session. This is expected, not
  a misconfiguration: see "GitHub repositories your flake fetches" in
  step 3 for the one list of remedies, `nix-dev` first.
- **Sessions run on a different model than expected.** Check the
  `Co-Authored-By` trailer of a commit the session made. The model comes
  from how the session was started (`--model`, or the browser's picker),
  not from the environment.
- **Every session is slow to start.** The setup script takes longer
  than about five minutes, so no snapshot is saved.
- **`Unable to get organization UUID`.** You are signed in with an API
  key or your sign-in is stale. Run `/login` with your claude.ai account
  and try again.

## Cleaning up

- Sessions push to branches named `claude/...`. A session cannot delete
  branches, so delete ones you no longer need from your own machine:
  `git push origin --delete claude/<name>`. Probe branches
  (`claude/nix-probe*`) can be removed in one go with
  `nix run github:pr0d1r2/claudinix#probe -- --cleanup`.
- Archive finished sessions from the sidebar at
  [claude.ai/code](https://claude.ai/code) to keep the list short.
