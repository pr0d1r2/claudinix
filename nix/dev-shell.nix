# The dev shell: every tool the gate in `hk.pkl` calls, pinned by
# `flake.lock` (SPEC C14). CI and the git hooks enter this same shell, so a
# local pass and a CI pass mean the same thing (V17, V22).
{
  pkgs,
  xnl,
  specTools,
  claudinixDev,
}:
# mkShell, not mkShellNoCC: cargo links through the C compiler, so the
# Rust steps of the gate need one in the shell (dev:C31).
pkgs.mkShell {
  packages = [
    pkgs.hk
    pkgs.pkl
    pkgs.git
    # The target-project apps read flake.lock with jq (scripts:T25).
    pkgs.jq
    pkgs.just
    # setup-line.sh asks GitHub whether CI passed (read-only).
    pkgs.gh
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
    # The dev crate's gate (dev:C31): fmt, clippy and tests on `dev/**`.
    pkgs.cargo
    pkgs.rustc
    pkgs.clippy
    pkgs.rustfmt
    # The README badges and the INTEGRATION step counts (dev:C30). Built
    # without its tests: a RED commit must still get a shell to commit in.
    (claudinixDev.overrideAttrs { doCheck = false; })
  ]
  ++ specTools;

  LANG = "C.UTF-8";

  # bats runs one test at a time unless told otherwise; every test works in
  # its own BATS_TEST_TMPDIR (V21), so they can run together through
  # `parallel` above. 4 = the cloud VM's vCPUs (T52), and the suite is
  # I/O-bound, so a laptop gains little from more.
  BATS_NUMBER_OF_PARALLEL_JOBS = "4";
  HK_JOBS = "4";

  # Entering the shell installs the hk hooks (V17). The logic lives in a
  # bats-covered script, read here rather than inlined (C14, C15).
  shellHook = "${pkgs.writeShellScript "claudinix-shell-hook" (
    builtins.readFile ../scripts/dev/shell-hook.sh
  )}";
}
