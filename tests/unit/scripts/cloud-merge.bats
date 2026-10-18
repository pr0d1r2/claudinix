#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/cloud-merge.sh (SPEC cloud:T160, cloud:V51,
# .:C29). git and gh are stubs: nothing reaches GitHub and nothing is
# merged.

# shellcheck source=/dev/null # the cross-repo fixture
load helpers/cross-repo.bash

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../scripts/cloud-merge.sh"
    export STUBS="$BATS_TEST_TMPDIR/stubs"
    export STATE="$BATS_TEST_TMPDIR/state"
    export TOPLEVEL="$BATS_TEST_TMPDIR/project"
    unset CLAUDINIX_PROJECTS CLOUD_TASK_REMOTE STUB_PR STUB_BRANCH STUB_DIRTY GH_MERGE_RC
    mkdir -p "$STUBS" "$STATE" "$TOPLEVEL"

    # git: a work tree at $TOPLEVEL on $STUB_BRANCH (default main), clean
    # unless $STUB_DIRTY.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$STATE/git.log"' \
        'case "$*" in' \
        '-C\ *) exec "$STUBS/git-real" "$@" ;;' \
        'remote\ get-url\ *) echo https://github.com/o/p ;;' \
        'symbolic-ref*) echo "${STUB_BRANCH:-main}" ;;' \
        'rev-parse\ --show-toplevel) echo "$TOPLEVEL" ;;' \
        'status\ --porcelain*) printf "%s" "${STUB_DIRTY:-}" ;;' \
        'pull\ --ff-only*) ;;' \
        '*) exit 9 ;;' \
        'esac' >"$STUBS/git"
    # gh: a `pr view` that asks for the checks answers the PR's fields merged
    # into $STATE/pr.json; one that does not answers the open-PR TSV.
    # `pr diff` answers $STATE/pr.diff; `pr merge` logs and exits
    # $GH_MERGE_RC.
    cat >"$STUBS/gh" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$STATE/gh.log"
fields="${STUB_PR:-8\tOPEN\tclaude/scripts-T9\tmain\thttps://github.com/o/p/pull/8\tfalse}"
case "$*" in
*statusCheckRollup*)
    printf '%b\n' "$fields" | jq -R 'split("\t") | {number: (.[0] | tonumber), state: .[1], headRefName: .[2], baseRefName: .[3], url: .[4], isCrossRepository: (.[5] == "true")}' |
        jq -c --slurpfile checks "$STATE/pr.json" '. + $checks[0]'
    ;;
*isCrossRepository*) printf '%b\n' "$fields" ;;
pr\ diff*) cat "$STATE/pr.diff" ;;
pr\ merge*) exit "${GH_MERGE_RC:-0}" ;;
*) exit 9 ;;
esac
STUB
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"

    # Every role is a file in review/ (cloud:I.cmd), non-security ones here.
    ROLES="$(for f in "$BATS_TEST_DIRNAME"/../../../scripts/review/*.md; do basename "$f" .md; done | grep -vx security | tr '\n' ' ')"
    GREEN='[{"status":"COMPLETED","conclusion":"SUCCESS"},{"status":"COMPLETED","conclusion":"SKIPPED"}]'
    pr_json "$GREEN" 'Findings: 0' end
    diff_of scripts/x.sh '-a' '+b'
}

# pr_json ROLLUP SECURITY_TAIL FIXUP: the verdict read's answer: head
# abc123, checks ROLLUP, a review comment per role (security's ending in
# SECURITY_TAIL) and a Fixup: reply at the `end`, the `start` or `none`.
pr_json() {
    jq -n --arg roles "$ROLES" --argjson rollup "$1" --arg sec "$2" --arg fix "$3" '
        ($roles | split(" ") | map(select(. != ""))) as $r
        | ([$r[] | {authorAssociation: "OWNER", body: ("## Review: " + . + "\n\nNo findings.\n\nFindings: 0")}]
            + [{authorAssociation: "OWNER", body: ("## Review: security\n\nRead the diff.\n\n" + $sec)}]) as $reviews
        | {headRefOid: "abc123", statusCheckRollup: $rollup,
           comments: (if $fix == "end" then $reviews + [{authorAssociation: "OWNER", body: "Fixup:\n\nNothing to fix.\n\nHead: abc123"}]
                      elif $fix == "start" then [{authorAssociation: "OWNER", body: "Fixup:\n\nearly"}] + $reviews
                      else $reviews end | map(.createdAt = "2026-10-15T12:00:00Z"))}' >"$STATE/pr.json"
}

