# Correctness
Find where the change does the wrong thing: wrong output, a crash, or a broken invariant.
- Trace each changed path with concrete inputs, including empty, missing, malformed and boundary values.
- Check error handling: exit codes, `set -euo pipefail` traps, partial failure that leaves state half-written.
- Check the tests prove the behaviour the change claims, as far as the repository's docs or, if it has a spec, its rows say, and would fail without the change.
- If the repository has a spec with invariants (`§V`), check every one the change touches still holds.
