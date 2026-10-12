# `nix flake check` outputs. Each check calls a script of its own, so no
# shell lives inside nix strings (SPEC C15).
{
  pkgs,
  xnl,
  src,
  cloudHome,
  claudinixDev,
  nix-rtk,
}:
let
  # The skills the agent home ships, one list for the home and its check.
  skills = import ./cloud-skills.nix;

  # The rtk the agent home installs, for this system. Only the home
  # system builds it (rtk-twins below), so other systems never realise it.
  rtk = nix-rtk.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # The agent home exists for one system only (x86_64-linux, the cloud
  # VM), so only that system checks its skills landed (nix:T16).
  homeSystem = cloudHome.pkgs.stdenv.hostPlatform.system;
  onHomeSystem = pkgs.stdenv.hostPlatform.system == homeSystem;
in
{
  # One language per file over the whole source tree (SPEC C15, T20).
  # `git` because xnl asks git for the file list first.
  xenolith = pkgs.runCommand "xenolith-check" {
    nativeBuildInputs = [
      xnl
      pkgs.git
    ];
  } "bash ${../scripts/nix/xenolith-check.sh} ${src} $out";

  # The dev crate builds and its `cargo test` passes in the checkPhase
  # (dev:C30, dev:C31).
  claudinix-dev = claudinixDev;

  # nix-rtk follows our nixpkgs-lock and rtk-src, so its cachix build is
  # only hit while both locks agree on their revs (nix:T151, B44, .:C14).
  rtk-pin = pkgs.runCommand "rtk-pin-check" {
    nativeBuildInputs = [ pkgs.jq ];
  } "bash ${../scripts/nix/rtk-pin-check.sh} ${src}/flake.lock ${nix-rtk}/flake.lock $out";
}
// pkgs.lib.optionalAttrs onHomeSystem {
  # The cavekit and caveman skills, FORMAT.md, the set rules and rtk are in
  # the activation package (nix:T16, nix:V14), its settings merge writes
  # exactly the cloud permissions (T101), and the caveman hooks and
  # statusLine run existing scripts by absolute paths (nix:V46).
  cloud-home =
    pkgs.runCommand "cloud-home-check" { nativeBuildInputs = [ pkgs.jq ]; }
      "bash ${../scripts/nix/cloud-home-check.sh} ${cloudHome.activationPackage} ${./cloud-permissions.json} $out ${toString skills.linked}";

  # The pinned rtk's own hook says which cloud permission rules it
  # rewrites; each needs its `rtk ` twin (.:V44, B53). The fast guard
  # knows git and cargo only; this catches a tool a new rtk rewrites.
  rtk-twins = pkgs.runCommand "rtk-twins-check" {
    nativeBuildInputs = [ pkgs.jq ];
  } "bash ${../scripts/nix/rtk-twins-check.sh} ${rtk}/bin/rtk ${./cloud-permissions.json} $out";
}
