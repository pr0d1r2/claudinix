# The skills the agent home ships (SPEC nix:T154, nix:V47): the toggles
# in agent-home.toml, switched on. `cloud-home.nix` links them,
# `checks.nix` hands the same names to the check.
let
  toggles = builtins.fromTOML (builtins.readFile ./agent-home.toml);
  on = table: builtins.filter (name: table.${name}) (builtins.attrNames table);
  cavekit = on toggles.cavekit;
  caveman = on toggles.caveman;
  has = name: builtins.elem name caveman;
in
assert
  !(has "caveman-commit")
  || throw "nix/agent-home.toml: caveman-commit must stay false -- it drops the commit body the commit-msg gate requires (nix:V45)";
{
  # The source directory names, per plugin.
  inherit cavekit caveman;

  # What lands in ~/.claude/skills: cavekit's as `ck-<name>`, so
  # caveman's own `caveman` keeps its bare name.
  linked = map (name: "ck-${name}") cavekit ++ caveman;

  # Skills that bring more than themselves.
  cavecrew = has "cavecrew";
  stats = has "caveman-stats";
}
