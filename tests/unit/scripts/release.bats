#!/usr/bin/env bats
# Unit tests for scripts/release.sh (SPEC T87, T75, C25, V33, B10,
# nix:V15, V20). git is real; setup-line.sh, verify-cachix.sh, nix and
# curl are stubs: no GitHub, no network, no store.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../scripts/release.sh"
    GUARD="$BATS_TEST_DIRNAME/../../../scripts/guard/readme-setup-line.sh"
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_PREFIX
    REPO="$BATS_TEST_TMPDIR/repo"
    git init -q "$REPO"
    cd "$REPO" || exit 1
    git config user.email t@example.invalid
    git config user.name t
    git config commit.gpgsign false
    printf '# t\n\n<!-- BEGIN setup-line -->\n<!-- END setup-line -->\n' >README.md
    echo '{ }' >flake.nix
    git add README.md flake.nix
    git commit -q -m "chore: root"
    SHA="$(git rev-parse HEAD)"
    BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$BIN"
    LOG="$BATS_TEST_TMPDIR/calls.log"
    export LOG
    export SETUP_LINE="$BIN/setup-line"
    export VERIFY_CACHIX="$BIN/verify-cachix"
    export CLOUD_HOME_STOREPATH="$REPO/cloud-home.storepath"
    export CACHIX_URL=https://cache.example.invalid
    unset RECORD_STOREPATH
    stub_setup_line 0
    stub_verify 0
    stub_nix
    stub_curl
    export PATH="$BIN:$PATH"
}

# stub_setup_line RC: logs its args; prints a line on 0, refuses otherwise.
stub_setup_line() {
    # shellcheck disable=SC2016 # expands inside the stub
    printf '#!/usr/bin/env bash\necho "setup-line $*" >>"$LOG"\nif [ %s = 0 ]; then echo "LINE-FOR-$1"; else echo "setup-line: CI on main for $1 is not green" >&2; exit %s; fi\n' "$1" "$1" >"$SETUP_LINE"
    chmod +x "$SETUP_LINE"
}

# stub_verify RC: logs its args; passes on 0, reports an uncached source otherwise.
stub_verify() {
    # shellcheck disable=SC2016 # expands inside the stub
    printf '#!/usr/bin/env bash\necho "verify-cachix $*" >>"$LOG"\nif [ %s = 0 ]; then exit 0; fi\necho "verify-cachix: source /nix/store/x-src is in neither cache (narinfo HTTP 404)" >&2\nexit %s\n' "$1" "$1" >"$VERIFY_CACHIX"
    chmod +x "$VERIFY_CACHIX"
}

# stub_nix: `nix eval --raw git+file://DIR?rev=SHA#...outPath` prints a
# store path derived from SHA's tree WITHOUT cloud-home.storepath, as the
# real flake's source filter does (V20): committing the recorded path
# leaves the agent home's path unchanged; any other change moves it.
stub_nix() {
    # shellcheck disable=SC2016 # expands inside the stub
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "nix $*" >>"$LOG"' \
        '[ "$1 $2" = "eval --raw" ] || exit 9' \
        'ref="$3"; dir="${ref#git+file://}"; dir="${dir%%\?*}"; rev="${ref#*rev=}"; rev="${rev%%#*}"' \
        'hash="$(git -C "$dir" ls-tree -r "$rev" | grep -v "	cloud-home.storepath$" | git hash-object --stdin)"' \
        'echo "/nix/store/${hash:0:32}-home-manager-generation"' >"$BIN/nix"
    chmod +x "$BIN/nix"
}

# stub_curl: every narinfo answers 200, as after a CI push.
stub_curl() {
    printf '#!/usr/bin/env bash\nprintf 200\n' >"$BIN/curl"
    chmod +x "$BIN/curl"
}

# home_of SHA: the agent home path the nix stub evaluates for SHA.
home_of() {
    "$BIN/nix" eval --raw "git+file://$(git rev-parse --show-toplevel)?rev=$1#homeConfigurations.cloud.activationPackage.outPath"
}

# commit_record: what the maintainer does between the phases.
commit_record() {
    git add cloud-home.storepath
    git commit -q -m "chore(release): record the agent home"
    git rev-parse HEAD
}

# ---- usage ----

@test "no subcommand is a usage error naming record and publish" {
    run bash "$SCRIPT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"record"* ]]
    [[ "$output" == *"publish"* ]]
}

@test "an unknown subcommand is a usage error" {
    run bash "$SCRIPT" "$SHA"
    [ "$status" -eq 2 ]
}

@test "record takes at most one REV" {
    run bash "$SCRIPT" record a b
    [ "$status" -eq 2 ]
}

