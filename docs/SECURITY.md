# Security policy

## Reporting a vulnerability

Report privately, not in a public issue.

- Preferred: [GitHub private vulnerability
  reporting](https://github.com/pr0d1r2/nix-claude-code-cloud/security/advisories/new)
- Or email **pr0d1r2@gmail.com** with `nix-claude-code-cloud security` in
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
   one (`SPEC.md` V2). A path that runs downloaded code without that check,
   or that lets the URL or hash be changed from outside the script, is a
   defect.
2. **A binary cache you did not choose.** The script adds
   `pr0d1r2.cachix.org` and its public key next to `cache.nixos.org`.
   Anything signed with that key can land in the session's `/nix/store`
   and run there. The cache is public and read-only from the VM: no push
   token is ever needed or stored (`SPEC.md` V6). If you do not trust the
   owner's cache, fork this repository and change the cache host and key
   at the top of `setup.sh`.
3. **Flake settings from the cloned repository.** The script sets
   `accept-flake-config = true` (`SPEC.md` V25). That makes Nix apply the
   `nixConfig` of any flake the session evaluates, including extra
   substituters and keys. A repository whose owner you do not trust can
   therefore point Nix at its own cache. Substituters outside the
   environment's allowed domains are unreachable, which limits but does not
   remove this. **Use the environment only with repositories you trust.**
4. **The GitHub proxy.** Cloud sessions reach GitHub through a proxy that
   injects credentials, and tools that read `GH_TOKEN` see the placeholder
   `proxy-injected`. A step here that sends that token, or a token of its
   own, to a host other than GitHub is a defect.
5. **Secrets in the environment.** Environment variables set in the cloud
   environment dialog are readable by anyone who can use that environment.
   [`env-names.txt`](../env-names.txt) holds names only for anything
   secret, and its tests reject values that look like tokens, keys or
   passwords. A change that asks you to paste a secret value into the
   dialog is a defect.
6. **Private information in a public repository.** This repository is
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
