# A measured example

[`SETUP.md`](SETUP.md) says what to click. This page shows what it was like
on a real repository: [`pr0d1r2/sherd`](https://github.com/pr0d1r2/sherd), a
Rust command line tool with a Nix flake dev shell and an hk gate. Every number
comes from a probe session run on 2026-10-03 and recorded in
[`FACTS.md`](FACTS.md). The sessions ran in a cloud environment named `nix`,
set up from this repository's files. The timings are one-off readings, not
benchmarks: the machine is a shared VM and the same step moved between
sessions.

## The target

`sherd` has a `flake.nix` with a dev shell (Rust toolchain, linters, `hk`), a
committed `flake.lock`, `cargo test`, and a gate run by `hk check --all`. It is
a good test because it needs everything the setup is meant to provide: Nix,
a cache for the dev shell, crates.io, and GitHub reads for the gate.

## Zero to a working dev shell

1. **Environment.** Created once at claude.ai/code from this repository's
   `setup.sh`, `allowlist.txt` and `env-names.txt`. Network access was
   **Custom** with the default package-manager list, plus the allowed domains
   from `allowlist.txt`, including the nixos.org hosts the default list did not
   cover. The setup script in the dialog was then the contents of `setup.sh`
   pasted in whole. The one-line setup script that [`SETUP.md`](SETUP.md)
   now describes did not exist yet, so none of these sessions used it.
2. **Choose it.** `/remote-env`, pick `nix`.
3. **Start a session** from a checkout of `sherd` with the branch pushed. The
   probe prompt asked for the session facts, then for the dev shell and the
   tests.

What the first probes found, in order, and what fixed each:

| what happened | fix | measured |
|---|---|---|
| `nix develop` tried to build from source and failed: the proxy refused `cache.nixos.org` and `channels.nixos.org`. | name both in the allowed domains | probes 1-3 |
| `github:` inputs failed with a 403. | fetch small inputs as `git+https://github.com/<owner>/<repo>`; get large ones from a cache | probe 2 |
| The nixpkgs source was substituted from `cache.nixos.org` by its `narHash`, without touching GitHub. | none needed once the host was allowed | probe 4 |
| Cargo needs its registry hosts. | add `index.crates.io` and `static.crates.io` | probe 4 |

## The timings

| step | time | session |
|---|---|---|
| dev shell, cold | 34 s | probe 4 |
| dev shell, cold, `git+https` inputs, no overrides | 33 s | probe 7 |
| `cargo test` | 12.5 s | probe 5 |
| `cargo test` in a later session | 31 s | probe 7 |
| `hk check --all` | 2 min 45 s | probe 5 |
| `hk check --all`, cold | 3 min 43 s (8 min 33 s of CPU) | probe 6 |

Also from those sessions: the machine had 4 vCPUs, 15 GB of RAM and about 30 GB
of free disk, and the dev shell grew `/nix/store` from 103 MB to 3.7 GB.

`hk check --all` took longer than 120 seconds, and the Bash tool did not kill
it: a command still running at 120 s moves to the background and finishes, and
its real exit status arrives with the completion notice. Wait for that notice
and do not read the 120-second return as the result (probe 6).

## The one red step

In probe 5, `hk check --all` was green except `zizmor`, the workflow auditor,
which ran an online audit. It tried to read `actions/checkout` through git and
got a 403 from the proxy, because `github.com` was not yet in the allowed
domains. Once `github.com` was added, third-party git reads passed (the `sherd`
#96 session). Separately, a tool that sends `GH_TOKEN` gets the placeholder
`proxy-injected` and a 401 (`sherd` #97 session), so the fix is to run
zizmor offline. [`CONSUMER.md`](CONSUMER.md) states the rule.

## What it cost

Eight short sessions in all (seven probes and one job, seven of them on
Opus 5.5) came to about $7, roughly $0.90 per session. That figure is not split
by session, and it is a rough reading from the usage page
([`MODEL.md`](MODEL.md)).

## Reproduce it

You need your own cloud environment ([`SETUP.md`](SETUP.md)) and a repository
that meets the checklist in [`CONSUMER.md`](CONSUMER.md). Then:

```sh
claude --cloud "Run: nix --version && nix develop -c true && echo DEVSHELL-OK. Report the output." --model sonnet
```

Then, inside a session, run `bash probe.sh` from a copy of this repository and
compare its lines with the table in
[`RUNBOOK.md`](RUNBOOK.md). If your numbers differ much from the ones above,
record them in `FACTS.md` with the date.
