# Third-party notices

This repository is shell, Nix and Markdown. It vendors one schema file and
depends on other people's work in three ways: things the setup script
downloads and runs, things the dev shell and the gate run, and things the
agent home installs. Each is listed with the licence its owner
declares. Nothing from the list below is copied into this repository except
where a section says so.

Licences were checked on 2026-10-03 where this file says "checked"; for
anything else, the licence in the upstream repository is the authority.

## Run by the setup script on a session VM

| what | how it is used | licence |
|---|---|---|
| [Nix](https://github.com/NixOS/nix) | The image ships Nix. `setup.sh` uses it, and installs the pinned upstream release (2.35.2) from `releases.nixos.org` only when the image is below the floor. The installer is downloaded and run, never copied here. | LGPL-2.1 (checked) |
| `cache.nixos.org` and [Cachix](https://www.cachix.org) | Binary caches the VM reads from. Services, not software shipped here. | not applicable |

## Vendored

### `pkl/Config.pkl`

The schema `hk.pkl` amends, copied verbatim from [hk](https://hk.jdx.dev) at
the release named in `hk.pkl` (v1.58.1), so the gate needs no network. It is
not edited; `typos` excludes it for that reason.

- Upstream: <https://github.com/jdx/hk>
- Licensed under the MIT License, Copyright (c) 2025 Jeff Dickey (checked)

## Run by the gate and the dev shell

All of these come from the flake's dev shell and are pinned by `flake.lock`.
They are separate programs the gate runs. None is linked into or copied
into this repository, and each keeps its own licence.

| tool | what it does here | licence |
|---|---|---|
| [hk](https://github.com/jdx/hk), through [nix-hk](https://github.com/pr0d1r2/nix-hk) | the gate runner | MIT (checked) |
| [xenolith](https://github.com/pr0d1r2/xenolith) | one language per file | MIT, same owner |
| [microlith](https://github.com/pr0d1r2/microlith), [itok](https://github.com/pr0d1r2/itok), [sherd](https://github.com/pr0d1r2/sherd) | format, token-count and federate `SPEC.md` | MIT, same owner |
| ShellCheck | shell linter | GPL-3.0-only |
| shfmt | shell formatter | BSD-3-Clause |
| nixfmt | Nix formatter | MPL-2.0 |
| bats, GNU parallel, pkl, typos, ripsecrets, actionlint, zizmor | tests and checks | see each project |
| [just](https://github.com/casey/just), [jq](https://github.com/jqlang/jq), [gh](https://github.com/cli/cli) | `just` runs the recipes, `jq` reads `flake.lock` and JSON, and `gh` asks GitHub whether CI passed (read-only); the dev shell also ships them | see each project |

The three licences listed for ShellCheck, shfmt and nixfmt are the ones the
owner's xenolith notices record for the same nixpkgs packages. Running a
GPL-licensed linter over this repository's files does not make the files
GPL-licensed, and shipping none of them is why this repository carries no
GPL text.

## The agent home

The home-manager configuration `homeConfigurations.cloud`
(`nix/cloud-home.nix`) is built from the following flake inputs, and
`setup.sh` activates it in a session. That activation has not yet been run
in a real cloud session. It also uses the owner's
`pr0d1r2/nix-home-manager-claude-code` module, whose licence is not
recorded here.

### cavekit

The spec skills (`spec`, `build`, `check`, `backprop`, `caveman`) and the
`FORMAT.md` they cite come from cavekit, as a non-flake input. The owner's
microlith vendors the same project's format file under the same terms.

- Upstream: <https://github.com/JuliusBrussee/cavekit>
- Copyright (c) 2026 Julius Brussee
- Licensed under the MIT License

```text
MIT License

Copyright (c) 2026 Julius Brussee

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### set-and-setting

The owner's skill sets, built into the agent home with its `mkSet` helper.

- Upstream: <https://github.com/pr0d1r2/set-and-setting>
- Licensed under the MIT License, Copyright (c) 2026 Marcin Nowicki

### home-manager

The agent home is a standalone home-manager configuration, which is MIT
licensed upstream (not checked here): <https://github.com/nix-community/home-manager>.

## Trademarks

Nominative use only; no affiliation or endorsement is implied.

- **NixOS** and **Nix** are trademarks of the NixOS Foundation.
- **GitHub** is a trademark of GitHub, Inc.
- **Claude** and **Anthropic** are trademarks of Anthropic PBC.
- **Ubuntu** is a trademark of Canonical Ltd.

## `claudinix` itself

Everything not covered above is licensed under the MIT License. See
[`LICENSE`](../LICENSE).
