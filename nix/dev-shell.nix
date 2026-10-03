# The dev shell: every tool the gate in `hk.pkl` calls, pinned by
# `flake.lock` (SPEC C14). CI and the git hooks enter this same shell, so a
# local pass and a CI pass mean the same thing (V17, V22).
{
  pkgs,
  xnl,
}:
pkgs.mkShellNoCC {
  packages = [
    pkgs.hk
    pkgs.pkl
    pkgs.git
    pkgs.bats
    pkgs.parallel
    pkgs.coreutils
    pkgs.shellcheck
    pkgs.shfmt
    pkgs.nixfmt
    pkgs.typos
    pkgs.ripsecrets
    pkgs.actionlint
    pkgs.zizmor
    xnl
  ];

  LANG = "C.UTF-8";

  # bats runs one test at a time unless told otherwise; every test works in
  # its own BATS_TEST_TMPDIR (V21), so they can run together through
  # `parallel` above. 4 = the cloud VM's vCPUs (T52), and the suite is
  # I/O-bound, so a laptop gains little from more.
  BATS_NUMBER_OF_PARALLEL_JOBS = "4";
  HK_JOBS = "4";

  # Entering the shell installs the hk hooks (V17). The logic lives in a
  # bats-covered script, read here rather than inlined (C14, C15).
  shellHook = "${pkgs.writeShellScript "nccc-shell-hook" (
    builtins.readFile ../scripts/dev/shell-hook.sh
  )}";
}
