# `claudinix-dev`, the repo-only Rust tool (dev:C30): README badges and the
# step counts docs/INTEGRATION.md states, with their drift checks. std
# only, so `cargoLock` vendors nothing and the build needs no crates.io.
# The source is `dev/` alone, so a doc or shell change does not rebuild it.
# `cargo test` runs in the checkPhase; the dev shell takes the variant
# without it, because a RED commit (a failing test, C17) must not stop the
# shell that runs the hooks from building.
{ pkgs }:
let
  inherit (pkgs) lib;
in
pkgs.rustPlatform.buildRustPackage {
  pname = "claudinix-dev";
  version = "0.0.0";
  src = lib.fileset.toSource {
    root = ../dev;
    fileset = lib.fileset.unions [
      ../dev/Cargo.toml
      ../dev/Cargo.lock
      ../dev/src
    ];
  };
  cargoLock.lockFile = ../dev/Cargo.lock;
  meta = {
    description = "Development-only tooling for the claudinix repository";
    license = lib.licenses.mit;
    mainProgram = "claudinix-dev";
  };
}