# diff_of FILE LINE...: a one-hunk patch of FILE with LINEs (each `-old`
# or `+new`).
diff_of() {
    local file="$1"
    shift
    {
        printf 'diff --git a/%s b/%s\n--- a/%s\n+++ b/%s\n@@ -1 +1 @@\n' "$file" "$file" "$file" "$file"
        printf '%s\n' "$@"
    } >"$STATE/pr.diff"
}

merged() {
    grep -q '^pr merge 8 --rebase --match-head-commit abc123' "$STATE/gh.log"
}

not_merged() {
    if merged; then return 1; fi
}

not_pulled() {
    if grep -q "^pull" "$STATE/git.log"; then return 1; fi
}

# --- the happy path ---

@test "every rule holds: merges #8 by rebase at the head it judged, then pulls main" {
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 0 ]
    merged
    grep -q '^pull --ff-only' "$STATE/git.log"
    [[ "$output" == *"merge: merged #8"* ]]
}

@test "the pull request is read once: one gh pr view for the open check and the verdict" {
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 0 ]
    [ "$(grep -c '^pr view' "$STATE/gh.log")" = 1 ]
}

@test "after the merge, a branch other than main or a dirty tree is not pulled" {
    export STUB_BRANCH=feature/y
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 0 ]
    merged
    not_pulled
    export STUB_BRANCH=main STUB_DIRTY=' M x'
    : >"$STATE/git.log"
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 0 ]
    not_pulled
}

@test "--dry-run judges, prints the gh command and merges nothing" {
    run bash "$SCRIPT" 8 --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"gh pr merge 8 --rebase --match-head-commit abc123"* ]]
    not_merged
}

@test "without --yes, only y merges" {
    run bash "$SCRIPT" 8 <<<'n'
    [ "$status" -eq 1 ]
    [[ "$output" == *"not merged"* ]]
    not_merged
    run bash "$SCRIPT" 8 <<<'y'
    [ "$status" -eq 0 ]
    merged
}

@test "gh refusing the merge (the head moved): exit 1, says so" {
    export GH_MERGE_RC=1
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"gh did not merge #8"* ]]
}

# --- the strict rule: each stops for the owner and says why ---

@test "a red, a pending or no check on the head: stops, naming CI" {
    for rollup in '[{"status":"COMPLETED","conclusion":"FAILURE"}]' \
        '[{"status":"IN_PROGRESS","conclusion":""}]' '[{"state":"PENDING"}]' '[]'; do
        pr_json "$rollup" 'Findings: 0' end
        run bash "$SCRIPT" 8 --yes
        [ "$status" -eq 1 ] || {
            echo "merged with checks $rollup"
            return 1
        }
        [[ "$output" == *"stops for the owner"* ]]
        [[ "$output" == *"CI"* ]]
    done
    not_merged
}

@test "a neutral check is green, as in the wait of just all (cloud:B68)" {
    pr_json '[{"status":"COMPLETED","conclusion":"SUCCESS"},{"status":"COMPLETED","conclusion":"NEUTRAL"}]' 'Findings: 0' end
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 0 ]
    merged
}

@test "Review: security-deep or a regex-like role is not Review: security (cloud:B69)" {
    jq '.comments |= map(if (.body | startswith("## Review: security")) then .body |= sub("security"; "security-deep") else . end)' "$STATE/pr.json" >"$STATE/p" && mv "$STATE/p" "$STATE/pr.json"
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *'no "Review: security" comment'* ]]
    not_merged
    mkdir -p "$BATS_TEST_TMPDIR/scripts/review"
    touch "$BATS_TEST_TMPDIR/scripts/review/sec.rity.md"
    pr_json "$GREEN" 'Findings: 0' end
    CLAUDINIX_SCRIPTS="$BATS_TEST_TMPDIR/scripts" run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *'no "Review: sec.rity" comment'* ]]
}

@test "a Findings: 0 that is not the last line of the security review: stops (cloud:B70)" {
    pr_json "$GREEN" $'Findings: 0\n\nOne blocker remains: see above.' end
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"security"* ]]
    not_merged
}

