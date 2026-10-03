# Flake apps: the target-project tools, run FROM the project you will send
# to the cloud (SPEC I.cmd):
#
#   nix run github:pr0d1r2/nix-claude-code-cloud#inputs
#
# Each app is its bats-covered script read verbatim, never shell written
# here (C15). The scripts find their data files (`*.jq`, detectors)
# through NCCC_SCRIPTS, which points at a store copy of `scripts/`.
{ pkgs, rev }:
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

  # claude, gh, git, the opener and the clipboard come from the caller's
  # PATH. NCCC_SETUP_REV pins the setup line to the commit this app was
  # built from: the store copy is not a git clone, so without it the guide
  # stops at step 3. A dirty tree has no rev, and the guide says so.
  guide = app {
    name = "guide";
    runtimeInputs = [
      pkgs.jq
      pkgs.curl
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
    ];
    runtimeEnv = {
      NCCC_SETUP_REV = rev;
      NCCC_ALLOWLIST = "${../allowlist.txt}";
      NCCC_MODEL_DOC = "${../docs/MODEL.md}";
      NCCC_ENV_NAMES = "${../env-names.txt}";
    };
    description = "Walk the cloud environment setup steps from the terminal";
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