@test "publish needs exactly one REV" {
    run bash "$SCRIPT" publish
    [ "$status" -eq 2 ]
    run bash "$SCRIPT" publish a b
    [ "$status" -eq 2 ]
}

@test "unresolvable REV fails before asking anything" {
    run bash "$SCRIPT" record no-such-rev
    [ "$status" -eq 1 ]
    [ ! -e "$LOG" ]
    run bash "$SCRIPT" publish no-such-rev
    [ "$status" -eq 1 ]
    [ ! -e "$LOG" ]
}

# ---- phase 1: record ----

@test "record: CI green and cached: writes the agent home of REV" {
    run bash "$SCRIPT" record "$SHA"
    [ "$status" -eq 0 ]
    [ "$(cat cloud-home.storepath)" = "$(home_of "$SHA")" ]
}

@test "record: default REV is HEAD" {
    run bash "$SCRIPT" record
    [ "$status" -eq 0 ]
    grep -qx "setup-line $SHA" "$LOG"
}

@test "record: asks setup-line.sh about CI for the full SHA, without --force" {
    run bash "$SCRIPT" record HEAD
    [ "$status" -eq 0 ]
    grep -qx "setup-line $SHA" "$LOG"
    [ "$(grep -c -- --force "$LOG")" = 0 ]
}

@test "record: checks input sources and the agent home of REV, not the worktree (V33)" {
    run bash "$SCRIPT" record "$SHA"
    [ "$status" -eq 0 ]
    top="$(git rev-parse --show-toplevel)"
    grep -qxF "verify-cachix --sources git+file://$top?rev=$SHA git+file://$top?rev=$SHA#homeConfigurations.cloud.activationPackage" "$LOG"
}

@test "record: CI not green: refuses, records nothing" {
    stub_setup_line 1
    run bash "$SCRIPT" record "$SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not green"* ]]
    [[ "$output" == *"nothing was recorded"* ]]
    [ ! -e cloud-home.storepath ]
    [ "$(grep -c '^verify-cachix' "$LOG")" = 0 ]
}

@test "record: an input source not cached: refuses, records nothing (V33, B10)" {
    stub_verify 1
    run bash "$SCRIPT" record "$SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"neither cache"* ]]
    [[ "$output" == *"nothing was recorded"* ]]
    [ ! -e cloud-home.storepath ]
}

@test "record: agent home narinfo not 200: refuses, records nothing" {
    printf '#!/usr/bin/env bash\nprintf 404\n' >"$BIN/curl"
    run bash "$SCRIPT" record "$SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"nothing was recorded"* ]]
    [ ! -e cloud-home.storepath ]
}

@test "record: never commits or pushes; prints the commit and push, then publish" {
    commits="$(git rev-list --count HEAD)"
    run bash "$SCRIPT" record "$SHA"
    [ "$status" -eq 0 ]
    [ "$(git rev-list --count HEAD)" = "$commits" ]
    [[ "$output" == *"git add cloud-home.storepath"* ]]
    [[ "$output" == *"chore(release): record the agent home of ${SHA:0:12}"* ]]
    [[ "$output" == *"Why: "* ]]
    [[ "$output" == *"Refs: "* ]]
    [[ "$output" == *"git push"* ]]
    [[ "$output" == *"CI"* ]]
    [[ "$output" == *"scripts/release.sh publish"* ]]
}

@test "record: REV that already holds its own path: publish it directly" {
    bash "$SCRIPT" record "$SHA"
    sha2="$(commit_record)"
    run bash "$SCRIPT" record "$sha2"
    [ "$status" -eq 0 ]
    [[ "$output" == *"already"* ]]
    [[ "$output" == *"scripts/release.sh publish $sha2"* ]]
    [[ "$output" != *"git commit"* ]]
}

# ---- phase 2: publish ----

@test "publish: a SHA without cloud-home.storepath is refused (B10, V33)" {
    before="$(cat README.md)"
    run bash "$SCRIPT" publish "$SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"cloud-home.storepath"* ]]
    [[ "$output" == *"release.sh record"* ]]
    [[ "$output" == *"nothing was published"* ]]
    [ "$(cat README.md)" = "$before" ]
}

@test "publish: a recorded path that is not the SHA's own agent home is refused (V33)" {
    echo /nix/store/00000000000000000000000000000000-stale >cloud-home.storepath
    sha2="$(commit_record)"
    before="$(cat README.md)"
    run bash "$SCRIPT" publish "$sha2"
    [ "$status" -eq 1 ]
    [[ "$output" == *"00000000000000000000000000000000-stale"* ]]
    [[ "$output" == *"$(home_of "$sha2")"* ]]
    [[ "$output" == *"nothing was published"* ]]
    [ "$(cat README.md)" = "$before" ]
}

