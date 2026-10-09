# The skills the agent home ships (SPEC nix:T153): `cloud-home.nix` links
# them, `checks.nix` hands the same names to the check.
{
  # cavekit's skills (SPEC.md workflow): the commands `/ck:*` would run,
  # all nine of v4.1.0 (nix:T153).
  cavekit = [
    "spec"
    "build"
    "check"
    "backprop"
    "caveman"
    "deepen"
    "grill"
    "research"
    "review"
  ];

  # The caveman plugin's skills the owner runs locally (nix:T153). Its own
  # `caveman` skill is left out: cavekit's holds that name, and the hooks
  # in cloud-home.nix read caveman's copy straight from the source. `caveman-commit`
  # is left out too: it competes with the commit-msg gate (nix:V45).
  caveman = [
    "caveman-review"
    "caveman-help"
    "caveman-compress"
  ];
}
