# Setup

Claude Code cloud environments have no API or CLI for creating or
editing them, so this part is done by hand in the browser. The files in
this repository are the source of truth: copy from them, never edit the
environment in the browser without a matching commit here.

You need a claude.ai account with cloud sessions (Pro, Max, Team, or
Enterprise with a Claude Code seat) and GitHub connected to it.

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

## 1. Create the environment (browser, once)

1. Open [claude.ai/code](https://claude.ai/code).
2. Select the cloud icon showing the current environment's name, in the
   row above the message box. There is no settings page or direct URL
   for it.
3. Select **Cloud**, then **Add cloud environment**.
4. Fill in the dialog:
   - **Name**: `nix`.
   - **Network access**: **Custom**.
     - Check **Also include default list of common package managers**.
       It covers `*.nixos.org`, where the Nix installer, its tarball and
       `cache.nixos.org` live.
     - In **Allowed domains**, enter every non-comment line of
       [`allowlist.txt`](../allowlist.txt), one domain per line.
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

## 2. Update the environment (browser, after a change here)

1. Open the environment selector as in step 1 and select **Cloud**.
2. Hover over `nix` and select the settings icon on the right.
3. Change only what the commit changed: the setup script, the allowed
   domains, or the environment variable names.
4. Save.

A change to the setup script or the allowed domains rebuilds the
snapshot on the next new session. A session that is already running
keeps its old VM; start a new session to pick up the change.

## 3. Use the environment from the terminal

Run `/remote-env` in Claude Code and pick `nix`. This saves the choice
as `remote.defaultEnvironmentId` in your user settings, and
`claude --cloud` uses it from then on in every project.

A repository can pin the environment for everyone who works in it by
setting the same key in its committed `.claude/settings.json`. Copy the
`env_...` ID from your user settings (`~/.claude/settings.json`) after
running `/remote-env`:

```json
{
  "remote": {
    "defaultEnvironmentId": "env_..."
  }
}
```

Then start a session from a checkout whose branch is pushed to GitHub:

```sh
claude --cloud "nix --version && nix develop -c true && echo DEVSHELL-OK"
```

While the VM starts, the terminal shows a checklist of setup steps,
including the setup script. Send follow-ups with
`claude -p "<message>" --cloud <session-id>`, and pull the session into
your terminal with `claude --teleport <session-id>`.
