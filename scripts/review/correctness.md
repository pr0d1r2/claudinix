# Correctness
Find where the change does the wrong thing: wrong output, a crash, or a broken invariant.
- Trace each changed path with concrete inputs, including empty, missing, malformed and boundary values.
- Check error handling: exit codes, `set -euo pipefail` traps, partial failure that leaves state half-written.
- Check the tests prove the behaviour the spec row asks for, and would fail without the change.
- Check every `§V` invariant the change touches still holds.
