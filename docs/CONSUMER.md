# Using the environment from your repository

[`SETUP.md`](SETUP.md) gets a cloud environment with Nix. This page is about
the other side: what your own repository, the one you send to the cloud,
should do so that `nix develop` and its git hooks work in a session. Your
repository adopts these changes through its own spec and its own commits.
Nothing here is applied for you, and everything below is a recommendation
with the dated fact behind it.

Why the work lives in your repository and not in the setup script: the setup
script installs Nix and nothing that belongs to one project (`SPEC.md` C3,
V7). Repository toolchains, linters, hooks and dependencies come from your
flake's dev shell.

## Checklist

1. Your flake has a `devShells.<system>.default` and a complete, committed
   `flake.lock`.
2. Every `github:` input is either in a binary cache the session reads, or is
   written as a `git+https` URL (below).
3. A SessionStart hook prepares the clone (below).
4. Tools that talk to GitHub run offline in the cloud (below).
5. Your commit-msg checks accept the cloud author and trailer (below).
6. The allowed domains cover your ecosystem's package hosts.

## Inputs: cache them, or fetch them with git

A session can read from GitHub only the repositories attached to it, and Nix
fetches a `github:` input as an archive tarball, which the proxy refuses with
a 403 (probe 2, 2026-10-03). Two ways round that, best first:

- **Put the locked input in a binary cache** from your CI, so Nix substitutes
  it by `narHash` and never contacts GitHub. Large inputs such as nixpkgs
  must go this way. [`CACHE-CI.md`](CACHE-CI.md) has the job.
- **Fetch the input with git.** Write a small input as
  `git+https://github.com/<owner>/<repo>?ref=main&shallow=1` instead of
  `github:<owner>/<repo>`. A plain git read of a public repository passes the
  proxy, and `shallow=1` fetches only the commit. The owner's `sherd`
  repository changed its inputs this way and its dev shell then built in 33
  seconds cold with no overrides (probe 7, 2026-10-03). Do not do this for
  nixpkgs, whose history is huge.

Whichever you pick, the dev shell's closure should be in the cache too, or
the session builds it from source.

Two commands do this for you ([`CLI.md`](CLI.md)):

- `nix run github:pr0d1r2/claudinix#inputs`, run in your project,
  lists each `github:` input of `flake.lock` as `cached` or `attach`. To check
  one by hand, use the narinfo request in [`CACHE-CI.md`](CACHE-CI.md).
- `nix-dev` is installed in the session by the setup script. It runs
  `nix develop` and tries these tiers in order: locked inputs from the cache,
  uncached inputs fetched with git at the locked revision, `github:` as
  locked, and last nixpkgs from its channel tarball. It logs the tier it used
  and never writes `flake.lock`, so your flake needs no change. It has not
  yet been run inside a real cloud session.

## A SessionStart hook

Claude Code runs a SessionStart hook when a session begins. The cloud sets
`CLAUDE_CODE_REMOTE=true` (probe 7, 2026-10-03), so one script can do
cloud-only work and stay silent on a laptop.

Two things the cloud clone needs before your gate works:

- **History.** The clone is shallow (probe 1, 2026-10-03). Any guard that
  reads history, such as a "test before code" check, needs
  `git fetch --unshallow`.
- **Your git hooks.** Each session is a fresh clone, so the hooks are not
  installed. Install them from inside the dev shell with
  `nix develop -c hk install`, if your repository uses hk.

Commit the hook script and register it in your repository's committed
`.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "bash scripts/dev/cloud-session-start.sh" }
        ]
      }
    ]
  }
}
```

and `scripts/dev/cloud-session-start.sh`:

```sh
#!/usr/bin/env bash
# Prepare a Claude Code cloud clone. Silent outside the cloud.
set -euo pipefail

[ "${CLAUDE_CODE_REMOTE:-}" = true ] || exit 0

if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
    git fetch --unshallow
fi

nix develop -c hk install
```

This snippet is a sketch written from the facts above. It has not been run
in a target repository yet, so try it in a session and read its output
before you depend on it. The setup script does not run on a cached snapshot
(`SPEC.md` C1), which is one more reason this belongs in a per-session hook
and not in `setup.sh`.

## Tools that read GitHub

Cloud sessions reach GitHub through a proxy that injects credentials, and a
tool that reads `GH_TOKEN` sees the placeholder `proxy-injected`. Such a tool
fails with a 401 (zizmor's online audit, sherd #97 session, 2026-10-03).
Third-party git reads, by contrast, pass once `github.com` is in the allowed
domains (probe 5, 2026-10-03).

So in the cloud:

- Run tools that audit online in their offline mode. This repository runs
  `zizmor --offline` everywhere, so the gate does not need the network.
- If a tool must go online, run it without the token, for example
  `env -u GH_TOKEN -u GITHUB_TOKEN <tool>`.
- A tool that could not run is not a pass and not a finding. Report it as
  "could not run". This repository's gate does that through
  [`scripts/hk/run-tool.sh`](../scripts/hk/run-tool.sh).

## Commits and branches from a session

- **The author is `Claude <noreply@anthropic.com>`**, the commits are
  ssh-signed, and the harness adds a `Claude-Session:` trailer (probe 1,
  2026-10-03). A commit-msg hook that rejects either will block the session.
  This repository's [`commit-msg.sh`](../scripts/guard/commit-msg.sh) checks
  the subject and a `Why:` line and accepts both.
- **The branch gets a random suffix**, for example `claude/<name>-8yxk95`.
  Anything that matches branch names exactly will miss it; match by prefix.
- **Pushed branches stay until you delete them.** A session cannot delete
  branches ([`RUNBOOK.md`](RUNBOOK.md), "Clean up probe branches").

## Permission prompts

On 2026-10-03 a session in `sherd` stopped on a prompt, "Allow Claude to use
add repo (claude-code-remote)?", until someone answered it, because the
`add_repo` tool asks first. Ways to avoid that are being worked out
(`SPEC.md` T47) and are not documented here yet. Until then, expect that an
unattended session can wait on a prompt.

## Network

Your ecosystem's package hosts must be in the environment's allowed domains.
Cargo needs `index.crates.io` and `static.crates.io`, added by name (probe 4,
2026-10-03). Allowlist edits reach only new sessions. Run `nix run
github:pr0d1r2/claudinix#domains` in your project: it lists the
base hosts plus the hosts your lock files name (Cargo, npm, Python, Ruby, Go,
git submodules, Nix), and `--why` says which file named each
([`CLI.md`](CLI.md)).
