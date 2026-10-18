#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/cloud-enroll.sh (SPEC cloud:T174, cloud:V52,
# cloud:V59, cloud:I.cmd). gh and git are stubs: nothing reaches GitHub.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../scripts/cloud-enroll.sh"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    export STATE="$BATS_TEST_TMPDIR/state"
    export CLAUDINIX_PROJECTS="$BATS_TEST_TMPDIR/projects"
    export CLAUDE_SETTINGS="$BATS_TEST_TMPDIR/user-settings.json"
    unset GH_FAIL GH_FAIL_PR_VIEW
    mkdir -p "$STUBS" "$STATE" "$CLAUDINIX_PROJECTS"
    jq -n '{remote: {defaultEnvironmentId: "env_pick"}}' >"$CLAUDE_SETTINGS"

    # gh: `api user` answers the owner, `search prs` answers
    # $STATE/prs.json, `pr view` says whether $STATE/fork.<N> exists,
    # `repo clone R DIR` makes a git dir at DIR whose origin is R.
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$STATE/gh.log"' \
        '[ -z "${GH_FAIL:-}" ] || { echo "HTTP 502: bad gateway" >&2; exit 1; }' \
        '[ -z "${GH_FAIL_PR_VIEW:-}" ] || [[ "$*" != "pr view"* ]] || { echo "HTTP 502" >&2; exit 1; }' \
        'case "$*" in' \
        'api\ user*) echo owner ;;' \
        'search\ prs*) cat "$STATE/prs.json" ;;' \
        'pr\ view*) [ -f "$STATE/fork.${3##*/}" ] && echo true || echo false ;;' \
        'repo\ clone*) git init -q "$4" && git -C "$4" remote add origin "https://github.com/$3.git" ;;' \
        '*) exit 9 ;;' \
        'esac' >"$STUBS/gh"
    # git: logs a fetch and succeeds, so nothing reaches GitHub; the rest is the real git.
    REAL_GIT="$(command -v git)" run bash -c 'printf "%s\n" "#!/usr/bin/env bash" \
        "case \"\$*\" in *fetch*) echo \"\$*\" >>\"\$STATE/git.log\"; exit 0 ;; esac" \
        "exec $REAL_GIT \"\$@\"" >"$1"' _ "$STUBS/git"
    chmod +x "$STUBS"/*
    export PATH="$STUBS:$PATH"
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
}

# existing REPO [ORIGIN]: a checkout of REPO whose origin is ORIGIN.
existing() {
    git init -q "$CLAUDINIX_PROJECTS/$1"
    git -C "$CLAUDINIX_PROJECTS/$1" remote add origin "https://github.com/${2-owner/$1}.git"
}

# pr REPO N [AUTHOR]: one `gh search prs` row.
prs() {
    jq -s . <<<"$*" >"$STATE/prs.json"
}
pr() {
    jq -n --arg r "$1" --argjson n "$2" --arg a "${3-owner}" \
        '{number: $n, url: "https://github.com/owner/\($r)/pull/\($n)", repository: {name: $r, nameWithOwner: "owner/\($r)"}, author: {login: $a}}'
}

pinned() {
    jq -r '.remote.defaultEnvironmentId' "$CLAUDINIX_PROJECTS/$1/.claude/settings.local.json"
}

@test "a missing checkout is cloned and pinned to the /remote-env pick" {
    run bash "$SCRIPT" --repo owner/alpha --yes
    [ "$status" -eq 0 ]
    [ "$(pinned alpha)" = env_pick ]
    grep -q 'repo clone owner/alpha' "$STATE/gh.log"
    [[ "$output" == *"enroll: report: owner/alpha enrolled"* ]]
}

@test "the pin file goes to .git/info/exclude, once, and nothing is committed" {
    run bash "$SCRIPT" --repo owner/alpha --yes
    run bash "$SCRIPT" --repo owner/alpha --yes
    [ "$status" -eq 0 ]
    [ "$(grep -c 'settings.local.json' "$CLAUDINIX_PROJECTS/alpha/.git/info/exclude")" -eq 1 ]
    run git -C "$CLAUDINIX_PROJECTS/alpha" log
    [ "$status" -ne 0 ]
}

@test "an existing checkout is fetched, not cloned, and other settings keys stay" {
    existing alpha
    mkdir -p "$CLAUDINIX_PROJECTS/alpha/.claude"
    echo '{"keep": 1}' >"$CLAUDINIX_PROJECTS/alpha/.claude/settings.local.json"
    run bash "$SCRIPT" --repo owner/alpha --yes
    [ "$status" -eq 0 ]
    run ! grep -q 'repo clone' "$STATE/gh.log"
    grep -q 'fetch' "$STATE/git.log"
    [ "$(jq -r .keep "$CLAUDINIX_PROJECTS/alpha/.claude/settings.local.json")" = 1 ]
    [ "$(pinned alpha)" = env_pick ]
}

@test "no /remote-env pick is needs-env, nothing pinned" {
    rm "$CLAUDE_SETTINGS"
    run bash "$SCRIPT" --repo owner/alpha --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"enroll: report: owner/alpha needs-env"* ]]
    [ ! -e "$CLAUDINIX_PROJECTS/alpha/.claude/settings.local.json" ]
}

@test "a checkout pinned to another environment is needs-env and left alone" {
    existing alpha
    mkdir -p "$CLAUDINIX_PROJECTS/alpha/.claude"
    echo '{"remote":{"defaultEnvironmentId":"env_other"}}' >"$CLAUDINIX_PROJECTS/alpha/.claude/settings.local.json"
    run bash "$SCRIPT" --repo owner/alpha --yes
    [[ "$output" == *"enroll: report: owner/alpha needs-env"* ]]
    [ "$(pinned alpha)" = env_other ]
}

@test "a checkout whose origin is another repo is failed and untouched" {
    existing alpha owner/zeta
    run bash "$SCRIPT" --repo owner/alpha --yes
    [[ "$output" == *"enroll: report: owner/alpha failed"* ]]
    [ ! -e "$CLAUDINIX_PROJECTS/alpha/.claude/settings.local.json" ]
}

@test "a repo name that is not owner/repo is refused before any gh call" {
    run bash "$SCRIPT" --repo 'owner/../x' --yes
    [ "$status" -ne 0 ]
    [ ! -e "$STATE/gh.log" ]
}

@test "without --repo, repos come from the owner's own open PRs under the label" {
    prs "$(pr alpha 7)" "$(pr beta 3 stranger)" "$(pr gamma 4)" "$(pr alpha 8)"
    touch "$STATE/fork.4"
    run bash "$SCRIPT" --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"enroll: report: owner/alpha enrolled"* ]]
    [ "$(grep -c 'report: owner/alpha' <<<"$output")" -eq 1 ]
    [[ "$output" != *"report: owner/beta"* ]]
    [[ "$output" != *"report: owner/gamma"* ]]
    [[ "$output" == *"beta"*"stranger"* ]]
}

@test "--dry-run names the repos and changes nothing" {
    run bash "$SCRIPT" --repo owner/alpha --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *owner/alpha* ]]
    [ ! -e "$CLAUDINIX_PROJECTS/alpha" ]
}

@test "without --yes, an answer other than y starts nothing" {
    run bash "$SCRIPT" --repo owner/alpha <<<n
    [ "$status" -eq 1 ]
    [ ! -e "$CLAUDINIX_PROJECTS/alpha" ]
}

@test "CLAUDINIX_PROJECTS unset is refused" {
    unset CLAUDINIX_PROJECTS
    run bash "$SCRIPT" --repo owner/alpha --yes
    [ "$status" -eq 1 ]
}

@test "a PR whose fork lookup fails is skipped, its repo not enrolled (cloud:B102)" {
    prs "$(pr alpha 7)"
    GH_FAIL_PR_VIEW=1 run bash "$SCRIPT" --yes
    [[ "$output" == *"enroll: skip owner/alpha#7"* ]]
    [ ! -e "$CLAUDINIX_PROJECTS/alpha" ]
}

@test "a .claude symlink in the checkout is failed, nothing written through it (cloud:B103)" {
    existing alpha
    mkdir "$BATS_TEST_TMPDIR/victim"
    ln -s "$BATS_TEST_TMPDIR/victim" "$CLAUDINIX_PROJECTS/alpha/.claude"
    run bash "$SCRIPT" --repo owner/alpha --yes
    [[ "$output" == *"enroll: report: owner/alpha failed"* ]]
    [ ! -e "$BATS_TEST_TMPDIR/victim/settings.local.json" ]
}

@test "a pin file the repo tracks is failed and left untouched (cloud:B104)" {
    existing alpha
    mkdir -p "$CLAUDINIX_PROJECTS/alpha/.claude"
    echo '{"keep": 1}' >"$CLAUDINIX_PROJECTS/alpha/.claude/settings.local.json"
    git -C "$CLAUDINIX_PROJECTS/alpha" add -f .claude/settings.local.json
    run bash "$SCRIPT" --repo owner/alpha --yes
    [[ "$output" == *"enroll: report: owner/alpha failed"* ]]
    [ "$(jq -c . "$CLAUDINIX_PROJECTS/alpha/.claude/settings.local.json")" = '{"keep":1}' ]
}

@test "a failed write to info/exclude is failed, not enrolled (cloud:B105)" {
    existing alpha
    rm -f "$CLAUDINIX_PROJECTS/alpha/.git/info/exclude"
    mkdir "$CLAUDINIX_PROJECTS/alpha/.git/info/exclude"
    run bash "$SCRIPT" --repo owner/alpha --yes
    [[ "$output" == *"enroll: report: owner/alpha failed"* ]]
}

@test "a repo name starting with - is refused before any gh call (cloud:B106)" {
    run bash "$SCRIPT" --repo -x/y --yes
    [ "$status" -eq 2 ]
    [ ! -e "$STATE/gh.log" ]
}

@test "a repo found by search that is not owner/repo is skipped, not cloned (cloud:B106)" {
    prs "$(pr -x 7)" "$(pr alpha 8)"
    run bash "$SCRIPT" --yes
    [[ "$output" == *"enroll: skip owner/-x"* ]]
    run ! grep -q 'repo clone owner/-x' "$STATE/gh.log"
    [ -d "$CLAUDINIX_PROJECTS/alpha" ]
}

@test "without a /remote-env pick nothing is cloned or fetched" {
    rm "$CLAUDE_SETTINGS"
    existing alpha
    run bash "$SCRIPT" --repo owner/alpha --repo owner/beta --yes
    [[ "$output" == *"enroll: report: owner/beta needs-env"* ]]
    [ ! -e "$CLAUDINIX_PROJECTS/beta" ]
    [ ! -e "$STATE/git.log" ]
}

@test "two repos with one name are refused before any gh call (cloud:V59)" {
    run bash "$SCRIPT" --repo a/foo --repo B/FOO --yes
    [ "$status" -eq 2 ]
    [ ! -e "$STATE/gh.log" ]
}
