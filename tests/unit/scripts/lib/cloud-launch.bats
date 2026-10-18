#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/lib/cloud-launch.sh, the launch rules that
# cloud-task.sh, cloud-rebase.sh and cloud-review.sh share (SPEC
# cloud:I.cmd, cloud:B19). claude and script are stubs; git is real,
# in a throwaway repository.

# shellcheck source=/dev/null # the cross-repo fixture, beside this directory
load ../helpers/cross-repo.bash

setup() {
    REPO="$BATS_TEST_DIRNAME/../../../.."
    LIB="$REPO/scripts/lib/cloud-launch.sh"
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_EXEC_PATH
    export STATE="$BATS_TEST_TMPDIR/state"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    mkdir -p "$STATE" "$STUBS"
    # claude: records its prompt and model.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'printf "%s" "$2" >"$STATE/claude.prompt"' \
        'printf "%s" "$4" >"$STATE/claude.model"' >"$STUBS/claude"
    # script: BSD form, as on macOS.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        '[ "$1" != --version ] || exit 1' \
        'while [ "$1" != /dev/null ]; do shift; done; shift; exec "$@"' >"$STUBS/script"
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"
    # shellcheck source=/dev/null
    source "$LIB"
}

# repo_with_upstream: a clone of a bare repository, one commit pushed.
repo_with_upstream() {
    git init -q --bare "$BATS_TEST_TMPDIR/origin.git"
    git clone -q "$BATS_TEST_TMPDIR/origin.git" "$BATS_TEST_TMPDIR/work" 2>/dev/null
    cd "$BATS_TEST_TMPDIR/work" || return 1
    git config user.email t@t
    git config user.name t
    git checkout -q -b main
    git commit -q --allow-empty -m one
    git push -q -u origin main 2>/dev/null
}

@test "cloud_fill replaces every key and keeps the value as written" {
    # shellcheck disable=SC2016 # the literal text, not an expansion
    local value='x & "y" $z'
    prompt='a @K@ b @K@'
    cloud_fill @K@ "$value"
    [ "$prompt" = "a $value b $value" ]
}

@test "cloud_fill does not fill a placeholder spelled in its own value" {
    prompt='@A@ @B@'
    cloud_fill @A@ '@B@'
    [ "$prompt" = '@B@ @B@' ]
}

@test "cloud_require_remote: a missing remote says to push the project first" {
    repo_with_upstream
    run cloud_require_remote review origin
    [ "$status" -eq 0 ]
    run cloud_require_remote review nowhere
    [ "$status" -eq 1 ]
    [ "$output" = "review: no remote nowhere -- push the project to GitHub first" ]
}

@test "cloud_require_pushed_branch: pushed and equal passes, the branch is named" {
    repo_with_upstream
    current=
    cloud_require_pushed_branch cloud origin
    [ "$current" = main ]
}

@test "cloud_require_pushed_branch: detached, no upstream, behind each refuse" {
    repo_with_upstream
    git checkout -q -b local
    run cloud_require_pushed_branch cloud origin
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud: branch local is not pushed (no upstream) -- push it first: git push -u origin local"* ]]
    git checkout -q main
    git commit -q --allow-empty -m two
    run cloud_require_pushed_branch cloud origin
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud: branch main is not up to date with origin/main"* ]]
    git checkout -q --detach
    run cloud_require_pushed_branch cloud origin
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud: HEAD is detached"* ]]
}

@test "cloud_resolve_model: --model wins, else config.sh says it" {
    model=opus
    cloud_resolve_model "$REPO/scripts"
    [ "$model" = opus ]
    model=
    cd "$BATS_TEST_TMPDIR" || return 1
    cloud_resolve_model "$REPO/scripts"
    [ "$model" = sonnet ]
}

@test "cloud_confirm: y starts, anything else says not started" {
    run cloud_confirm review 'Start? ' <<<"y"
    [ "$status" -eq 0 ]
    run cloud_confirm review 'Start? ' <<<""
    [ "$status" -eq 1 ]
    [[ "$output" == *"Start? "* ]]
    [[ "$output" == *"review: not started"* ]]
}

@test "cloud_launch hands claude the prompt and model through script" {
    cloud_launch 'do it & more' opus
    [ "$(cat "$STATE/claude.prompt")" = 'do it & more' ]
    [ "$(cat "$STATE/claude.model")" = opus ]
}

