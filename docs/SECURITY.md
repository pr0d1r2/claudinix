# Security policy

## Reporting a vulnerability

Report privately, not in a public issue.

- Preferred: [GitHub private vulnerability
  reporting](https://github.com/pr0d1r2/claudinix/security/advisories/new)
- Or email **pr0d1r2@gmail.com** with `claudinix security` in
  the subject.

Include the commit you used, what you ran, and what happened. A reproducing
session transcript or `probe.sh` output is worth more than a description of
one.

Expect an acknowledgement within a week. If a report is valid, the fix and
the advisory go out together, and you are credited unless you ask otherwise.

## Supported versions

Only the latest commit on `main` is supported. There are no backports. Pin
your environment to a commit you have read, and move the pin on purpose.

## What the attack surface actually is

Stated plainly, because this repository's main product runs with more power
than most code you paste anywhere.

**The setup script runs as root, on every fresh session VM, before Claude
starts.** Whatever it does, it does with full control of that VM: the
filesystem, the Nix store, and the shell Claude will later use. The VM also
holds the session's clone of your repository and the session's GitHub
access. That makes the following the classes worth reporting:

1. **Code you did not read reaching the VM.** The setup script downloads
   the Nix installer only when the image's Nix is older than the floor, and
   it refuses to run an installer whose sha256 does not match the pinned
   one (`SPEC.md` V2). A path that runs a downloaded installer without that check,
   or that lets the URL or hash be changed from outside the script, is a
   defect.
   **Downloads that are not hash-checked.** Besides the installer, `setup.sh`
   downloads these files from `raw.githubusercontent.com` at the commit the
   setup line is pinned to: `nix-dev.sh`, `nix-dev.jq`, `inputs.sh` and
   `inputs.jq` (installed under `/usr/local/lib/claudinix`, with `nix-dev`
   linked into `/usr/local/bin`), and, only with the agent home,
   `cloud-home.storepath`. None has a hash of its own. They are trusted only
   through the pinned commit SHA and TLS, so the setup line you paste is
   what you trust: read it, and read the files at that commit. `nix-dev`
   runs as whatever user runs it in the session, which is root.
   A fetch that fails only warns, and setup carries on without `nix-dev`.
2. **The agent home is opt-in, and it changes Claude's behaviour.** Without
   `--agent-home` (or `CLAUDINIX_AGENT_HOME=1`), setup does not activate it.
   With it, setup builds `homeConfigurations.cloud` from this repository's
   flake and its pinned inputs, activates it as root, and writes the owner's
   rules, skills and a claude-code configuration into `/root/.claude`
   ([`README.md`](../README.md#the-agent-home-is-opt-in)). Opt in only if
   you trust those rules and skills to steer your sessions.
   **It also rewrites Bash commands.** Its `rtk` hook runs before every
   Bash call and turns a command such as `git status` into
   `rtk git status`, and setup links `rtk` into `/usr/local/bin`. rtk then
   runs the real command and condenses its output, so you trust rtk with
   every command Claude runs. `rtk proxy <cmd>` runs a command unfiltered.
   **It also pre-approves commands.** It writes a narrow permission list
   (`nix/cloud-permissions.json`) into `/root/.claude/settings.json`: the
   gate's own commands (`hk`, `bats`, `mth`, `sherd`, `itok`, `scripts/*`,
   `nix develop -c` or `nix-dev -c` followed by one of them), `git` commits,
   fetches and reads, and pushing `claude/*` branches run without a prompt.
   Pushing `main` is denied. These rules exist only in cloud sessions; they
   are never in the committed `.claude/settings.json`, so a local session
   never gets them. The `cloud-permissions` gate step refuses blanket rules
   and a missing main-push deny. With `CLAUDINIX_SESSION_PERMISSIONS=1` the
   SessionStart hook also writes the list into the gitignored
   `.claude/settings.local.json`, only in a cloud session. Whether the
   agent home's file survives to launch, and whether the fallback applies in
   the same session, is not measured yet (experiment T104).
   **A rule you commit into your own repository is a separate grant.**
   [`SETUP.md`](SETUP.md#permission-prompts) describes allowing the
   `add_repo` tool that way. The rule cannot limit the tool's arguments, so
   it also allows attaching a repository with push access without a prompt,
   and a session reads it from whatever branch it runs on. Review that file
   like any permission change.
3. **A binary cache you did not choose.** The script adds
   `pr0d1r2.cachix.org` and its public key next to `cache.nixos.org`.
   Anything signed with that key can land in the session's `/nix/store`
   and run there. The cache is public and read-only from the VM: no push
   token is ever needed or stored (`SPEC.md` V6). If you do not trust the
   owner's cache, fork this repository and change the cache host and key
   at the top of `setup.sh`.
4. **Flake settings from the cloned repository.** The script sets
   `accept-flake-config = true` (`SPEC.md` V25). That makes Nix apply the
   `nixConfig` of any flake the session evaluates, including extra
   substituters and keys. A repository whose owner you do not trust can
   therefore point Nix at its own cache. Substituters outside the
   environment's allowed domains are unreachable, which limits but does not
   remove this. **Use the environment only with repositories you trust.**
5. **The GitHub proxy.** Cloud sessions reach GitHub through a proxy that
   injects credentials, and tools that read `GH_TOKEN` see the placeholder
   `proxy-injected`. A step here that sends that token, or a token of its
   own, to a host other than GitHub is a defect.
6. **Secrets in the environment.** Environment variables set in the cloud
   environment dialog are readable by anyone who can use that environment.
   [`env-names.txt`](../env-names.txt) holds names only for anything
   secret, and its tests reject values that look like tokens, keys or
   passwords. A change that asks you to paste a secret value into the
   dialog is a defect.
7. **Private information in a public repository.** This repository is
   public from its first push. A private hostname, LAN address, self-hosted
   forge path or token in the tree or in its history is a defect
   (`SPEC.md` V12); the gate runs `ripsecrets` and `detect-private-key` on
   every commit.

**What is structurally excluded:**

- **No daemon, no listener.** Nothing here opens a port or keeps a process
  running after the setup script ends.
- **No push credentials on the VM.** Filling the cache is CI's job, with a
  token stored only in CI secrets.

## What is out of scope

- The cloud platform itself: the VM image, the network proxy and the
  environment dialog belong to Anthropic. Report those to Anthropic.
- A target repository's own flake, dev shell or hooks running code in the
  session. That is what the session is for; the repository's owner is
  responsible for it.
- Choosing to trust a cache or a repository and getting what it serves.
- Anything that needs an attacker who can already edit your cloud
  environment's settings or push to this repository.
