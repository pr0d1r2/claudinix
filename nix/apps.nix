# Flake apps: the target-project tools, run FROM the project you will send
# to the cloud (SPEC I.cmd):
#
#   nix run github:pr0d1r2/nix-claude-code-cloud#inputs
#
# Each app is its bats-covered script read verbatim, never shell written
# here (C15). The scripts find their data files (`*.jq`, detectors)
# through NCCC_SCRIPTS, which points at a store copy of `scripts/`.
{ pkgs }:
let
  app =
    {
      name,
      script ? name,
      runtimeInputs,
      description,
      runtimeEnv ? { },
    }:
    {
      type = "app";
      program = pkgs.lib.getExe (
        pkgs.writeShellApplication {
          inherit name runtimeInputs;
          text = builtins.readFile (../scripts + "/${script}.sh");
          runtimeEnv = {
            NCCC_SCRIPTS = "${../scripts}";
          }
          // runtimeEnv;
        }
      );
      meta = { inherit description; };
    };
in
{
  inputs = app {
    name = "inputs";
    runtimeInputs = [
      pkgs.jq
      pkgs.curl
      pkgs.coreutils
    ];
    description = "List a flake's github inputs: cached, or attach to the session";
  };

  domains = app {
    name = "domains";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
    ];
    runtimeEnv.NCCC_ALLOWLIST = "${../allowlist.txt}";
    description = "Print the allowed domains a cloud environment needs for a project";
  };

  # git, claude and `script` come from the caller's PATH: their own
  # credentials and the TTY form of `script` this OS has.
  probe = app {
    name = "probe";
    script = "probe-launch";
    runtimeInputs = [ pkgs.coreutils ];
    runtimeEnv.PROBE_SCRIPT = "${../probe.sh}";
    description = "Start a cloud session that probes this project, print its report";
  };
}