@test "cloud_launch passes claude's failure on" {
    printf '%s\n' '#!/usr/bin/env bash' 'exit 3' >"$STUBS/claude"
    run cloud_launch p m
    [ "$status" -ne 0 ]
}

@test "the heading constants are the ones the review and fixup prompts tell the session to use" {
    # shellcheck source=/dev/null
    source "$LIB"
    grep -qF "\"$CLOUD_REVIEW_HEADING @ROLE@\"" "$REPO/scripts/cloud-review-prompt.txt"
    grep -qF "\"$CLOUD_FIXUP_HEADING\"" "$REPO/scripts/cloud-fixup-prompt.txt"
    grep -qF "\`$CLOUD_FINDINGS_HEADING N\`" "$REPO/scripts/cloud-review-prompt.txt"
}

@test "cloud_roles lists the role files of a directory, by name, and skips what is not a file" {
    # shellcheck source=/dev/null
    source "$LIB"
    mkdir -p "$BATS_TEST_TMPDIR/review/dir.md"
    : >"$BATS_TEST_TMPDIR/review/beta.md"
    : >"$BATS_TEST_TMPDIR/review/alpha.md"
    : >"$BATS_TEST_TMPDIR/review/notes.txt"
    run cloud_roles "$BATS_TEST_TMPDIR/review"
    [ "$status" -eq 0 ]
    [ "$output" = "alpha
beta" ]
}

@test "cloud_role_count counts the roles, or refuses naming the caller when there are none" {
    # shellcheck source=/dev/null
    source "$LIB"
    mkdir -p "$BATS_TEST_TMPDIR/s/review"
    run cloud_role_count held "$BATS_TEST_TMPDIR/s"
    [ "$status" -eq 1 ]
    [[ "$output" == "held: no review roles in $BATS_TEST_TMPDIR/s/review"* ]]
    : >"$BATS_TEST_TMPDIR/s/review/a.md"
    : >"$BATS_TEST_TMPDIR/s/review/b.md"
    run cloud_role_count held "$BATS_TEST_TMPDIR/s"
    [ "$status" -eq 0 ]
    [ "$output" = 2 ]
}

@test "cloud_roles prints nothing for a directory without role files" {
    # shellcheck source=/dev/null
    source "$LIB"
    mkdir -p "$BATS_TEST_TMPDIR/empty"
    run cloud_roles "$BATS_TEST_TMPDIR/empty"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "cloud_parse_task splits Tn and node:Tn into want_node and id" {
    # shellcheck source=/dev/null
    source "$LIB"
    want_node=x id=x
    cloud_parse_task scripts:T98
    [ "$want_node" = scripts ] && [ "$id" = T98 ]
    cloud_parse_task T7
    [ -z "$want_node" ] && [ "$id" = T7 ]
    cloud_parse_task root:T5
    [ "$want_node" = root ] && [ "$id" = T5 ]
}

@test "cloud_parse_task refuses anything else" {
    # shellcheck source=/dev/null
    source "$LIB"
    for bad in "" 47 docs:47 T1x a/b:T1 :T1 "T1 T2"; do
        run cloud_parse_task "$bad"
        [ "$status" -eq 1 ]
    done
}

@test "cloud_branch_name is claude/<node>-<task>, the root node as root" {
    # shellcheck source=/dev/null
    source "$LIB"
    [ "$(cloud_branch_name scripts T98)" = claude/scripts-T98 ]
    [ "$(cloud_branch_name . T5)" = claude/root-T5 ]
}

@test "cloud_branch_regex matches the branch name, lower case, with the harness suffix, and no other task" {
    # shellcheck source=/dev/null
    source "$LIB"
    re="$(cloud_branch_regex scripts T98)"
    [[ claude/scripts-t98 =~ $re ]]
    [[ claude/scripts-t98-dk9i03 =~ $re ]]
    [[ ! claude/scripts-t980 =~ $re ]]
    [[ ! claude/docs-t98 =~ $re ]]
    re="$(cloud_branch_regex root T5)"
    [[ claude/root-t5-x1 =~ $re ]]
}

@test "cloud_branch_regex without a node takes any node" {
    # shellcheck source=/dev/null
    source "$LIB"
    re="$(cloud_branch_regex "" T98)"
    [[ claude/docs-t98-x =~ $re ]]
    [[ ! claude/docs-t99 =~ $re ]]
}

@test "cloud_branch_regex takes a dot in the node literally" {
    # shellcheck source=/dev/null
    source "$LIB"
    re="$(cloud_branch_regex a.b T1)"
    [[ claude/a.b-t1 =~ $re ]]
    [[ ! claude/axb-t1 =~ $re ]]
}

@test "cloud_parse_pr takes PR# or a PR URL into pr and url_repo" {
    # shellcheck source=/dev/null
    source "$LIB"
    pr=x url_repo=x
    cloud_parse_pr 17
    [ "$pr" = 17 ] && [ -z "$url_repo" ]
    cloud_parse_pr https://github.com/o/p/pull/23/
    [ "$pr" = 23 ] && [ "$url_repo" = o/p ]
}

@test "cloud_parse_pr refuses anything else" {
    # shellcheck source=/dev/null
    source "$LIB"
    for bad in "" T1 docs:T1 17x http://github.com/o/p/pull/1 https://github.com/o/p/issues/1 https://github.com/o/p/pull/1/files; do
        run cloud_parse_pr "$bad"
        [ "$status" -eq 1 ]
    done
}

@test "cloud_spec_branch_name is claude/spec-optimize, then each node after a -, the root as root (cloud:T148)" {
    # shellcheck source=/dev/null
    source "$LIB"
    [ "$(cloud_spec_branch_name)" = claude/spec-optimize ]
    [ "$(cloud_spec_branch_name scripts)" = claude/spec-optimize-scripts ]
    [ "$(cloud_spec_branch_name . scripts nix)" = claude/spec-optimize-root-scripts-nix ]
}

@test "cloud_nodes lists the root, then every dir of the root's §F table" {
    # shellcheck source=/dev/null
    source "$LIB"
    printf '%s\n' '# SPEC' '' '## §F FEDERATION' '' 'dir|owns|⊥owns|tokens' \
        'scripts|shell tools|-|-' 'docs|human docs|-|-' '' '## §T TASKS' \
        'id|status|task|cites' 'T1|.|not a node|C1' >"$BATS_TEST_TMPDIR/SPEC.md"
    run cloud_nodes "$BATS_TEST_TMPDIR/SPEC.md"
    [ "$status" -eq 0 ]
    [ "$output" = ".
scripts
docs" ]
}

@test "cloud_spec_of: the root's spec is SPEC.md, a node's is <node>/SPEC.md" {
    [ "$(cloud_spec_of .)" = SPEC.md ]
    [ "$(cloud_spec_of scripts)" = scripts/SPEC.md ]
}

@test "cloud_require_node: a listed node passes; another is refused naming it and the nodes (scripts:V26)" {
    cloud_require_node cloud docs . scripts docs
    run cloud_require_node spec-optimize nope . scripts docs
    [ "$status" -eq 1 ]
    [ "$output" = "spec-optimize: no node nope in SPEC.md §F (nodes: . scripts docs)" ]
}

@test "cloud_in_list: true when the first argument is one of the rest; false for none, even with no items" {
    cloud_in_list b a b c
    run cloud_in_list d a b c
    [ "$status" -eq 1 ]
    run cloud_in_list a
    [ "$status" -eq 1 ]
}

@test "cloud_node_label: the root, ., is spelled root; another node as is" {
    [ "$(cloud_node_label .)" = root ]
    [ "$(cloud_node_label scripts)" = scripts ]
}

@test "cloud_diff_reasons: names a kept file, a §C or §V row and a raised ceiling; a quiet diff prints nothing (cloud:V51)" {
    run cloud_diff_reasons <<<$'diff --git a/hk.pkl b/hk.pkl\n--- a/hk.pkl\n+++ b/hk.pkl\n@@ -1 +1 @@\n-a\n+b'
    [ "$status" -eq 0 ]
    [ "$output" = "diff: changes hk.pkl" ]
    run cloud_diff_reasons <<<$'diff --git a/SPEC.md b/SPEC.md\n+V9: new'
    [ "$output" = "diff: changes a §C or §V row of SPEC.md" ]
    run cloud_diff_reasons <<<$'diff --git a/.context-limits b/.context-limits\n-a.md 10\n+a.md 20'
    [ "$output" = "diff: raises the .context-limits row a.md from 10 to 20" ]
    run cloud_diff_reasons <<<$'diff --git a/README.md b/README.md\n-a\n+b'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "CLOUD_CI_OK: success, skipped and neutral are green; red, cancelled and pending are not (cloud:B68)" {
    for state in SUCCESS SKIPPED NEUTRAL; do [[ "$state" =~ $CLOUD_CI_OK ]]; done
    for state in FAILURE CANCELLED PENDING ""; do
        if [[ "$state" =~ $CLOUD_CI_OK ]]; then return 1; fi
    done
}

@test "cloud_session_count: 1 build + 1 per role + 1 fixup for a task, no build for a pull request" {
    # shellcheck source=/dev/null
    source "$LIB"
    [ "$(cloud_session_count 4)" -eq 6 ]
    [ "$(cloud_session_count 4 pr)" -eq 5 ]
    [ "$(cloud_session_count 1)" -eq 3 ]
}

@test "cloud_report prints one '<cmd>: report: <subject> <status>' row (cloud:I.file)" {
    run cloud_report enroll owner/alpha enrolled
    [ "$output" = "enroll: report: owner/alpha enrolled" ]
    run cloud_report held owner/alpha#7 ok https://github.com/owner/alpha/pull/7
    [ "$output" = "held: report: owner/alpha#7 ok https://github.com/owner/alpha/pull/7" ]
}

@test "cloud_repo_checkout is \$CLAUDINIX_PROJECTS/<repo>, owner dropped (cloud:I.file)" {
    CLAUDINIX_PROJECTS=/work run cloud_repo_checkout owner/alpha
    [ "$output" = /work/alpha ]
    CLAUDINIX_PROJECTS=/work run cloud_repo_checkout alpha
    [ "$output" = /work/alpha ]
}

@test "cloud_pin_env reads the environment id of a settings file, empty when none (cloud:I.file)" {
    echo '{"remote":{"defaultEnvironmentId":"env_a"}}' >"$BATS_TEST_TMPDIR/s.json"
    run cloud_pin_env "$BATS_TEST_TMPDIR/s.json"
    [ "$output" = env_a ]
    run cloud_pin_env "$BATS_TEST_TMPDIR/missing.json"
    [ -z "$output" ]
}

@test "cloud_pin_set merges the id into settings JSON and keeps the other keys (cloud:I.file)" {
    run cloud_pin_set env_b <<<'{"keep":1,"remote":{"x":2}}'
    [ "$(jq -c . <<<"$output")" = '{"keep":1,"remote":{"x":2,"defaultEnvironmentId":"env_b"}}' ]
}

@test "CLOUD_PIN_FILE is the per-checkout pin path (cloud:I.file)" {
    [ "$CLOUD_PIN_FILE" = .claude/settings.local.json ]
}

@test "cloud_origin_is matches github.com https and ssh origins, case folded (cloud:V59)" {
    git init -q "$BATS_TEST_TMPDIR/c"
    git -C "$BATS_TEST_TMPDIR/c" remote add origin https://github.com/Owner/Alpha.git
    cloud_origin_is owner/alpha "$BATS_TEST_TMPDIR/c"
    git -C "$BATS_TEST_TMPDIR/c" remote set-url origin git@github.com:owner/alpha.git
    cloud_origin_is Owner/alpha "$BATS_TEST_TMPDIR/c"
    run ! cloud_origin_is owner/zeta "$BATS_TEST_TMPDIR/c"
}

# gh_prs ROWS_JSON: a gh stub that answers the owner, those search rows, and
# "false" to the fork question.
gh_prs() {
    printf '%s\n' '#!/usr/bin/env bash' \
        'case "$*" in' \
        'api\ user*) echo owner ;;' \
        "search\\ prs*) echo '$1' ;;" \
        'pr\ view*) echo false ;;' \
        'esac' >"$STUBS/gh"
    chmod +x "$STUBS/gh"
}

@test "cloud_repos_with_label lists each repo once for the owner's own PRs (cloud:V52, cloud:V59)" {
    gh_prs '[{"number":1,"url":"u/1","repository":{"nameWithOwner":"owner/b"},"author":{"login":"owner"}},{"number":2,"url":"u/2","repository":{"nameWithOwner":"owner/b"},"author":{"login":"owner"}},{"number":3,"url":"u/3","repository":{"nameWithOwner":"owner/c"},"author":{"login":"other"}}]'
    run --separate-stderr cloud_repos_with_label enroll h10n-human
    [ "$output" = owner/b ]
    [[ "$stderr" == *"enroll: skip owner/c#3: its author is other, not owner"* ]]
}

@test "cloud_repos_with_label warns when the search cap is reached (cloud:B88)" {
    gh_prs "$(jq -nc '[range(100) | {number: ., url: "u/\(.)", repository: {nameWithOwner: "owner/b"}, author: {login: "owner"}}]')"
    run --separate-stderr cloud_repos_with_label enroll h10n-human
    [[ "$stderr" == *"enroll: only the first 100 labelled pull requests were found"* ]]
}

@test "cloud_valid_repo accepts owner/repo and refuses a leading -, dots and extra parts (cloud:V59, cloud:B106)" {
    cloud_valid_repo owner/repo.name-1
    cloud_valid_repo owner/.github
    run ! cloud_valid_repo -x/y
    run ! cloud_valid_repo owner/-y
    run ! cloud_valid_repo owner/..
    run ! cloud_valid_repo owner/repo/extra
    run ! cloud_valid_repo repo
}

# --- another repository's pull request, run from its checkout (cloud:T175) ---

# lib_cross_fixture: cross_fixture, with the real git behind `git`.
lib_cross_fixture() {
    cross_fixture
    cp "$STUBS/git-real" "$STUBS/git"
    pr=7 url_repo=owner/alpha
}

@test "cloud_require_url_repo enters the URL repo's checkout when its origin is that repo, case folded (cloud:T175)" {
    lib_cross_fixture
    cloud_require_url_repo review origin https://github.com/owner/alpha/pull/7
    [ "$PWD" = "$PROJECTS/alpha" ]
    [ "$entered_checkout" = "$PROJECTS/alpha" ]
}

@test "cloud_require_url_repo refuses as before without a usable checkout (cloud:B21, B25, B63, T175)" {
    lib_cross_fixture
    unset CLAUDINIX_PROJECTS
    run cloud_require_url_repo review origin u
    [ "$status" -eq 1 ]
    [[ "$output" == *"run it from a checkout of owner/alpha"* ]]
    export CLAUDINIX_PROJECTS="$PROJECTS"
    url_repo=owner/missing
    run cloud_require_url_repo review origin u
    [ "$status" -eq 1 ]
    [[ "$output" == *"run it from a checkout of owner/missing"* ]]
    url_repo=owner/..
    run cloud_require_url_repo review origin u
    [ "$status" -eq 1 ]
    [[ "$output" == *"run it from a checkout of owner/.."* ]]
}

@test "cloud_require_url_repo refuses a checkout whose origin is another repo, staying where it is (cloud:T175)" {
    lib_cross_fixture
    git -C "$PROJECTS/alpha" remote set-url origin https://github.com/owner/zeta
    run cloud_require_url_repo review origin u
    [ "$status" -eq 1 ]
    [[ "$output" == *"origin"* ]] && [[ "$output" == *"owner/alpha"* ]]
    [ -z "$entered_checkout" ]
}

@test "cloud_require_url_repo leaves a URL of this repo alone (cloud:T175)" {
    lib_cross_fixture
    url_repo=me/here
    cloud_require_url_repo review origin u
    [ "$PWD" = "$HERE" ]
    [ -z "$entered_checkout" ]
}

@test "cloud_require_checkout_ready passes a clean checkout on the base at the fetched tip (cloud:T175)" {
    lib_cross_fixture
    cloud_require_url_repo review origin u
    # shellcheck disable=SC2034 # read by cloud_require_checkout_ready
    base=main
    cloud_require_checkout_ready review
}

@test "cloud_require_checkout_ready refuses a dirty tree, another branch or a stale tip (cloud:T175)" {
    lib_cross_fixture
    cloud_require_url_repo review origin u
    # shellcheck disable=SC2034 # read by cloud_require_checkout_ready
    base=main
    touch "$PROJECTS/alpha/stray"
    run cloud_require_checkout_ready review
    [ "$status" -eq 1 ]
    [[ "$output" == *"not clean"* ]]
    rm "$PROJECTS/alpha/stray"
    git -C "$PROJECTS/alpha" checkout -q -b topic
    run cloud_require_checkout_ready review
    [ "$status" -eq 1 ]
    [[ "$output" == *"not on main"* ]]
    git -C "$PROJECTS/alpha" checkout -q main
    git -C "$PROJECTS/alpha" commit -q --allow-empty -m local
    run cloud_require_checkout_ready review
    [ "$status" -eq 1 ]
    [[ "$output" == *"not at the fetched"* ]]
}

@test "cloud_require_checkout_ready does nothing when no checkout was entered (cloud:T175)" {
    lib_cross_fixture
    # shellcheck disable=SC2034 # read by cloud_require_checkout_ready
    base=main
    cloud_require_checkout_ready review
}
