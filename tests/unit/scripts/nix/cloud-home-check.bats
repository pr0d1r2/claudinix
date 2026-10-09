#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Unit tests for scripts/nix/cloud-home-check.sh (SPEC nix:T16, nix:V14,
# C12, nix:T153): the agent home's activation package carries the cavekit
# and caveman skills, caveman's hooks and a statusLine, rtk (nix:T151),
# FORMAT.md and the set rules under home-files/.claude, and its settings
# merge writes exactly the cloud permissions into settings.json (T101).

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../../../../scripts/nix/cloud-home-check.sh"
    PKG="$BATS_TEST_TMPDIR/activation"
    OUT="$BATS_TEST_TMPDIR/out"
    CLAUDE="$PKG/home-files/.claude"
    PERMS="$BATS_TEST_TMPDIR/cloud-permissions.json"
    echo '{"allow":["Bash(bats *)"],"deny":["Bash(git push * main)"]}' >"$PERMS"
    MERGE="$BATS_TEST_TMPDIR/store/abc123-run-merge-settings.sh"
    MERGED="$BATS_TEST_TMPDIR/merged.json"
    HOOKS='{"SessionStart":[{"hooks":[{"type":"command","command":"/nix/store/abc-nodejs/bin/node /nix/store/abc-source/src/hooks/caveman-activate.js"}]}],"SubagentStart":[{"hooks":[{"type":"command","command":"/nix/store/abc-nodejs/bin/node /nix/store/abc-source/src/hooks/caveman-activate.js --subagent"}]}],"UserPromptSubmit":[{"hooks":[{"type":"command","command":"/nix/store/abc-nodejs/bin/node /nix/store/abc-source/src/hooks/caveman-mode-tracker.js"}]}],"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"/nix/store/abc-rtk/bin/rtk hook claude"}]}]}'
    STATUSLINE='{"type":"command","command":"bash /nix/store/abc-source/src/hooks/caveman-statusline.sh"}'
    # cavekit v4.1.0 (all nine) and the caveman skills the owner uses (nix:T153).
    SKILLS="spec build check backprop caveman deepen grill research review caveman-commit caveman-review caveman-help caveman-compress"
}

# merge_writes JSON: the settings merge the activation runs writes JSON
# to $HOME/.claude/settings.json, as the claude-code module's does.
merge_writes() {
    mkdir -p "$(dirname "$MERGE")"
    printf '%s\n' "$1" >"$MERGED"
    # shellcheck disable=SC2016 # $HOME expands when the merge runs
    printf '#!/usr/bin/env bash\nmkdir -p "$HOME/.claude"\ncp %s "$HOME/.claude/settings.json"\n' "$MERGED" >"$MERGE"
}

# A complete home: every required file, as the store links them.
full_home() {
    local skill
    for skill in $SKILLS; do
        mkdir -p "$CLAUDE/skills/$skill"
        echo "# $skill" >"$CLAUDE/skills/$skill/SKILL.md"
    done
    echo "# format" >"$CLAUDE/FORMAT.md"
    mkdir -p "$CLAUDE/rules/set"
    echo "# set" >"$CLAUDE/rules/set/generic.md"
    echo "# rtk" >"$CLAUDE/RTK.md"
    printf "@RTK.md\n" >"$CLAUDE/CLAUDE.md"
    mkdir -p "$PKG/home-path/bin"
    printf "#!/usr/bin/env bash\n" >"$PKG/home-path/bin/rtk"
    chmod +x "$PKG/home-path/bin/rtk"
    # shellcheck disable=SC2016 # $DRY_RUN_CMD is the activate script's own
    printf '#!/usr/bin/env bash\nnoteEcho claudeSettings\n$DRY_RUN_CMD bash %s\n' "$MERGE" >"$PKG/activate"
    merge_writes "{\"permissions\": $(cat "$PERMS"), \"model\": \"x\", \"hooks\": $HOOKS, \"statusLine\": $STATUSLINE}"
}

@test "complete home: passes and writes OUT" {
    full_home
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 0 ]
    [ -e "$OUT" ]
}

@test "missing skill: fails, names it, writes no OUT" {
    full_home
    rm "$CLAUDE/skills/backprop/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/backprop/SKILL.md"* ]]
    [ ! -e "$OUT" ]
}

@test "missing FORMAT.md: fails and names it" {
    full_home
    rm "$CLAUDE/FORMAT.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"FORMAT.md"* ]]
}

@test "every missing file is reported, not only the first" {
    full_home
    rm "$CLAUDE/skills/spec/SKILL.md" "$CLAUDE/skills/caveman/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/spec/SKILL.md"* ]]
    [[ "$output" == *"skills/caveman/SKILL.md"* ]]
}