@test "publish: a change after the record moves the agent home: refused" {
    bash "$SCRIPT" record "$SHA"
    git add cloud-home.storepath
    echo '{ x = 1; }' >flake.nix
    git commit -q -am "feat: change the home"
    run bash "$SCRIPT" publish HEAD
    [ "$status" -eq 1 ]
    [[ "$output" == *"nothing was published"* ]]
}

@test "record then commit keeps the agent home path: publish accepts the new SHA (V20)" {
    bash "$SCRIPT" record "$SHA"
    sha2="$(commit_record)"
    [ "$(home_of "$sha2")" = "$(home_of "$SHA")" ]
    run bash "$SCRIPT" publish "$sha2"
    [ "$status" -eq 0 ]
}

@test "publish: the README block and the notes name the published SHA, not REV" {
    bash "$SCRIPT" record "$SHA"
    sha2="$(commit_record)"
    run bash "$SCRIPT" publish "$sha2"
    [ "$status" -eq 0 ]
    [[ "$output" == *"https://raw.githubusercontent.com/pr0d1r2/claudinix/$sha2/setup.sh"* ]]
    [[ "$output" == *'```sh'* ]]
    grep -qF "raw.githubusercontent.com/pr0d1r2/claudinix/$sha2/setup.sh" README.md
    run ! grep -qF "$SHA" README.md
}

@test "publish: the README it writes passes the gate's block check" {
    bash "$SCRIPT" record "$SHA"
    sha2="$(commit_record)"
    run bash "$SCRIPT" publish "$sha2"
    [ "$status" -eq 0 ]
    run bash "$GUARD"
    [ "$status" -eq 0 ]
}

@test "publish: CI not green for the SHA: refused, README untouched" {
    bash "$SCRIPT" record "$SHA"
    sha2="$(commit_record)"
    stub_setup_line 1
    before="$(cat README.md)"
    run bash "$SCRIPT" publish "$sha2"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not green"* ]]
    [[ "$output" == *"nothing was published"* ]]
    [ "$(cat README.md)" = "$before" ]
    grep -qx "setup-line $sha2" "$LOG"
}

@test "publish: sources or agent home not cached for the SHA: refused (V33)" {
    bash "$SCRIPT" record "$SHA"
    sha2="$(commit_record)"
    stub_verify 1
    before="$(cat README.md)"
    run bash "$SCRIPT" publish "$sha2"
    [ "$status" -eq 1 ]
    [[ "$output" == *"nothing was published"* ]]
    [ "$(cat README.md)" = "$before" ]
    top="$(git rev-parse --show-toplevel)"
    grep -qxF "verify-cachix --sources git+file://$top?rev=$sha2 git+file://$top?rev=$sha2#homeConfigurations.cloud.activationPackage" "$LOG"
}

@test "publish: never commits, tags or pushes; prints the commands instead" {
    bash "$SCRIPT" record "$SHA"
    sha2="$(commit_record)"
    commits="$(git rev-list --count HEAD)"
    run bash "$SCRIPT" publish "$sha2"
    [ "$status" -eq 0 ]
    [ "$(git rev-list --count HEAD)" = "$commits" ]
    [ -z "$(git tag)" ]
    [[ "$output" == *"git add README.md"* ]]
    [[ "$output" == *"git commit"* ]]
    [[ "$output" == *"git push"* ]]
    [[ "$output" == *"git tag -a claudinix-${sha2:0:12} $sha2"* ]]
    [[ "$output" == *"gh release create claudinix-${sha2:0:12}"* ]]
}

@test "publish: notes go to stdout, commands to stderr, so notes can be saved" {
    bash "$SCRIPT" record "$SHA"
    sha2="$(commit_record)"
    bash "$SCRIPT" publish "$sha2" >"$BATS_TEST_TMPDIR/notes.md" 2>"$BATS_TEST_TMPDIR/err"
    grep -qF "$sha2/setup.sh" "$BATS_TEST_TMPDIR/notes.md"
    [ "$(grep -c 'git push' "$BATS_TEST_TMPDIR/notes.md")" = 0 ]
    grep -q 'git push' "$BATS_TEST_TMPDIR/err"
}

@test "just release passes the subcommand and REV through" {
    grep -qxF 'release *args:' "$BATS_TEST_DIRNAME/../../../justfile"
    grep -qxF '    scripts/release.sh {{ args }}' "$BATS_TEST_DIRNAME/../../../justfile"
}
