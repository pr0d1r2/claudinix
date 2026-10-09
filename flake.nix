{
  # The repo's own toolchain: the gate (hk and the linters it calls) for the
  # shell and nix files that set up Nix inside a Claude Code cloud session.
  # The root file is a wiring diagram -- inputs, systems, one import per
  # output -- and everything with a body lives in `nix/*.nix`.
  description = "claudinix -- Nix and an agent home inside Claude Code cloud sessions";

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
    # git+https, not github: the agent home evaluates this input inside a
    # cloud session, where a `github:` tarball fetch is a 403 unless the
    # source is cached (C6, V30, B8). The same holds for the agent-home
    # inputs below; nixpkgs itself is substituted from cache.nixos.org
    # by its narHash (C8b). The dev-shell inputs (nix-hk, xenolith and the
    # spec tools) use git+https too, so `nix develop` of this repo works in
    # a cloud session without cached sources (T99, C29). A tag needs its
    # full `refs/tags/<tag>` ref: the git fetcher reads a bare ref as a
    # branch.
    nixpkgs-lock.url = "git+https://github.com/pr0d1r2/nixpkgs-lock?ref=main&shallow=1";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";

    nix-hk = {
      url = "git+https://github.com/pr0d1r2/nix-hk?ref=main&shallow=1";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
    };

    xenolith = {
      url = "git+https://github.com/pr0d1r2/xenolith?ref=main&shallow=1";
      inputs = {
        nixpkgs-lock.follows = "nixpkgs-lock";
        nix-hk.follows = "nix-hk";
        itok.follows = "itok";
        microlith.follows = "microlith";
      };
    };

    # The spec toolchain (SPEC C20), pinned to release tags: microlith
    # formats and checks SPEC.md, itok counts its tokens against
    # `.context-limits`, sherd validates the federation and its budget.
    # itok names its hk input `hk`, microlith names it `nix-hk`; both
    # follow the same node so the shell holds one hk build.
    itok = {
      url = "git+https://github.com/pr0d1r2/itok?ref=refs/tags/v0.3.1&shallow=1";
      inputs = {
        nixpkgs-lock.follows = "nixpkgs-lock";
        hk.follows = "nix-hk";
        microlith.follows = "microlith";
      };
    };

    microlith = {
      url = "git+https://github.com/pr0d1r2/microlith?ref=refs/tags/v0.7.3&shallow=1";
      inputs = {
        nixpkgs-lock.follows = "nixpkgs-lock";
        nix-hk.follows = "nix-hk";
        itok.follows = "itok";
      };
    };

    sherd = {
      url = "git+https://github.com/pr0d1r2/sherd?ref=refs/tags/v0.5.3&shallow=1";
      inputs = {
        nixpkgs-lock.follows = "nixpkgs-lock";
        nix-hk.follows = "nix-hk";
      };
    };

    # The agent home (nix:T16, C12). home-manager's release matches the
    # locked nixpkgs (26.05) and follows it, so the activation package
    # shares cachix hits with everything else. The claude-code module and
    # set-and-setting are read as plain sources (`flake = false`): their
    # flakes carry ~50 dev-only inputs (linters, shells) that an
    # evaluation in a cloud session would have to fetch, and a `github:`
    # fetch there is a 403 unless cached (C6, B3). The files imported are
    # the ones their flakes export (`homeManagerModules.default`,
    # `lib.mkSet`). cavekit and caveman are plugins, read as plain sources
    # at a release tag (nix:T153). All are fetched over git+https (nix:T78,
    # V30); `shallow=1` keeps the clone to the locked commit.
    home-manager = {
      url = "git+https://github.com/nix-community/home-manager?ref=release-26.05&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-home-manager-claude-code = {
      url = "git+https://github.com/pr0d1r2/nix-home-manager-claude-code?ref=main&shallow=1";
      flake = false;
    };
    set-and-setting = {
      url = "git+https://github.com/pr0d1r2/set-and-setting?ref=main&shallow=1";
      flake = false;
    };
    cavekit = {
      url = "git+https://github.com/JuliusBrussee/cavekit?ref=refs/tags/v4.1.0&shallow=1";
      flake = false;
    };
    # caveman's hooks and skills (nix:T153), at a release tag like cavekit.
    caveman = {
      url = "git+https://github.com/JuliusBrussee/caveman?ref=refs/tags/v3.2.0&shallow=1";
      flake = false;
    };
    # rtk for the agent home (nix:T151). Branch `cached` only holds commits
    # whose build is in cachix. nix-rtk follows our nixpkgs-lock (one
    # nixpkgs) and our rtk-src: its own is `github:`, a 403 in a cloud
    # session unless cached (B44, V30); the same tag over git+https has
    # the same NAR, so the store path and the cachix hit stay. The
    # `rtk-pin` check fails when either rev leaves the one that build used
    # (rtk would then compile in every cloud setup).
    rtk-src = {
      url = "git+https://github.com/rtk-ai/rtk?ref=refs/tags/v0.51.0&shallow=1";
      flake = false;
    };
    nix-rtk = {
      url = "git+https://github.com/pr0d1r2/nix-rtk?ref=cached&shallow=1";
      inputs = {
        nixpkgs-lock.follows = "nixpkgs-lock";
        rtk-src.follows = "rtk-src";
      };
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-hk,
      xenolith,
      itok,
      microlith,
      sherd,
      home-manager,
      nix-home-manager-claude-code,
      set-and-setting,
      cavekit,
      caveman,
      nix-rtk,
      rtk-src,
      ...
    }:
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
            # Only the languages this repo has (SPEC C15): a smaller binary
            # with only the linters those languages call.
            xnl = xenolith.packages.${system}.default.override {
              languages = [
                "nix"
                "shell"
              ];
            };
            specTools = map (flake: flake.packages.${system}.default) [
              itok
              microlith
              sherd
            ];
          }
        );
    in
    {
      # The repo-only Rust tool (dev:C30): never in a session closure.
      packages = forAll (
        { pkgs, ... }:
        {
          claudinix-dev = import ./nix/claudinix-dev.nix { inherit pkgs; };
        }
      );

      devShells = forAll (
        {
          system,
          pkgs,
          xnl,
          specTools,
          ...
        }:
        {
          default = import ./nix/dev-shell.nix {
            inherit pkgs xnl specTools;
            claudinixDev = self.packages.${system}.claudinix-dev;
          };
        }
      );

      apps = forAll (
        { pkgs, ... }:
        import ./nix/apps.nix { inherit pkgs; }
      );

      checks = forAll (
        {
          system,
          pkgs,
          xnl,
          ...
        }:
        import ./nix/checks.nix {
          inherit pkgs xnl;
          src = self;
          cloudHome = self.homeConfigurations.cloud;
          inherit (inputs) nix-rtk;
          claudinixDev = self.packages.${system}.claudinix-dev;
        }
      );

      # The agent home `setup.sh` activates in a cloud session (nix:T16).
      homeConfigurations.cloud = import ./nix/cloud-home.nix {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        inherit
          home-manager
          nix-home-manager-claude-code
          set-and-setting
          cavekit
          caveman
          nix-rtk
          rtk-src
          ;
      };
    };
}
