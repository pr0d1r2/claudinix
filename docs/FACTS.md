# Cloud session facts

What a Claude Code cloud session actually looks like, as measured. Every fact
here comes from a probe run inside a real session, and every fact carries the
date it was measured. Anthropic can change the platform at any time, so an
old date is a warning: re-measure before you rely on it.

All probes so far ran on 2026-10-03, in sessions on the owner's `sherd`
repository, through the cloud environment named `nix`. The numbers in
brackets (probe 1, probe 2, ...) are the order they ran in. The spec records
the same facts in caveman form in `SPEC.md` C6, C8, C8b, C8c and C13.

To re-measure, run [`probe.sh`](../probe.sh) inside a session.

## The machine

| fact | measured | source |
|---|---|---|
| The session runs as root: uid 0, `HOME=/root`. | 2026-10-03 | probe 1 |
| PID 1 is `process_api`. There is no systemd. | 2026-10-03 | probe 1 |
| `unshare -Ur` works. | 2026-10-03 | probe 1 |
| 4 vCPUs, 15 GB RAM, no swap. | 2026-10-03 | probe 6 |
| About 30 GB of free disk per session, on a 252 GB device. No cgroup v2 limits are visible. | 2026-10-03 | probe 6 |
| The VM had been up for 3 minutes when the session started: a fresh boot, not a reused one. | 2026-10-03 | probe 6 |
| The session sets `CLAUDE_CODE_REMOTE=true`, plus several `CCR_*` variables. A hook can use this to tell it is running in the cloud. | 2026-10-03 | probe 7 |

## Nix in the image

| fact | measured | source |
|---|---|---|
| The image already ships Nix 2.34.6, installed by nix-installer into root's default profile, with no daemon. `setup.sh` uses it instead of installing another. | 2026-10-03 | probe 1 |
| The Bash tool's `PATH` starts with `/nix/var/nix/profiles/default/bin`. | 2026-10-03 | probe 1 |
| A flake's `nixConfig` is ignored unless `accept-flake-config = true` is set. | 2026-10-03 | probe 1 |
| With `cache.nixos.org` allowed, the nixpkgs source is substituted from the cache by its `narHash`, without touching GitHub. | 2026-10-03 | probe 4 |
| `sherd`'s dev shell takes 34 s cold and grows `/nix/store` from 103 MB to 3.7 GB. | 2026-10-03 | probes 4, 6 |

## The network

| fact | measured | source |
|---|---|---|
| "Include default list of common package managers" does **not** cover the nixos.org hosts. The proxy refused `cache.nixos.org` and `channels.nixos.org` until they were added by name. | 2026-10-03 | probes 1-3 |
| Cargo needs `index.crates.io` and `static.crates.io` added by name. | 2026-10-03 | probe 4 |
| Editing the allowed domains does not reach a session that is already running. Start a new session. | 2026-10-03 | probe 4 |

## GitHub

GitHub traffic goes through a GitHub proxy, separately from the allowlist.

| fact | measured | source |
|---|---|---|
| Nix `github:` inputs fail with 403. They fetch an archive tarball (`github.com/<owner>/<repo>/archive/<rev>.tar.gz`) or call the GitHub API, which the proxy refuses unless the repository is attached to the session. | 2026-10-03 | probe 2 |
| Plain git reads of the owner's public repositories pass: `git ls-remote`, and Nix `git+https://github.com/<owner>/<repo>` inputs. | 2026-10-03 | probes 2, 5 |
| A git read of a third-party repository (`actions/checkout`) fails with 403 unless `github.com` is in the allowed domains. With it, the read passes. | 2026-10-03 | probe 5, sherd #96 session |
| The in-session `add_repo` tool, given a public repository, answers "read_available" and attaches nothing. | 2026-10-03 | probe 1, sherd #96 session |
| Tools that send `GH_TOKEN` get the placeholder value `proxy-injected` and fail with 401. zizmor's online audit is one. Run such tools offline or without the token. | 2026-10-03 | sherd #97 session |

## Git and commits

| fact | measured | source |
|---|---|---|
| The clone is shallow (`git rev-parse --is-shallow-repository` prints `true`). Guards that read history need `git fetch --unshallow` first. | 2026-10-03 | probe 1 |
| Commits are authored as `Claude <noreply@anthropic.com>`, ssh-signed, and the harness adds a `Claude-Session:` trailer. | 2026-10-03 | probe 1 |
| A pushed branch gets a random suffix, for example `claude/nix-probe-8yxk95`. | 2026-10-03 | probe 1 |

## Claude Code in the session

| fact | measured | source |
|---|---|---|
| `~/.claude/skills` exists at launch, holding the harness's `session-start-hook` and the skills synced from the account (`synced/<id>/...`). There is no `~/.claude/settings.json`. Whether skills placed there by `setup.sh` survive the session start is still open. | 2026-10-03 | probe 1 |
| The `ANTHROPIC_MODEL` environment variable does not choose the model. A session with it set to Sonnet 5.5 ran on Opus 5.5. | 2026-10-03 | probe 6 |
| `claude --cloud "<task>" --model sonnet` runs the session on Sonnet 5.5: configured model, served model and commit trailer all agree. Putting `--model` before the task fails with `--cloud requires a description`. | 2026-10-03 | probe 7 |
| A Bash command still running at 120 s is not killed. It moves to the background and finishes (limit 30 min); its real exit status arrives with the completion notice. | 2026-10-03 | probe 6 |

## Timings

| what | time | measured | source |
|---|---|---|---|
| `sherd` dev shell, cold | 34 s | 2026-10-03 | probe 4 |
| `sherd` dev shell, cold, `git+https` inputs and no overrides | 33 s | 2026-10-03 | probe 7 |
| `cargo test` on `sherd` | 12.5 s, and 31 s in a later session | 2026-10-03 | probes 5, 7 |
| `hk check --all` on `sherd` | 2m45s; 3m43s cold (8m33s of CPU) | 2026-10-03 | probes 5, 6 |

## Cost

| fact | measured | source |
|---|---|---|
| 8 short sessions (7 probes and 1 job, 7 of them on Opus 5.5) cost about $7 in total, roughly $0.90 per session. The split between sessions is not measured yet. | 2026-10-03 | usage page |

## Still open

- Does a second session in the same environment reuse the snapshot and skip
  the setup script, and how much faster does it start? (`SPEC.md` T55)
- Do skills placed in `~/.claude/skills` by the setup script survive until
  Claude starts? (T14, T56)
- Is `raw.githubusercontent.com` reachable while the setup script runs?
  (T57)
- Which git version does the image ship? Not recorded yet (noted
  2026-10-03). Ubuntu 24.04 packages 2.43, but nobody has run
  `git --version` in a session. It matters: a session commits with that
  git, outside the dev shell, and only git 2.54 or newer runs the gate's
  config-based hooks; an older one runs only the `.git/hooks` shims.
  `probe.sh` now prints it as `git-version` and `git-config-hooks`.
  (T86, V32)
