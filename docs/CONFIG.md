# The per-repo config file: `.claudinix.toml`

A repository can keep its claudinix choices in one small file at its root,
`.claudinix.toml`, instead of repeating them as flags every time. The tools
that run against a project read it: `domains`, `inputs`, `guide`, `probe`,
`nix-dev` and the cache check in CI.

**The file is optional.** Most repositories need none. Without it every tool
does what it always did, and no tool even calls Nix to look for it.

## Where the file is found

`scripts/config.sh` is the one reader. It takes the first of these:

1. `CLAUDINIX_CONFIG_JSON`, an internal handoff between tools: the effective
   config a calling tool (`guide`, `nix-dev`) already read, passed on so the
   run reads the file once. It is checked like a file, and no file is read
   and no `nix` call is made. You do not set it by hand;
2. with `--dir DIR` (`domains`, `inputs` and `guide` pass the project
   directory they were given): `.claudinix.toml` at the top level of the git
   repository DIR is in, else `DIR/.claudinix.toml`. `CLAUDINIX_CONFIG` is
   not consulted, so one project's file is never read for another;
3. without `--dir`: the file named in the `CLAUDINIX_CONFIG` environment
   variable, else `.claudinix.toml` at the top level of the git repository
   the current directory is in, else `.claudinix.toml` in the current
   directory.

A run makes at most one `nix eval`: `guide` and `nix-dev` pass the parsed
config on to the tools they call. `domains` given several project
directories reads each project's own file.

A missing file is not an error. A directory given with `--dir` that does not
exist is:

```text
config: no directory /nonexistent -- nothing was read
```

## Keys

Every key is optional, but a file that exists must say `version = 1`.

The table is generated from the schema in
[`scripts/config.jq`](../scripts/config.jq) by
`claudinix-dev config --write`, and the gate fails when it no longer
matches.

<!-- BEGIN config: generated from scripts/config.jq by `claudinix-dev config --write`; do not edit -->
| key | type | default | read by |
|---|---|---|---|
| `version` | the number `1` | none; required in a file | every reader (the file is refused without it) |
| `session.model` | `"sonnet"` or `"opus"` | `"sonnet"` | `guide` (its answer to the model question in step 5), `probe` (`--model`) |
| `session.agent_home` | `true` or `false` | `false` | `guide` (adds ` --agent-home` to the setup line it copies) |
| `devshell.installable` | string, no whitespace, quote, backtick or control character | `"."` | `nix-dev` (the installable when you give none), `guide` (the first dev shell check), `probe` (the dev shell the probe task runs) |
| `network.extra_domains` | list of bare hostnames | `[]` | `domains` (hosts added to the list, source `config`) |
| `cache.name` | string matching `^[a-z0-9][a-z0-9-]*$` | `"pr0d1r2"` | `inputs` (the cache it asks), `ci/verify-cachix.sh` (the cache it verifies) |
| `cache.push_sources` | `true` or `false` | `false` | nothing yet: reserved for the central cache job, which is not built |
| `probe.branch_prefix` | string, no whitespace, quote, backtick or control character | `"claude/nix-probe"` | `probe` (the branch the session pushes its report on) |
<!-- END config -->

`.` as `devshell.installable` means a bare `nix develop`, which is what the
tools did before the file existed. The per-tool detail is in
[`CLI.md`](CLI.md).

## Precedence

A flag or an environment variable beats the file, and the file beats the
built-in default:

```text
flag (or env var)  >  .claudinix.toml  >  default
```

For example `probe --model opus` runs on Opus whatever `session.model` says,
and `INPUTS_CACHES` beats `cache.name`.

## Validation

The reader checks the whole file and reports **every** problem, one line
each, then exits 2. Each line names the file as it was given and the key:

```text
config: /work/app/.claudinix.toml: version must be 1, got 2
config: /work/app/.claudinix.toml: unknown table [nope] (known: cache, devshell, network, probe, session)
config: /work/app/.claudinix.toml: session.agent_home must be true or false, got "yes"
config: /work/app/.claudinix.toml: unknown key session.bogus (known: session.agent_home, session.model, devshell.installable, network.extra_domains, cache.name, cache.push_sources, probe.branch_prefix)
config: /work/app/.claudinix.toml: session.model must be "sonnet" or "opus", got "gpt"
```

