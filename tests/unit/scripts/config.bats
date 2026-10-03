#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/config.sh (SPEC scripts:T90, scripts:V34,
# scripts:V26, .:C28, I.file `.claudinix.toml`). The TOML is parsed by
# the real nix (`builtins.fromTOML`, no store, no network); a wrapper
# on PATH only counts the calls.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../scripts/config.sh"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    PROJECT="$BATS_TEST_TMPDIR/project"
    export NIX_LOG="$BATS_TEST_TMPDIR/nix.log"
    while read -r var; do unset "$var"; done < <(env | sed -n 's/^\(GIT_[A-Z_]*\)=.*/\1/p')
    unset CLAUDINIX_CONFIG CLAUDINIX_SCRIPTS
    export GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR"
    mkdir -p "$STUBS" "$PROJECT"
    REAL_NIX="$(command -v nix)"
    export REAL_NIX
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'echo "$*" >>"$NIX_LOG"' \
        'exec "$REAL_NIX" "$@"' >"$STUBS/nix"
    chmod +x "$STUBS/nix"
    export PATH="$STUBS:$PATH"
    : >"$NIX_LOG"
    cd "$PROJECT" || return 1
}

# toml LINE...: the project's .claudinix.toml.
toml() {
    printf '%s\n' "$@" >"$PROJECT/.claudinix.toml"
}

# refused KEY LINE...: the file with LINE... is refused with exit 2, and
# the message names KEY and the file (V34, V26).
refused() {
    local key="$1"
    shift
    toml "$@"
    run --separate-stderr bash "$SCRIPT" --dir "$PROJECT" check
    [ "$status" -eq 2 ]
    [ -z "$output" ]
    [[ "$stderr" == *"$key"* ]]
    [[ "$stderr" == *"$PROJECT/.claudinix.toml"* ]]
}

DEFAULTS='{"cache":{"name":"pr0d1r2","push_sources":false},"devshell":{"installable":"."},"network":{"extra_domains":[]},"probe":{"branch_prefix":"claude/nix-probe"},"session":{"agent_home":false,"model":"sonnet"},"version":1}'

@test "no file: json prints today's defaults and nix is never called" {
    run --separate-stderr bash "$SCRIPT" json
    [ "$status" -eq 0 ]
    [ "$(jq -cS . <<<"$output")" = "$DEFAULTS" ]
    [ ! -s "$NIX_LOG" ]
}

