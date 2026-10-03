#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/domains.sh (SPEC scripts:T27, I.cmd `domains`,
# C6): base allowlist + detected hosts + log refusals, deduped. The
# clipboard is a stub: a test never touches the real one.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../scripts/domains.sh"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    P="$BATS_TEST_TMPDIR/sherd"
    export CLIP="$BATS_TEST_TMPDIR/clip"
    export CLAUDINIX_ALLOWLIST="$BATS_TEST_TMPDIR/allowlist.txt"
    export CLIPBOARD_TOOLS="$STUBS/pbcopy"
    mkdir -p "$STUBS" "$P"
    printf '%s\n' '# base' 'pr0d1r2.cachix.org' '' 'cache.nixos.org' 'github.com' >"$CLAUDINIX_ALLOWLIST"
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' 'echo "$0 $*" >"$CLIP.args"' 'cat >"$CLIP"' >"$STUBS/pbcopy"
    cp "$STUBS/pbcopy" "$STUBS/xclip"
    chmod +x "$STUBS"/*

    # A sherd-like project: Rust with a git dependency, a flake with its
    # own cache and one git+https input.
    printf '%s\n' 'source = "registry+https://github.com/rust-lang/crates.io-index"' \
        'source = "git+https://git.example.org/o/b?rev=1#1"' >"$P/Cargo.lock"
    printf '%s\n' '{' '  nixConfig.extra-substituters = [ "https://pr0d1r2.cachix.org" ];' '}' >"$P/flake.nix"
    printf '%s' '{"nodes":{"x":{"locked":{"type":"git","url":"https://github.com/o/x"}},' \
        '"root":{"inputs":{}}},"root":"root","version":7}' >"$P/flake.lock"
}

@test "base first in file order, then detected hosts sorted, each once" {
    cd "$P"
    run --separate-stderr bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "pr0d1r2.cachix.org" ]
    [ "${lines[1]}" = "cache.nixos.org" ]
    [ "${lines[2]}" = "github.com" ]
    [ "${lines[3]}" = "git.example.org" ]
    [ "${lines[4]}" = "index.crates.io" ]
    [ "${lines[5]}" = "static.crates.io" ]
    [ "${#lines[@]}" -eq 6 ]
}

@test "--why tags each host with its source" {
    cd "$P"
    run bash "$SCRIPT" --why
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "pr0d1r2.cachix.org	base" ]
    [ "${lines[4]}" = "index.crates.io	Cargo.lock" ]
}

@test "several projects: union, deduped, tags name the project" {
    Q="$BATS_TEST_TMPDIR/web"
    mkdir -p "$Q"
    printf '%s\n' '  "resolved": "https://registry.npmjs.org/a/-/a-1.tgz",' >"$Q/package-lock.json"
    printf '%s\n' 'x v1 h1:abc=' >"$Q/go.sum"
    cp "$P/Cargo.lock" "$Q/Cargo.lock"
    run bash "$SCRIPT" --why "$P" "$Q"
    [ "$status" -eq 0 ]
    [ "$(grep -c '^index.crates.io' <<<"$output")" -eq 1 ]
    [[ "$output" == *"index.crates.io	$P/Cargo.lock"* ]]
    [[ "$output" == *"registry.npmjs.org	$Q/package-lock.json"* ]]
    [[ "$output" == *"proxy.golang.org	$Q/go.sum"* ]]
}

@test "--from-log adds the hosts the proxy refused" {
    log="$BATS_TEST_TMPDIR/session.log"
    printf '%s\n' 'Host not in allowlist: files.pythonhosted.org' 'Host not in allowlist: github.com' >"$log"
    run bash "$SCRIPT" --why --from-log "$log" "$P"
    [ "$status" -eq 0 ]
    [[ "$output" == *"files.pythonhosted.org	log"* ]]
    [ "$(grep -c '^github.com' <<<"$output")" -eq 1 ]
}

@test "plain output is copied to the clipboard as printed" {
    run --separate-stderr bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [ "$(cat "$CLIP")" = "$output" ]
}

@test "--why output still copies the paste-ready host list" {
    run bash "$SCRIPT" --why "$P"
    [ "$status" -eq 0 ]
    [ "$(head -n 1 "$CLIP")" = "pr0d1r2.cachix.org" ]
}

@test "xclip is asked for the clipboard selection" {
    CLIPBOARD_TOOLS="$STUBS/xclip" run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [[ "$(cat "$CLIP.args")" == *"-selection clipboard"* ]]
}

@test "no clipboard tool: output only, still passes" {
    CLIPBOARD_TOOLS=no-such-clipboard-tool run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "pr0d1r2.cachix.org" ]
    [ ! -e "$CLIP" ]
}

@test "default base is this repo's allowlist.txt" {
    unset CLAUDINIX_ALLOWLIST
    run bash "$SCRIPT" "$BATS_TEST_TMPDIR/stubs"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "pr0d1r2.cachix.org" ]
}

@test "a missing project dir fails and says nothing was checked" {
    run bash "$SCRIPT" "$BATS_TEST_TMPDIR/none"
    [ "$status" -eq 1 ]
    [[ "$output" == *"nothing was checked"* ]]
}

@test "--from-log without a file or an unknown flag is a usage error" {
    run bash "$SCRIPT" --from-log
    [ "$status" -eq 2 ]
    run bash "$SCRIPT" --nope
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
}

@test "the clipboard tool's own output never reaches ours (xclip, scripts:T80)" {
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' 'cat >"$CLIP"' 'echo CLIP-STDOUT' 'echo CLIP-STDERR >&2' >"$STUBS/xclip"
    CLIPBOARD_TOOLS="$STUBS/xclip" run bash "$SCRIPT" "$P"
    [ "$status" -eq 0 ]
    [[ "$output" != *"CLIP-STDOUT"* ]]
    [[ "$output" != *"CLIP-STDERR"* ]]
    [[ "$output" == *"copied"* ]]
}

@test "an unreadable log fails" {
    run bash "$SCRIPT" --from-log "$BATS_TEST_TMPDIR/none.log" "$P"
    [ "$status" -eq 1 ]
}