A file that is not TOML at all:

```text
config: /work/app/.claudinix.toml: cannot be read as TOML (error: while parsing TOML: [error] bad format: unknown value appeared)
```

An unknown key asked of `config.sh get`:

```text
config: unknown key nope.x (known: session.agent_home, session.model, devshell.installable, network.extra_domains, cache.name, cache.push_sources, probe.branch_prefix)
```

### Value rules

A value of the right type must also make sense:

- every string must be non-empty;
- `cache.name` is a cachix cache name: it matches `^[a-z0-9][a-z0-9-]*$`
  (lowercase letters, digits and hyphens, not starting with a hyphen);
- each `network.extra_domains` entry is a bare hostname: letters, digits,
  dots and hyphens, with no scheme, path, port or space, no leading or
  trailing dot or hyphen (also inside a label), and no wildcard;
- `devshell.installable` and `probe.branch_prefix` have no whitespace,
  quote, backtick or control character, because they are printed into shell
  commands and a prompt.

Every problem is reported at once, and the exit status is 2:

```text
config: /work/app/.claudinix.toml: cache.name must be a cachix cache name (lowercase letters, digits and hyphens, not starting with a hyphen), got "My_Cache"
config: /work/app/.claudinix.toml: devshell.installable must have no space, quote or control character, got "path:./a b"
config: /work/app/.claudinix.toml: network.extra_domains: "https://x.example.org" is not a bare hostname (letters, digits, dots and hyphens; no scheme, path, port or space)
config: /work/app/.claudinix.toml: network.extra_domains: "*.example.org" is not a bare hostname (letters, digits, dots and hyphens; no scheme, path, port or space)
config: /work/app/.claudinix.toml: probe.branch_prefix must not be empty, got ""
```

A tool that reads the file stops with that exit 2 before it does anything
else, so a typo never turns into a silently ignored setting. A missing
`version`, an unknown table or key, a wrong type, a bad value and a
`version` other than 1 are all refused.

## What it needs

Nix parses the file (`builtins.fromTOML`, through `nix eval`), so a cloud
session needs no other TOML parser, and `jq` checks the schema and fills in
the defaults. Both must be on `PATH` when a file exists:

```text
config: jq is not on PATH -- cannot read the config
config: nix is not on PATH -- cannot read /work/app/.claudinix.toml
```

Those exit 1. With no file there is no `nix` call at all. `setup.sh`
installs the reader (`config.sh`, `config.jq`) beside `nix-dev`, so
`nix-dev` can read the file in a session. A `nix-dev` installed before that
change reads no file.

## Reading it by hand

`scripts/config.sh [--dir DIR] get KEY | json | check`:

| command | output |
|---|---|
| `json` | the effective config, defaults merged, as JSON |
| `get TABLE.KEY` | one value; a list prints one item per line |
| `check` | nothing; exit 0 when the file is valid or absent |

## This repository's own file

claudinix keeps one, and `config.sh json` prints what is in effect here:

```toml
version = 1

[session]
model = "sonnet"
agent_home = false

[devshell]
installable = ".#default"

[cache]
name = "pr0d1r2"
push_sources = true

[probe]
branch_prefix = "claude/nix-probe"
```

```text
$ scripts/config.sh get session.model
sonnet
```

The gate checks it with the `claudinix-config` step
([`INTEGRATION.md`](INTEGRATION.md)).

## What is not in it

- **`setup.sh` never reads it.** The setup script runs once for the whole
  environment, which many repositories share, so it cannot know which
  repository's file to trust. Its choices live in the setup line you paste.
- **The agent home is an environment choice.** Whether a session gets the
  agent home is set by ` --agent-home` on the setup line
  ([`SETUP.md`](SETUP.md)). `session.agent_home` only tells `guide` whether
  to put that flag on the line it copies for you.
- **No secrets.** The file is committed with the repository.
