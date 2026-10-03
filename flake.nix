{
  # The repo's own toolchain: the gate (hk and the linters it calls) for the
  # shell and nix files that set up Nix inside a Claude Code cloud session.
  # The root file is a wiring diagram -- inputs, systems, one import per
  # output -- and everything with a body lives in `nix/*.nix`.
  description = "nix-claude-code-cloud -- Nix and an agent home inside Claude Code cloud sessions";

  # hk is built by `nix-hk` and pushed to this cache. Without the substituter
  # every entry into the dev shell builds hk from source.
  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [
      "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM="
    ];
  };

  # ONE nixpkgs (SPEC C14): every input follows `nixpkgs-lock`, so the lock
  # holds a single nixpkgs node and the cachix builds of hk and xenolith are
  # hits rather than local rebuilds against a second revision.
  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";

    nix-hk = {
      url = "github:pr0d1r2/nix-hk";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
    };

    xenolith = {
      url = "github:pr0d1r2/xenolith";
      inputs = {
        nixpkgs-lock.follows = "nixpkgs-lock";
        nix-hk.follows = "nix-hk";
      };
    };
  };

  outputs =
    inputs@{ nixpkgs, nix-hk, ... }:
    let
      # Where the gate runs: the owner's laptop and the Linux of CI and of
      # the cloud session itself.
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      # The overlay makes `pkgs.hk` mean nix-hk's hk (V23: >= 1.55) rather
      # than whatever nixpkgs ships.
      forAll =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f {
            inherit system;
            pkgs = nixpkgs.legacyPackages.${system}.extend nix-hk.overlays.default;
          }
        );
    in
    {
      devShells = forAll (
        { pkgs, system }:
        {
          default = import ./nix/dev-shell.nix { inherit inputs pkgs system; };
        }
      );
    };
}
