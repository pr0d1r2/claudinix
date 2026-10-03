# Flake apps: the target-project tools, run FROM the project you will send
# to the cloud (SPEC I.cmd):
#
#   nix run github:pr0d1r2/claudinix#inputs
#
# Each app is its bats-covered script read verbatim, never shell written
# here (C15). The scripts find their data files (`*.jq`, detectors) and
# the config reader (`config.sh`, scripts:T91) through CLAUDINIX_SCRIPTS,
# which points at a store copy of `scripts/`. The reader parses a
# project's .claudinix.toml with the caller's own `nix` from PATH, as
# `inputs` already runs it; every app ships jq for it.
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
            CLAUDINIX_SCRIPTS = "${../scripts}";
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
    description = "List a flake's github inputs: cached, or uncached (nix-dev fetches those over git)";
  };

  domains = app {
    name = "domains";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
    ];
    runtimeEnv.CLAUDINIX_ALLOWLIST = "${../allowlist.txt}";
    description = "Print the allowed domains a cloud environment needs for a project";
  };

  # claude, the opener and the clipboard come from the caller's PATH.
  # The setup line is the release's, read from a store copy of the README
  # (.:C25), so the app needs neither gh nor a clone; `--rev SHA` asks
  # setup-line.sh instead, and that needs gh and git on the caller's PATH.
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
      CLAUDINIX_README = "${../README.md}";
      CLAUDINIX_ALLOWLIST = "${../allowlist.txt}";
      CLAUDINIX_MODEL_DOC = "${../docs/MODEL.md}";
      CLAUDINIX_ENV_NAMES = "${../env-names.txt}";
    };
    description = "Walk the cloud environment setup steps from the terminal";
  };

  # git, claude and `script` come from the caller's PATH: their own
  # credentials and the TTY form of `script` this OS has. jq reads the
  # project's .claudinix.toml through config.sh (scripts:T91).
  probe = app {
    name = "probe";
    script = "probe-launch";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    runtimeEnv.PROBE_SCRIPT = "${../probe.sh}";
    description = "Start a cloud session that probes this project, print its report";
  };
}
