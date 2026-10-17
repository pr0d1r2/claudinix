# Fleet
Find what this change breaks in the other repositories that consume this one, on their next pin bump.
- Find every consumer under the same owner: `gh search code "<owner>/<repo>" --owner <owner>`, and local checkouts of sibling repositories when they exist. A consumer is a repository that holds a flake input, a `uses: <owner>/<repo>/.github/workflows/…` line, a hook or hk reference, a `nix run …#app` call, or a vendored copy of this repository.
- For each consumer, say what the diff changes once it bumps its pin: a renamed or removed output, option, default, workflow input or hook id.
- Evidence for each finding is the consumer's `file:line` that still uses the old name or value.
- A change nothing consumes is not a finding; say that no consumer was found rather than padding.
- Suggest the fix: keep the old name, add a shim, or name the consumer change its owner must make.
