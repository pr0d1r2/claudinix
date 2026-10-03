# Setup

This guide takes you from nothing to a Claude Code cloud session that
can run `nix develop` in your repository. It assumes no earlier
experience with Claude Code cloud sessions.

Most of the work happens in your terminal. Two parts happen in the
browser, because Claude Code has no API or CLI for them: account
settings and the cloud environment itself. The files in this repository
are the source of truth for the environment: copy from them, and never
change the environment in the browser without a matching commit here.

Steps at a glance:

0. Protect your money (browser, before anything else).
1. Check the prerequisites.
2. Connect GitHub (browser, once).
3. Create the environment (browser, once).
4. Choose the environment in your terminal (once per machine).
5. Run a first session and check that it works.

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

- **A claude.ai plan with cloud sessions**: Pro, Max, Team, or
  Enterprise with a Claude Code seat.
- **Claude Code installed and signed in with that claude.ai account.**
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
4. Fill in the dialog:
   - **Name**: `nix`.
   - **Network access**: **Custom**.
     - Check **Also include default list of common package managers**.
     - In **Allowed domains**, enter every non-comment line of
       [`allowlist.txt`](../allowlist.txt), one domain per line. It
       lists `cache.nixos.org`, `channels.nixos.org` and
       `releases.nixos.org` explicitly: the first probe (2026-10-03) got
       a 403 from the proxy for `cache.nixos.org` and
       `channels.nixos.org`, so do not rely on the default list for
       them.
   - **Environment variables**: enter the names listed in
     [`env-names.txt`](../env-names.txt) with your values. If it lists
     none, leave the box empty. Anyone who can use the environment can
     read these values, so never put secrets here.
   - **Setup script**: paste the whole of [`setup.sh`](../setup.sh).
     To use your own binary cache, edit the config block at its top
     first.
5. Select **Create environment**.

The setup script runs as root on the first session in the environment.
When it finishes within about five minutes, the VM's filesystem is
snapshotted and later sessions start from that snapshot without
running the script again, so the first session is the slow one.

### GitHub repositories your flake fetches

A session can read from GitHub only the repositories attached to it.
Any other `github:` flake input, even a public one, fails with a 403
that says GitHub access to the repository "is not enabled for this
session". The first probe hit this for `github:NixOS/nixpkgs` and for
`github:pr0d1r2/nix-hk`.

Plain git reads of public repositories do pass the proxy
(`git ls-remote https://github.com/<owner>/<repo>` works), but the
archive tarballs Nix downloads for `github:` inputs
(`https://github.com/<owner>/<repo>/archive/<rev>.tar.gz`) get the 403.
Attaching a public repository with `add_repo` read access does not
help: it answers "read access is already available" and attaches
nothing (probe 2, 2026-10-03).

For every repository your flake fetches straight from GitHub, either:

- **Cache it.** Push the locked input and everything built from it to
  your binary cache from CI. Nix then substitutes it by `narHash` and
  never contacts GitHub. Do this for large repositories such as
  `NixOS/nixpkgs`.
- **Fetch it with git.** Write the input as
  `git+https://github.com/<owner>/<repo>` instead of
  `github:<owner>/<repo>`, so Nix uses a git fetch, which the proxy
  allows for public repositories. Fine for small repositories such as
  `pr0d1r2/nix-hk`; avoid it for `NixOS/nixpkgs`, whose git history is
  huge.

`just inputs` lists every `github:` input of a flake and whether it is
already cached.

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

From a checkout of your repository, with your branch pushed:

```sh
claude --cloud "Run: nix --version && nix develop -c true && echo DEVSHELL-OK. Report the output."
```

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

1. Open the environment selector as in step 3: start page of
   [claude.ai/code](https://claude.ai/code), cloud icon above the message
   box, then **Cloud**.
2. Hover over `nix` and select the settings (gear) icon on the right.
3. Change only what the commit changed:
   - **Setup script**: select all of the old script and paste the new
     one over it.
   - **Allowed domains**: one domain per line; `just domains` prints
     the full list.
   - **Environment variables**: names from `env-names.txt`.
4. Save, then check the change in a **new** session (see below).

A change to the setup script or the allowed domains rebuilds the
snapshot on the next new session. A session that is already running
keeps its old VM; start a new session to pick up the change.

## Troubleshooting

- **The session fails to start, or stops during setup.** The setup
  script exited with an error. The setup checklist in your terminal
  shows which step failed. Check that you pasted the whole script and
  that **Also include default list of common package managers** is
  checked.
- **`nix: command not found`.** The session ran in another environment.
  Run `/remote-env`, pick `nix`, and start a new session.
- **Downloads fail with a network or proxy error** such as
  `CONNECT tunnel failed, response 403`. The host is not allowed. Add
  it to **Allowed domains** here and in `allowlist.txt`.
- **`warning: ignoring untrusted flake configuration setting
  'extra-substituters'`.** Nix ignores the caches your flake declares in
  `nixConfig` unless told to trust them. The setup script sets
  `accept-flake-config = true` in `/etc/nix/nix.conf`; only use
  environments with repositories whose flake settings you trust.
- **`nix develop` fails while fetching a `github:` input** with a 403
  saying the repository isn't enabled for this session. This is
  expected, not a misconfiguration: the GitHub proxy only lets the
  GitHub API reach repositories attached to the session, so an input
  such as `github:NixOS/nixpkgs` is refused (seen 2026-10-03). Ways
  around it, best first:
  1. Keep `flake.lock` committed and complete, and push every locked
     input to your binary cache from CI. Nix then substitutes each
     input by its `narHash` from the cache and never asks GitHub.
  2. Point `nixpkgs` at a nixos.org tarball, which the default network
     list allows:
     `https://channels.nixos.org/<channel>/nixexprs.tar.xz`.
  Attaching `NixOS/nixpkgs` to the session is not a fix: the session
  would clone the whole repository.
- **Every session is slow to start.** The setup script takes longer
  than about five minutes, so no snapshot is saved.
- **`Unable to get organization UUID`.** You are signed in with an API
  key or your sign-in is stale. Run `/login` with your claude.ai account
  and try again.

## Cleaning up

- Sessions push to branches named `claude/...`. A session cannot delete
  branches, so delete ones you no longer need from your own machine:
  `git push origin --delete claude/<name>`.
- Archive finished sessions from the sidebar at
  [claude.ai/code](https://claude.ai/code) to keep the list short.
