# The agent home (SPEC nix:T16, C12): what `setup.sh` activates for the
# user Claude runs as in a cloud session -- root, `/root` (C8, nix:V14).
#
# The pattern is the owner's home configuration (`claude-home.nix`): the claude-code
# home-manager module plus a set from set-and-setting. `mkTrip` is not
# upstream yet (nix:T15), so the set is built with `mkSet` directly.
# Plugins are not installed in the cloud, so cavekit's skills and the
# FORMAT.md they read are materialized into ~/.claude as plain files.
#
# Agent-level only (nix:V16): skills and the settings Claude reads. No
# language toolchain -- the target repo's devShell owns those (C3).
{
  pkgs,
  home-manager,
  nix-home-manager-claude-code,
  set-and-setting,
  cavekit,
  nix-rtk,
  rtk-src,
}:
let
  # set-and-setting's flake exports exactly this as `lib.mkSet`.
  mkSet = import "${set-and-setting}/set/lib/mk-set.nix" { inherit (pkgs) lib; };

  # The categories that apply to any repo an agent works in here; the
  # NixOS and lefthook ones serve the owner's own machine, not a cloud VM.
  # `concepts` off: they describe the owner's own machines, not a cloud VM.
  skillSet = mkSet {
    inherit pkgs;
    concepts = false;
    categories = [
      "generic"
      "architecture"
      "ci"
      "git"
      "gnu"
      "just"
      "language"
      "nix"
      "security"
      "test"
      "update"
    ];
  };

  # cavekit's skills (SPEC.md workflow): the commands `/ck:*` would run.
  cavekitSkills = [
    "spec"
    "build"
    "check"
    "backprop"
    "caveman"
  ];

  # rtk and the RTK.md `rtk init -g` writes, from the same source (nix:T151).
  rtk = nix-rtk.packages.${pkgs.stdenv.hostPlatform.system}.default;
  rtkMd = "${rtk-src}/hooks/rtk-awareness.md";

  skillFile = name: {
    name = ".claude/skills/${name}";
    value = {
      source = "${cavekit}/skills/${name}";
      recursive = true;
    };
  };
in
home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  modules = [
    {
      # home-manager ships its own `programs.claude-code`; the fleet's
      # module replaces it (as mkTrip does).
      disabledModules = [ "programs/claude-code.nix" ];
      imports = [ "${nix-home-manager-claude-code}/modules/default.nix" ];

      home = {
        username = "root";
        homeDirectory = "/root";
        stateVersion = "26.05";
        packages = [ rtk ];

        file = builtins.listToAttrs (map skillFile cavekitSkills) // {
          # The skills say "read FORMAT.md"; with no plugin root in the
          # cloud, ~/.claude is where they find it.
          ".claude/FORMAT.md".source = "${cavekit}/FORMAT.md";
          ".claude/RTK.md".source = rtkMd;
          # The set's rules and their always-on manifest, as
          # set-and-setting's README places them for home-manager.
          ".claude/rules/set" = {
            source = "${skillSet}/.claude/rules/set";
            recursive = true;
          };
          ".claude/rules/set.md".source = "${skillSet}/.claude/rules/set.md";
        };
      };

      # A session VM has no desktop, no man reader and no systemd (PID 1
      # is `process_api`, C8). Each of these would grow the closure that
      # setup substitutes inside its ~5 min cache window (C1, V5).
      # Measured against cache.nixos.org (`nix path-info -rS`, 2026-10-03,
      # over the activation script's own tools, ~93 MiB): the default
      # `programs.man` (man-db) adds ~24 MiB, and `systemd.user`, which
      # puts systemd into the activation script, adds ~129 MiB.
      manual = {
        manpages.enable = false;
        html.enable = false;
        json.enable = false;
      };
      programs.man.enable = false;
      xdg.mime.enable = false;
      systemd.user.enable = false;
      news.display = "silent";

      programs.claude-code = {
        enable = true;
        # The cloud harness installs Claude Code itself.
        package = null;
        # rtk rewrites Bash commands to `rtk <cmd>` (nix:T151); setup links
        # home-path/bin onto PATH so the rewritten command finds it.
        hooks.PreToolUse = [
          {
            matcher = "Bash";
            hooks = [
              {
                type = "command";
                command = "${rtk}/bin/rtk hook claude";
              }
            ];
          }
        ];
        claudeMd.fragments = [
          {
            content = "@RTK.md";
            order = 10;
          }
        ];
        # The one narrow rule list unattended cloud tasks need (T101),
        # merged into ~/.claude/settings.json at activation, before
        # Claude starts. Through the freeform `settings`: the module's
        # typed `permissions.allow` writes a literal "permissions.allow"
        # key, which Claude Code does not read.
        settings.permissions = builtins.fromJSON (builtins.readFile ./cloud-permissions.json);
      };
    }
  ];
}