@test "the harness footer after Findings: is not the last line: 0 merges, 2 stops (cloud:B76)" {
    local footer=$'\n\n---\n_Generated by [Claude Code](https://claude.ai/code)_'
    pr_json "$GREEN" "Findings: 2$footer" end
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"security: 2 finding(s)"* ]]
    pr_json "$GREEN" "Findings: 0$footer" end
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 0 ]
    merged
}

@test "a role without its review: stops, naming the role" {
    jq '.comments |= map(select(.body | startswith("## Review: performance") | not))' "$STATE/pr.json" >"$STATE/p" && mv "$STATE/p" "$STATE/pr.json"
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"performance"* ]]
    not_merged
}

@test "no Fixup: reply after the reviews: stops" {
    for at in none start; do
        pr_json "$GREEN" 'Findings: 0' "$at"
        run bash "$SCRIPT" 8 --yes
        [ "$status" -eq 1 ]
        [[ "$output" == *"Fixup:"* ]]
    done
    not_merged
}

@test "reviews and a Fixup: from a stranger do not count (cloud:B64)" {
    for assoc in NONE CONTRIBUTOR FIRST_TIME_CONTRIBUTOR; do
        jq --arg a "$assoc" '.comments |= map(.authorAssociation = $a)' "$STATE/pr.json" >"$STATE/p" && mv "$STATE/p" "$STATE/pr.json"
        run bash "$SCRIPT" 8 --yes
        [ "$status" -eq 1 ] || {
            echo "merged on comments from $assoc"
            return 1
        }
        [[ "$output" == *"Review: security"* ]]
    done
    not_merged
}

@test "a MEMBER's reviews count (cloud:B64)" {
    jq '.comments |= map(.authorAssociation = "MEMBER")' "$STATE/pr.json" >"$STATE/p" && mv "$STATE/p" "$STATE/pr.json"
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 0 ]
    merged
}

@test "a Fixup: reply that names another head than the PR's: stops, naming the head (cloud:B73)" {
    jq '.headRefOid = "def456"' "$STATE/pr.json" >"$STATE/p" && mv "$STATE/p" "$STATE/pr.json"
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not name the head"* ]]
    not_merged
}

@test "a Fixup: reply edited to the new head after a CI-fix push merges (cloud:B73)" {
    jq '.headRefOid = "def456" | .comments[-1].body += "\nHead: def456"' "$STATE/pr.json" >"$STATE/p" && mv "$STATE/p" "$STATE/pr.json"
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 0 ]
    grep -q '^pr merge 8 --rebase --match-head-commit def456' "$STATE/gh.log"
}

@test "a Fixup: reply that names the head only inside a longer line stops (cloud:V51)" {
    jq '.headRefOid = "def456" | .comments[-1].body += "\nsee Head: def456 for the rest"' "$STATE/pr.json" >"$STATE/p" && mv "$STATE/p" "$STATE/pr.json"
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not name the head"* ]]
    not_merged
}

@test "security reported findings, or no Findings: line: stops, naming security" {
    for tail in 'Findings: 2' 'No blocking findings.'; do
        pr_json "$GREEN" "$tail" end
        run bash "$SCRIPT" 8 --yes
        [ "$status" -eq 1 ]
        [[ "$output" == *"security"* ]]
    done
    not_merged
}

@test "the diff touches a file the owner keeps: stops, naming the file" {
    for file in hk.pkl .github/workflows/ci.yml flake.lock nix/cloud-permissions.json; do
        diff_of "$file" '-a' '+b'
        run bash "$SCRIPT" 8 --yes
        [ "$status" -eq 1 ] || {
            echo "merged a change to $file"
            return 1
        }
        [[ "$output" == *"$file"* ]]
    done
    not_merged
}

@test "a change to the gate's own files: stops, naming the file (cloud:B67, cloud:B74, cloud:B77, cloud:B89)" {
    for file in scripts/guard/cloud-permissions.sh scripts/hk/run-tool.sh scripts/review/security.md \
        scripts/cloud-merge.sh scripts/lib/cloud-launch.sh scripts/cloud-review-prompt.txt \
        scripts/cloud-review.sh .claude/settings.json justfile \
        flake.nix nix/dev-shell.nix nix/checks.nix nix/apps.nix scripts/dev/session-start.sh \
        scripts/cloud-all.sh scripts/lib/spec-nodes.sh tests/unit/scripts/guard/tdd-order.bats scripts/cloud-drain.sh scripts/cloud-held.sh; do
        diff_of "$file" '-a' '+b'
        run bash "$SCRIPT" 8 --yes
        [ "$status" -eq 1 ] || {
            echo "merged a change to $file"
            return 1
        }
        [[ "$output" == *"$file"* ]]
    done
    not_merged
}

