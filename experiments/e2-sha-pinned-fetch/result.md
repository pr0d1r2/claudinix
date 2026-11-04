# E2 result: SHA-pinned fetch (2026-11-04)

Re-run of `prompt.md` in a cloud session after the first run's figures were not
kept. Scope: inside a running session. The setup phase before Claude starts was
not tested.

| item | value |
|---|---|
| REPO | `pr0d1r2/claudinix` |
| SHA | `acca896d4dca9081c40ef5be52d4c88815e80337` |
| HTTP status | 200 |
| sha256 of fetched `setup.sh` | `4885ac1e2975bd62491b39f96780ac7d735fb2d7285669ede207fb92be830d29` |
| sha256 of `git show $SHA:setup.sh` | `4885ac1e2975bd62491b39f96780ac7d735fb2d7285669ede207fb92be830d29` (same) |
| store path | `/nix/store/6sg8jrk2xzpj6h0jmkipp82h48mlskjn-home-manager-generation` |
| wall time of `nix build` | 7.7 s |
| caches seen in the log | `pr0d1r2.cachix.org` (home-manager paths); the first run, 8.8 s, also used `cache.nixos.org` |
