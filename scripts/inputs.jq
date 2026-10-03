# Every `github` node of a flake.lock with the store path of its source,
# once per owner/repo/rev (SPEC scripts:T25, I.cmd `inputs`).
#
# Input: `-n --slurpfile lock flake.lock --slurpfile arch archive.json`,
# where archive.json is `nix flake archive --dry-run --json DIR`.
# Output: one line per input, `owner/repo rev path` (path may be empty).
#
# The archive tree is keyed by input name and leaves out `follows` edges,
# so walking the lock from its root through plain (string) edges, side by
# side with the tree, maps each lock node to its path.

$lock[0] as $l
| def paths($key; $tree):
    [$key, ($tree.path // "")],
    (($l.nodes[$key].inputs // {})
     | to_entries[]
     | select(.value | type == "string")
     | paths(.value; ($tree.inputs[.key] // {})));
(reduce paths($l.root; $arch[0]) as [$key, $path] ({}; .[$key] = $path)) as $path
| [$l.nodes
   | to_entries[]
   | select(.value.locked.type? == "github")
   | [.value.locked.owner + "/" + .value.locked.repo, .value.locked.rev, ($path[.key] // "")]]
| unique_by(.[0:2])[]
| join(" ")
