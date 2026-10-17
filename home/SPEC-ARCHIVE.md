# SPEC ARCHIVE

Task rows moved out of `SPEC.md` by `mth archive`, then a second table,
`## §B BUGS` below §T, with fixed bug rows moved by hand (`mth archive`
appends only to §T). An id is never reused
(`V12`), so a citation to an archived row still resolves -- here.

This is a SINK, not a spec. The citations inside these rows point into
`SPEC.md`, so `mth check` on this file reports every one of them as dangling,
correctly and uselessly. The verb that reads it is `mth tasks`.

## §T TASKS

T155|x|move the `nix` skill, hook & toggle invariants (V45-V47) & their bugs (B50, B51) here; archived tasks T151, T153, T154 stay in `nix` as history (moving them rewrites 58 cites), not an unfinished move|V45,V46,V47,B50,B51

## §B BUGS

Bug rows moved out of `SPEC.md` by hand: fixed, each with its fix or invariant on record (`mth archive` moves only §T rows).

id|date|cause|fix
B46|2026-10-09|`caveman-commit` ("skip the body") in sessions; `commit-msg` refuses that|V45; skill dropped
B47|2026-10-09|check matched strings; moved `src/hooks` passed|V46: script must exist
B48|2026-10-09|`statusLine` ran `bash` from PATH|V46: absolute interpreter
B49|2026-10-09|hook timeout 5 vs upstream 30; slow start drops terse mode|V46: timeout ≥ 30
B52|2026-10-12|rtk 0.51 rewrite of `git push origin claude/x` got no allow|`.:V44`
B54|2026-10-12|`push … HEAD:claude/x -f` matched `HEAD:*` allow (#28)|deny `-f` \& rtk twins
B55|2026-10-12|deny `*-f` refused `claude/review-f` (#29)|deny ` -f` as a word
B56|2026-10-12|`-uf`/`-fu` force-pushed past the deny (#29)|deny both as words; `-nf`… B58
