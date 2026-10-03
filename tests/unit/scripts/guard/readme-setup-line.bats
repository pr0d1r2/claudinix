#!/usr/bin/env bats
# Unit tests for scripts/guard/readme-setup-line.sh (SPEC T75, C25, V20, V21).

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/guard/readme-setup-line.sh"
    SHA=0123456789abcdef0123456789abcdef01234567
    OTHER=89abcdef0123456789abcdef0123456789abcdef
    export README_FILE="$BATS_TEST_TMPDIR/README.md"
    printf '# t\n\nIntro.\n\n<!-- BEGIN setup-line -->\n<!-- END setup-line -->\n\n## Rest\n\nTail.\n' >"$README_FILE"
    BIN="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$BIN"
    GH_LOG="$BATS_TEST_TMPDIR/gh.log"
    # shellcheck disable=SC2016 # $* expands inside the stub
    printf '#!/usr/bin/env bash\necho "$*" >>"%s"\necho "[]"\n' "$GH_LOG" >"$BIN/gh"
    chmod +x "$BIN/gh"
    cd "$BATS_TEST_TMPDIR" || exit 1
}

@test "--write fills the block with setup-line.sh's line and names the SHA" {
    run bash "$SCRIPT" --write "$SHA"
    [ "$status" -eq 0 ]
    grep -qF "https://raw.githubusercontent.com/pr0d1r2/claudinix/$SHA/setup.sh" "$README_FILE"
    grep -qF '```sh' "$README_FILE"
    grep -qF "\`$SHA\`" "$README_FILE"
}

@test "--write keeps every line outside the markers" {
    run bash "$SCRIPT" --write "$SHA"
    [ "$status" -eq 0 ]
    [ "$(sed -n '1,4p' "$README_FILE")" = "$(printf '# t\n\nIntro.\n')" ]
    [ "$(tail -n 4 "$README_FILE")" = "$(printf '\n## Rest\n\nTail.')" ]
    [ "$(grep -c 'BEGIN setup-line' "$README_FILE")" -eq 1 ]
    [ "$(grep -c 'END setup-line' "$README_FILE")" -eq 1 ]
}

@test "a block written for its SHA passes the check" {
    bash "$SCRIPT" --write "$SHA"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a rewrite for another SHA replaces the block, not appends" {
    bash "$SCRIPT" --write "$SHA"
    bash "$SCRIPT" --write "$OTHER"
    [ "$(grep -c 'raw.githubusercontent' "$README_FILE")" -eq 1 ]
    grep -qF "$OTHER" "$README_FILE"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "a hand-edited line fails and names the regenerate command" {
    bash "$SCRIPT" --write "$SHA"
    sed -i.bak 's/bash "\$d\/setup.sh"/sh "$d\/setup.sh"/' "$README_FILE"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"scripts/guard/readme-setup-line.sh --write $SHA"* ]]
}

@test "the check never asks GitHub (offline, no gh call)" {
    bash "$SCRIPT" --write "$SHA"
    run env PATH="$BIN:$PATH" bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ ! -e "$GH_LOG" ]
}

@test "missing markers fail the check" {
    printf '# t\n' >"$README_FILE"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"<!-- BEGIN setup-line -->"* ]]
}

@test "an empty block (no SHA) fails the check" {
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"no release SHA"* ]]
}

@test "before the first release the block may hold only the placeholder" {
    # shellcheck disable=SC2016 # literal Markdown backticks
    printf '# t\n\n<!-- BEGIN setup-line -->\n%s\n<!-- END setup-line -->\n' \
        'No release yet: the maintainer publishes the line with `scripts/release.sh record`, then `scripts/release.sh publish`.' >"$README_FILE"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "the placeholder plus anything else is not the placeholder" {
    # shellcheck disable=SC2016 # literal Markdown and shell text
    printf '# t\n\n<!-- BEGIN setup-line -->\n%s\nd=$(mktemp -d)\n<!-- END setup-line -->\n' \
        'No release yet: the maintainer publishes the line with `scripts/release.sh record`, then `scripts/release.sh publish`.' >"$README_FILE"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
}

@test "--write with missing markers fails and leaves the README alone" {
    printf '# t\n' >"$README_FILE"
    run bash "$SCRIPT" --write "$SHA"
    [ "$status" -eq 1 ]
    [ "$(cat "$README_FILE")" = "# t" ]
}

@test "--write needs a full 40-hex SHA" {
    run bash "$SCRIPT" --write HEAD
    [ "$status" -eq 2 ]
    run bash "$SCRIPT" --write
    [ "$status" -eq 2 ]
}
