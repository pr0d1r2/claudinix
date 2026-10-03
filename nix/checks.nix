# `nix flake check` outputs. Each check calls a script of its own, so no
# shell lives inside nix strings (SPEC C15).
{
  pkgs,
  xnl,
  src,
}:
{
  # One language per file over the whole source tree (SPEC C15, T20).
  # `git` because xnl asks git for the file list first.
  xenolith = pkgs.runCommand "xenolith-check" {
    nativeBuildInputs = [
      xnl
      pkgs.git
    ];
  } "bash ${../scripts/nix/xenolith-check.sh} ${src} $out";
}