@test "no file: check is silent and passes" {
    run bash "$SCRIPT" --dir "$PROJECT" check
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "no file: get prints the default, an empty list prints nothing" {
    run --separate-stderr bash "$SCRIPT" get session.model
    [ "$status" -eq 0 ]
    [ "$output" = sonnet ]
    run --separate-stderr bash "$SCRIPT" get network.extra_domains
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run --separate-stderr bash "$SCRIPT" get session.agent_home
    [ "$output" = false ]
}

@test "valid file: every key read, one nix eval per call" {
    toml 'version = 1' \
        '[session]' 'model = "opus"' 'agent_home = true' \
        '[devshell]' 'installable = ".#ci"' \
        '[network]' 'extra_domains = ["a.example.org", "b.example.org"]' \
        '[cache]' 'name = "forker"' 'push_sources = true' \
        '[probe]' 'branch_prefix = "claude/probe"'
    run --separate-stderr bash "$SCRIPT" json
    [ "$status" -eq 0 ]
    [ "$(jq -r .session.model <<<"$output")" = opus ]
    [ "$(jq -r .session.agent_home <<<"$output")" = true ]
    [ "$(jq -r .devshell.installable <<<"$output")" = ".#ci" ]
    [ "$(jq -c .network.extra_domains <<<"$output")" = '["a.example.org","b.example.org"]' ]
    [ "$(jq -r .cache.name <<<"$output")" = forker ]
    [ "$(jq -r .cache.push_sources <<<"$output")" = true ]
    [ "$(jq -r .probe.branch_prefix <<<"$output")" = claude/probe ]
    [ "$(grep -c '^eval ' "$NIX_LOG")" -eq 1 ]
    run --separate-stderr bash "$SCRIPT" check
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "partial file: the keys it leaves out keep their defaults" {
    toml 'version = 1' '[cache]' 'name = "forker"'
    run --separate-stderr bash "$SCRIPT" json
    [ "$status" -eq 0 ]
    [ "$(jq -r .cache.name <<<"$output")" = forker ]
    [ "$(jq -r .cache.push_sources <<<"$output")" = false ]
    [ "$(jq -r .session.model <<<"$output")" = sonnet ]
    [ "$(jq -r .probe.branch_prefix <<<"$output")" = claude/nix-probe ]
}

@test "get of a list: one item per line" {
    toml 'version = 1' '[network]' 'extra_domains = ["a.example.org", "b.example.org"]'
    run --separate-stderr bash "$SCRIPT" get network.extra_domains
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [ "${lines[0]}" = a.example.org ]
    [ "${lines[1]}" = b.example.org ]
}

@test "get of an unknown key: exit 2, names the key" {
    run --separate-stderr bash "$SCRIPT" get session.colour
    [ "$status" -eq 2 ]
    [[ "$stderr" == *"session.colour"* ]]
    run --separate-stderr bash "$SCRIPT" get model
    [ "$status" -eq 2 ]
    [[ "$stderr" == *"model"* ]]
}

@test "wrong type: session.model not sonnet or opus" {
    refused session.model 'version = 1' '[session]' 'model = "haiku"'
    [[ "$stderr" == *'"haiku"'* ]]
}

@test "wrong type: session.agent_home not a bool" {
    refused session.agent_home 'version = 1' '[session]' 'agent_home = "yes"'
}

@test "wrong type: devshell.installable not a string" {
    refused devshell.installable 'version = 1' '[devshell]' 'installable = 1'
}

@test "wrong type: network.extra_domains a string, or a list of non-strings" {
    refused network.extra_domains 'version = 1' '[network]' 'extra_domains = "a.example.org"'
    refused network.extra_domains 'version = 1' '[network]' 'extra_domains = ["a.example.org", 1]'
}

@test "wrong type: cache.name not a string" {
    refused cache.name 'version = 1' '[cache]' 'name = true'
}

@test "wrong type: cache.push_sources not a bool" {
    refused cache.push_sources 'version = 1' '[cache]' 'push_sources = 1'
}

@test "wrong type: probe.branch_prefix not a string" {
    refused probe.branch_prefix 'version = 1' '[probe]' 'branch_prefix = ["claude/x"]'
}

@test "a known table that is not a table is refused" {
    refused session 'version = 1' 'session = "opus"'
}

@test "unknown table: refused, named" {
    refused '[colour]' 'version = 1' '[colour]' 'name = "red"'
}

@test "unknown key in a known table: refused, named with its table" {
    refused session.colour 'version = 1' '[session]' 'colour = "red"'
}

@test "unknown top-level key: refused, named" {
    refused colour 'version = 1' 'colour = "red"'
}

@test "version missing, not 1, or not a number: refused" {
    refused version '[session]' 'model = "opus"'
    refused version 'version = 2'
    refused version 'version = "1"'
}

@test "every problem in the file is reported at once" {
    refused session.model 'version = 1' '[session]' 'model = "haiku"' '[cache]' 'name = 1'
    [[ "$stderr" == *cache.name* ]]
}

@test "not TOML: exit 2 names the file" {
    refused 'TOML' 'version ='
}

@test "a path with spaces is read (passed to nix as data, not code)" {
    dir="$BATS_TEST_TMPDIR/my \"project\" \${x}"
    mkdir -p "$dir"
    printf '%s\n' 'version = 1' '[session]' 'model = "opus"' >"$dir/.claudinix.toml"
    run --separate-stderr bash "$SCRIPT" --dir "$dir" get session.model
    [ "$status" -eq 0 ]
    [ "$output" = opus ]
}

@test "--dir reads that directory's file, not the cwd's" {
    toml 'version = 1' '[session]' 'model = "opus"'
    other="$BATS_TEST_TMPDIR/other"
    mkdir -p "$other"
    run --separate-stderr bash "$SCRIPT" --dir "$other" get session.model
    [ "$output" = sonnet ]
    cd "$other"
    run --separate-stderr bash "$SCRIPT" --dir ../project get session.model
    [ "$output" = opus ]
}

@test "--dir names a missing directory as given: exit 2 (V26)" {
    run --separate-stderr bash "$SCRIPT" --dir no/such/dir json
    [ "$status" -eq 2 ]
    [[ "$stderr" == *"no/such/dir"* ]]
}

@test "a refused file is named as given, relative stays relative (V26)" {
    toml 'version = 3'
    cd "$BATS_TEST_TMPDIR"
    run --separate-stderr bash "$SCRIPT" --dir project check
    [ "$status" -eq 2 ]
    [[ "$stderr" == *"project/.claudinix.toml"* ]]
    [[ "$stderr" != *"$PROJECT/.claudinix.toml"* ]]
}

@test "without --dir: the file at the root of the cwd's git repo" {
    git init -q "$PROJECT"
    toml 'version = 1' '[session]' 'model = "opus"'
    mkdir -p "$PROJECT/sub/dir"
    cd "$PROJECT/sub/dir"
    run --separate-stderr bash "$SCRIPT" get session.model
    [ "$status" -eq 0 ]
    [ "$output" = opus ]
}

@test "without --dir outside a git repo: the cwd's file" {
    toml 'version = 1' '[session]' 'model = "opus"'
    run --separate-stderr bash "$SCRIPT" get session.model
    [ "$output" = opus ]
}

@test "CLAUDINIX_CONFIG names the file to read" {
    printf '%s\n' 'version = 1' '[cache]' 'name = "seam"' >"$BATS_TEST_TMPDIR/x.toml"
    CLAUDINIX_CONFIG="$BATS_TEST_TMPDIR/x.toml" run --separate-stderr bash "$SCRIPT" get cache.name
    [ "$output" = seam ]
}

@test "usage errors exit 2" {
    run bash "$SCRIPT"
    [ "$status" -eq 2 ]
    [[ "$output" == *usage* ]]
    run bash "$SCRIPT" get
    [ "$status" -eq 2 ]
    run bash "$SCRIPT" json extra
    [ "$status" -eq 2 ]
    run bash "$SCRIPT" --dir
    [ "$status" -eq 2 ]
    run bash "$SCRIPT" --frob json
    [ "$status" -eq 2 ]
    run bash "$SCRIPT" frob
    [ "$status" -eq 2 ]
}
