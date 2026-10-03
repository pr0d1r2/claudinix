# The schema of `.claudinix.toml` and the config it makes effective
# (SPEC scripts:T90, scripts:V34, I.file `.claudinix.toml`).
#
# Input: the file as `builtins.fromTOML` parsed it ({} when there is none).
# Args:  --arg file F       the file, as given, for messages (V26)
#        --argjson present  false when there is no file
#        --arg key K        "" for the whole config, else TABLE.KEY
# Output (with -r): the effective config, defaults merged; or K's value,
#        a list one item per line.
# Errors: every problem in the file, one line each, then exit 2.

# What the tools do without a file (V34: no file = today's behaviour).
# `.` as the installable is a bare `nix develop`.
def defaults: {
  version: 1,
  session: {model: "sonnet", agent_home: false},
  devshell: {installable: "."},
  network: {extra_domains: []},
  cache: {name: "pr0d1r2", push_sources: false},
  probe: {branch_prefix: "claude/nix-probe"}
};

def schema: {
  session: {model: "model", agent_home: "boolean"},
  devshell: {installable: "string"},
  network: {extra_domains: "strings"},
  cache: {name: "string", push_sources: "boolean"},
  probe: {branch_prefix: "string"}
};

def keynames: [schema | to_entries[] | .key as $t | .value | keys[] | "\($t).\(.)"] | join(", ");

def fits($kind):
  if $kind == "model" then . == "sonnet" or . == "opus"
  elif $kind == "strings" then type == "array" and all(.[]; type == "string")
  else type == $kind
  end;

def wanted($kind):
  {model: "\"sonnet\" or \"opus\"", strings: "a list of strings", string: "a string", boolean: "true or false"}[$kind];

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
         else empty
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