@test "empty skill file counts as missing" {
    full_home
    : >"$CLAUDE/skills/build/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/build/SKILL.md"* ]]
}

@test "dangling link counts as missing" {
    full_home
    rm "$CLAUDE/skills/check/SKILL.md"
    ln -s "$BATS_TEST_TMPDIR/nowhere" "$CLAUDE/skills/check/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/check/SKILL.md"* ]]
}

@test "set rules dir without any rule: fails" {
    full_home
    rm "$CLAUDE/rules/set/generic.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"rules/set"* ]]
}

@test "not an activation package: fails, nothing checked" {
    mkdir -p "$PKG"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"home-files"* ]]
    [ ! -e "$OUT" ]
}

@test "settings carry other permissions than the list: fails and says so" {
    full_home
    merge_writes '{"permissions":{"allow":["Bash(bats *)","Bash"],"deny":["Bash(git push * main)"]}}'
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"permissions"* ]]
    [ ! -e "$OUT" ]
}

@test "settings without permissions: fails" {
    full_home
    merge_writes '{"model":"x"}'
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"permissions"* ]]
}

@test "activation runs no settings merge: fails and names settings.json" {
    full_home
    printf '#!/usr/bin/env bash\n' >"$PKG/activate"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"settings.json"* ]]
    [ ! -e "$OUT" ]
}

@test "the merge never touches the real HOME" {
    full_home
    run env HOME="$BATS_TEST_TMPDIR/realhome" bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 0 ]
    [ ! -e "$BATS_TEST_TMPDIR/realhome" ]
}

@test "missing RTK.md: fails and names it (nix:T151)" {
    full_home
    rm "$CLAUDE/RTK.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"RTK.md"* ]]
    [ ! -e "$OUT" ]
}

@test "CLAUDE.md without the @RTK.md line: fails (nix:T151)" {
    full_home
    echo "# other" >"$CLAUDE/CLAUDE.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"@RTK.md"* ]]
}

@test "no rtk in home-path/bin: fails (nix:T151)" {
    full_home
    rm "$PKG/home-path/bin/rtk"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"home-path/bin/rtk"* ]]
}

@test "settings without the rtk Bash hook: fails (nix:T151)" {
    full_home
    merge_writes "{\"permissions\": $(cat "$PERMS")}"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"rtk hook claude"* ]]
    [ ! -e "$OUT" ]
}

@test "rtk hook on another matcher than Bash: fails (nix:T151)" {
    full_home
    merge_writes "{\"permissions\": $(cat "$PERMS"), \"hooks\": ${HOOKS/\"Bash\"/\"Read\"}}"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"rtk hook claude"* ]]
}

@test "missing cavekit 4.1 skill: fails and names it (nix:T153)" {
    full_home
    rm "$CLAUDE/skills/grill/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/grill/SKILL.md"* ]]
    [ ! -e "$OUT" ]
}

@test "missing caveman skill: fails and names it (nix:T153)" {
    full_home
    rm "$CLAUDE/skills/caveman-commit/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/caveman-commit/SKILL.md"* ]]
}

# without_hook EVENT: the complete settings minus the hooks of EVENT.
without_hook() {
    merge_writes "{\"permissions\": $(cat "$PERMS"), \"hooks\": $(jq -c --arg e "$1" 'del(.[$e])' <<<"$HOOKS"), \"statusLine\": $STATUSLINE}"
}

@test "no caveman SessionStart hook: fails and names it (nix:T153)" {
    full_home
    without_hook SessionStart
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"SessionStart"* ]]
    [[ "$output" == *"caveman-activate.js"* ]]
    [ ! -e "$OUT" ]
}

@test "no caveman SubagentStart hook: fails and names it (nix:T153)" {
    full_home
    without_hook SubagentStart
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"SubagentStart"* ]]
}

@test "no caveman UserPromptSubmit hook: fails and names it (nix:T153)" {
    full_home
    without_hook UserPromptSubmit
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"UserPromptSubmit"* ]]
    [[ "$output" == *"caveman-mode-tracker.js"* ]]
}

@test "caveman hook run by a bare node: fails (nix:T153)" {
    full_home
    merge_writes "{\"permissions\": $(cat "$PERMS"), \"hooks\": ${HOOKS//\/nix\/store\/abc-nodejs\/bin\/node/node}, \"statusLine\": $STATUSLINE}"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"node"* ]]
}

@test "settings without a statusLine: fails (nix:T153)" {
    full_home
    merge_writes "{\"permissions\": $(cat "$PERMS"), \"hooks\": $HOOKS}"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"statusLine"* ]]
}

@test "missing arguments is a usage error" {
    run bash "$SCRIPT" "$PKG" "$OUT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
}