@test "every CLOUD_MERGE_KEPT entry exists in the tree, so a moved gate file is noticed (cloud:B74)" {
    local root="$BATS_TEST_DIRNAME/../../.." kept
    # shellcheck source=/dev/null # the library under test
    source "$root/scripts/lib/cloud-launch.sh"
    for kept in "${CLOUD_MERGE_KEPT[@]}"; do
        [ -e "$root/$kept" ] || {
            echo "missing: $kept"
            return 1
        }
    done
}

@test "a rename into, out of or a mode change of a kept file: stops, naming it (cloud:B66)" {
    printf 'diff --git a/x.yml b/.github/workflows/x.yml\nsimilarity index 100%%\nrename from x.yml\nrename to .github/workflows/x.yml\n' >"$STATE/pr.diff"
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *".github/workflows/x.yml"* ]]
    printf 'diff --git a/hk.pkl b/old.pkl\nsimilarity index 100%%\nrename from hk.pkl\nrename to old.pkl\n' >"$STATE/pr.diff"
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"hk.pkl"* ]]
    printf 'diff --git a/flake.lock b/flake.lock\nold mode 100644\nnew mode 100755\n' >"$STATE/pr.diff"
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"flake.lock"* ]]
    not_merged
}

@test "the diff changes a §C or §V row of a spec: stops; a §T row or an archive does not" {
    diff_of cloud/SPEC.md '-- C7: old' '+- C7: new'
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud/SPEC.md"* ]]
    diff_of SPEC.md '+V99: a new rule'
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    not_merged
    diff_of cloud/SPEC.md '-T5|.|x|-' '+T5|x|x|-'
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 0 ]
    : >"$STATE/gh.log"
    diff_of cloud/SPEC-ARCHIVE.md '+V7: archived text'
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 0 ]
    merged
}

@test "a .context-limits ceiling raised or added: stops; one lowered does not" {
    diff_of .context-limits '-scripts/SPEC.md  4200' '+scripts/SPEC.md  4700'
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *".context-limits"* ]]
    diff_of .context-limits '+web/SPEC.md 900'
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    not_merged
    diff_of .context-limits '-scripts/SPEC.md  4700' '+scripts/SPEC.md  4200'
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 0 ]
    merged
}

@test "every reason is named, not only the first" {
    pr_json '[{"status":"COMPLETED","conclusion":"FAILURE"}]' 'Findings: 1' end
    diff_of hk.pkl '+x'
    run bash "$SCRIPT" 8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"CI"* ]]
    [[ "$output" == *"security"* ]]
    [[ "$output" == *"hk.pkl"* ]]
}

# --- the pull request itself ---

@test "a fork, another base or a closed PR: refused before any verdict" {
    for answer in '8\tOPEN\tx\tmain\thttps://github.com/o/p/pull/8\ttrue' \
        '8\tOPEN\tx\tdev\thttps://github.com/o/p/pull/8\tfalse' \
        '8\tMERGED\tx\tmain\thttps://github.com/o/p/pull/8\tfalse'; do
        export STUB_PR="$answer"
        run bash "$SCRIPT" 8 --yes
        [ "$status" -eq 1 ]
    done
    not_merged
    if grep -q '^pr diff' "$STATE/gh.log"; then return 1; fi
}

@test "a URL of another repository is refused; no argument or an unknown flag is usage" {
    run bash "$SCRIPT" https://github.com/other/repo/pull/8 --yes
    [ "$status" -eq 1 ]
    not_merged
    run bash "$SCRIPT"
    [ "$status" -eq 2 ]
    run bash "$SCRIPT" 8 --force
    [ "$status" -eq 2 ]
}

@test "another repository's URL is refused even with its checkout in CLAUDINIX_PROJECTS: merge never enters one (V60, B107)" {
    cross_fixture
    run bash "$SCRIPT" https://github.com/owner/alpha/pull/8 --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"run it from a checkout of owner/alpha"* ]]
    [ ! -e "$STATE/gh.log" ]
}
