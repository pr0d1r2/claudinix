# Every `github` node of a flake.lock with the shortest input path that
# reaches it, for `--override-input` (SPEC scripts:T12, scripts:V13).
#
# Input: flake.lock. Output: `path owner/repo rev ref` per node, where
# path is `a/b` for input b of input a, and ref is the original ref (the
# nixpkgs channel) or `-`. Only plain (string) edges are walked: a
# `follows` edge points at a node some other path already reaches.

.nodes as $n
| def edges($key; $prefix):
    ($n[$key].inputs // {})
    | to_entries[]
    | select(.value | type == "string")
    | ($prefix + [.key]) as $p
    | [.value, $p], edges(.value; $p);
[edges(.root; [])]
| group_by(.[0])
| map(min_by(.[1] | length))[]
| . as [$key, $path]
| $n[$key]
| select(.locked.type? == "github")
| "\($path | join("/")) \(.locked.owner)/\(.locked.repo) \(.locked.rev) \(.original.ref // "-")"
