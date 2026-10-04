# Performance
Find where the change costs time, network, disk or tokens it does not need to.
- Work repeated per file, per commit or per session that could run once.
- Network fetches, nix evaluations or builds on a hot path such as a git hook or session start.
- Gate steps whose globs make them run on unrelated commits.
- Give a measurement or a clear count for each finding, not a guess.
