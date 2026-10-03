# SPEC ARCHIVE

Task rows moved out of `SPEC.md` by `mth archive`. An id is never reused
(`V12`), so a citation to an archived row still resolves -- here.

This is a SINK, not a spec. The citations inside these rows point into
`SPEC.md`, so `mth check` on this file reports every one of them as dangling,
correctly and uselessly. The verb that reads it is `mth tasks`.

## §T TASKS

T1|x|GUARDRAILS FIRST: `flake.nix` (inputs `nixpkgs-lock`, `nix-hk`, `xenolith` w/ `follows`) devShell (hk, bats, `parallel`, shellcheck, shfmt, nixfmt, coreutils, kcov ?) + shellHook from file (`hk install`); `hk.pkl` from owner infra repo `hk.pkl` template (vendored `pkl/Config.pkl`, fast ⊂ all, commit-msg) w/ hk util hygiene, shellcheck, shfmt, nixfmt, typos, ripsecrets, actionlint, zizmor; parallel. ⊥ other task before T1,T19-T23 green|C7,C14,C18,V17,V18,V23
T2|x|import seed from owner's private seed repo `476cf1d` `cloud/envs/nix/` (16 bats; `accept-flake-config`, nixos.org, crates.io \& `github.com` hosts, `ANTHROPIC_MODEL` line marked as not choosing the model; crates.io → per-target per T30) → repo root (`setup.sh`, `allowlist.txt`, `env-names.txt`, `tests/unit/setup.bats`); fix paths; `just check` green|V1,V2,V3,V4,V6,V7,I.file
T3|x|`probe.sh`: `id`, PID 1 comm, systemd dir, `unshare -Ur true`, profile sourcing, `nix --version`, `nix config show substituters`, `nix flake metadata github:NixOS/nixpkgs` (direct fetch via proxy ok ?), locked-input substitution from cachix (input source w/ `narHash` pushed, ⊥ GitHub), `channels.nixos.org` tarball fetch, `nix-dev` tier reached, cachix narinfo hit, elapsed; bats w/ stubs|C8,V8,V9,I.file
T4|x|MANUAL create env `nix` at claude.ai/code from repo files; run 1 probe session; record facts → resolve C8 `?`, C6 `?`|C8,C6,V10,I.ext.env — done 2026-10-03: env `nix` created; probes 1-5 on sherd
T5|x|if probe: session uid ≠ root ∧ no systemd → make store usable (V9) \| switch install mode; bats|V9,V4 — not needed: session uid = root (probe 1)
T10|x|`just bump-nix <ver>`: fetch `install.sha256`, rewrite pin pair in `setup.sh`; owner reviews diff \& runs gate|V11,C4
T17|x|`setup.sh` tail: activate agent home w/ `nix:V15` failover as Claude's uid; seams `CLOUD_HOME_FLAKE`, `CLOUD_HOME_STOREPATH`; bats w/ stub `nix`|`nix:V14`,`nix:V15`,V7,I.file
T19|x|guard scripts: `bats-mirror` (unicoverage, both directions), `tdd-order` (RED in parent of GREEN, `-M`), `commit-msg` (Conventional + `Why:`); reused per C17; pre-push \| all; each w/ own bats (RED→GREEN)|C16,C17,V17,V19
T20|x|xenolith step `xnl check {{files}}` + `checks.<sys>.xenolith`; `xenolith.toml` (languages nix, shell)|C15,V18
T21|x|owner tools steps: `mth` on `SPEC.md`, `itok check` + `.context-limits`, `sherd validate`\|`budget`; pinned inputs w/ `follows`; via `scripts/hk/run-tool.sh` (V18)|C20,V18
T22|x|pklith ?: `.pklith` → `hk.pklith.pkl` imported by `hk.pkl`, `pklith check` step; adopt only if generated steps pass C15 purity (else upstream pklith issue: emit `scripts/hk/*.sh` calls) \& render C14-C20 steps ⊥ loss|C20,C15,V19 — decided 2026-10-03: ⊥ adopt; pklith v0.1.0 (`4aa83e0`) still emits inline `command -v … \|\| {…}` per step ⇒ C15 breach; keep hand `hk.pkl`; upstream issue (emit `scripts/hk/*.sh` calls) pending owner OK to file
T23|x|CI `.github/workflows/ci.yml`: gate + `nix flake check` + cachix push on default branch + verify job (narinfo 200); kcov line-coverage job ? w/ ratchet|C19,V22,C16
T24|x|UI line: `setup.sh` takes `<sha>` arg; `scripts/setup-line.sh` prints line for HEAD; bats. split 2026-10-03: SETUP.md half → `docs:T70`, CI-green gate → T69|V20,C19,V10
T29|x|open question: does `github.com` in Allowed domains (added 2026-10-03) or `add_repo` read let a session read 3rd-party public repos (`git ls-remote https://github.com/actions/checkout`)? answer → `allowlist.txt` keep\|drop + docs|C6,V10 — answered: `github.com` allowed ⇒ 3rd-party git reads pass; `add_repo` read = no-op
T30|x|base `allowlist.txt` = Nix-only hosts (cachix, `cache.nixos.org`, `channels.nixos.org`, `releases.nixos.org`); ecosystem hosts (crates.io…) come from `apps.domains` per target, ⊥ hardcoded; SETUP shows both|C6,I.cmd,`scripts:T27`
T48|x|`env-names.txt`: optional `BASH_DEFAULT_TIMEOUT_MS=600000` (E4: default backgrounds at 120 s, ⊥ kills); SETUP + guide show them|V24,I.file
T58|x|EXP E3 `ANTHROPIC_MODEL` effective: commit trailer of next session names Sonnet 5.5|I.file,`docs:T42` — answered 2026-10-03 (probe 6): env var ⊥ effective; launcher model wins. follow-up E3b: does `claude --cloud --model sonnet` set it? (T67)
T59|x|EXP E4 bash timeouts: `hk check --all` (2m45s) w/ \& w/o timeout env vars|V24,T48 — answered 2026-10-03 (probe 6): cold `hk check --all` 3m43s, backgrounded at 120 s, ⊥ killed
T60|x|EXP E5 resources + snapshot reuse: `nproc; free -g; df -h /`; 2 sessions back to back, compare start|T52,T55 — resources answered 2026-10-03 (probe 6); snapshot reuse still open (T55)
T61|x|EXP E6 3rd-party GitHub reads w/ `github.com` allowed + `add_repo` (running in sherd #96 step 0)|T29,C6 — answered: `github.com` allowed ⇒ 3rd-party git reads pass; `add_repo` read = no-op
T67|x|EXP E3b: launch w/ `claude --cloud --model sonnet`; check `get_session.configured_model` \& commit trailer; probe launcher (`scripts:T28`) passes `--model` always|T58,`scripts:T28`,I.cmd — answered 2026-10-03 (probe 7): `claude --cloud "<task>" --model sonnet` ⇒ configured, served \& trailer = Sonnet 5.5; `--model` before the task fails (`--cloud requires a description`)
T68|x|C11 config block: cachix host + key + repo slug as variables at top of `setup.sh`, used by every later line; `docs/FORKING.md` → 1 place; bats: block edit alone retargets cache \& repo|C11,V3,I.file
T69|x|setup line safety: `scripts/setup-line.sh` refuses a REV whose CI run on default branch is not green (`gh run list --commit`) unless `--force`; `setup.sh` fetches nix-dev at its SHA arg (⊥ `main`); bats w/ stubbed `gh`\|`curl`|V20,C19,I.file
