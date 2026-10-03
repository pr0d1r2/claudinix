# The schema of `.claudinix.toml` and the config it makes effective
# (SPEC scripts:T90, scripts:T95, scripts:V34, I.file `.claudinix.toml`).
#
# Input: the file as `builtins.fromTOML` parsed it ({} when there is none).
# Args:  --arg file F       the file, as given, for messages (V26)
#        --argjson present  false when there is no file
#        --arg key K        "" for the whole config, else TABLE.KEY
# Output (with -r): the effective config, defaults merged; or K's value,
#        a list one item per line.
# Errors: every problem in the file, one line each, then exit 2.

# The schema, ONE object: every key of every table, its type, its
# default (what the tools do without a file, V34: no file = today's
# behaviour), the rule its value must also meet, and the tools that read
# it.
#   type:    "string", "boolean" or "strings" (a list of strings)
#   values:  the only strings allowed
#   pattern: a regex the string must match (with rule "cachix")
#   rule:    "hostname" (each entry a bare hostname), "cachix" (a cachix
#            cache name) or "shell" (printed into shell commands and a
#            prompt: no space, quote or control character)
# `.` as the installable is a bare `nix develop`.
def schema: {
  session: {
    model: {type: "string", values: ["sonnet", "opus"], default: "sonnet", readers: "`guide` (its answer to the model question in step 5), `probe` (`--model`)"},
    agent_home: {type: "boolean", default: false, readers: "`guide` (adds ` --agent-home` to the setup line it copies)"}
  },
  devshell: {
    installable: {type: "string", rule: "shell", default: ".", readers: "`nix-dev` (the installable when you give none), `guide` (the first dev shell check), `probe` (the dev shell the probe task runs)"}
  },
  network: {
    extra_domains: {type: "strings", rule: "hostname", default: [], readers: "`domains` (hosts added to the list, source `config`)"}
  },
  cache: {
    name: {type: "string", rule: "cachix", pattern: "^[a-z0-9][a-z0-9-]*$", default: "pr0d1r2", readers: "`inputs` (the cache it asks), `ci/verify-cachix.sh` (the cache it verifies)"},
    push_sources: {type: "boolean", default: false, readers: "nothing yet: reserved for the central cache job, which is not built"}
  },
  probe: {
    branch_prefix: {type: "string", rule: "shell", default: "claude/nix-probe", readers: "`probe` (the branch the session pushes its report on)"}
  }
};

# What the tools do without a file: every default, and the version.
def defaults: {version: 1} + (schema | map_values(map_values(.default)));

def keynames: [schema | to_entries[] | .key as $t | .value | keys[] | "\($t).\(.)"] | join(", ");

def fits($spec):
  if $spec.type == "strings" then type == "array" and all(.[]; type == "string")
  elif $spec.values then . as $v | any($spec.values[]; . == $v)
  else type == $spec.type
  end;

def wanted($spec):
  if $spec.values then $spec.values | map(tojson) | join(" or ")
  else {strings: "a list of strings", string: "a string", boolean: "true or false"}[$spec.type]
  end;

# A bare hostname: dot-separated labels of letters, digits and hyphens,
# none starting or ending with a hyphen; no scheme, path, port or space.
def hostname:
  test("^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)*$");

# bad($key; $spec): the problems with a value of the right type
# (scripts:T95), each naming the key and the value. A "shell" value gets
# printed into shell commands and a prompt: no space, quote or control
# character, so quoting it is never ambiguous.
def bad($key; $spec):
  if $spec.rule == "hostname" then
    .[]
    | select(hostname | not)
    | "\($key): \(tojson) is not a bare hostname (letters, digits, dots and hyphens; no scheme, path, port or space)"
  elif type != "string" then empty
  elif . == "" then "\($key) must not be empty, got \"\""
  elif $spec.rule == "cachix" and (test($spec.pattern) | not) then
    "\($key) must be a cachix cache name (lowercase letters, digits and hyphens, not starting with a hyphen), got \(tojson)"
  elif $spec.rule == "shell" and test("[[:space:][:cntrl:]'\"`]") then
    "\($key) must have no space, quote or control character, got \(tojson)"
  else empty
  end;

def problems:
  (if has("version") | not then "version = 1 is missing"
   elif .version != 1 then "version must be 1, got \(.version | tojson)"
   else empty
   end),
  (to_entries[]
   | select(.key != "version")
   | .key as $t
   | .value as $v
   | if schema | has($t) | not then
       if $v | type == "object" then "unknown table [\($t)] (known: \(schema | keys | join(", ")))"
       else "unknown key \($t) (known: version, \(keynames))"
       end
     elif $v | type != "object" then "\($t) must be a table ([\($t)]), got \($v | tojson)"
     else
       $v
       | to_entries[]
       | .key as $k
       | .value as $x
       | if schema[$t] | has($k) | not then "unknown key \($t).\($k) (known: \(keynames))"
         elif $x | fits(schema[$t][$k]) | not then "\($t).\($k) must be \(wanted(schema[$t][$k])), got \($x | tojson)"
         else $x | bad("\($t).\($k)"; schema[$t][$k])
         end
     end);

[if $present then problems else empty end] as $problems
| if $problems | length > 0 then
    $problems | map("config: \($file): \(.)\n") | add | halt_error(2)
  else
    (defaults * .) as $config
    | if $key == "" then $config
      else
        ($key | split(".")) as $path
        | if ($path | length) == 2 and (schema[$path[0]] // {} | has($path[1])) then
            $config | getpath($path) | if type == "array" then .[] else . end
          else "config: unknown key \($key) (known: \(keynames))\n" | halt_error(2)
          end
      end
  end
