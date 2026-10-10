#!/usr/bin/env bats
# shellcheck disable=SC2086 # $SKILLS is a word list, the check's SKILL... arguments
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
    # What the hook commands point at; full_home creates them.
    BASH_BIN="$BATS_TEST_TMPDIR/store/abc-bash/bin/bash"
    NODE="$BATS_TEST_TMPDIR/store/abc-nodejs/bin/node"
    SRC="$BATS_TEST_TMPDIR/store/abc-source/src/hooks"
    RTKBIN="$BATS_TEST_TMPDIR/store/abc-rtk/bin/rtk"
    HOOKS="{\"SessionStart\":[{\"hooks\":[{\"type\":\"command\",\"command\":\"$NODE $SRC/caveman-activate.js\",\"timeout\":30}]}],\"SubagentStart\":[{\"hooks\":[{\"type\":\"command\",\"command\":\"$NODE $SRC/caveman-activate.js --subagent\",\"timeout\":30}]}],\"UserPromptSubmit\":[{\"hooks\":[{\"type\":\"command\",\"command\":\"$NODE $SRC/caveman-mode-tracker.js\",\"timeout\":30}]}],\"SessionEnd\":[{\"hooks\":[{\"type\":\"command\",\"command\":\"$NODE $SRC/caveman-stats.js --record\",\"timeout\":30}]}],\"PreToolUse\":[{\"matcher\":\"Bash\",\"hooks\":[{\"type\":\"command\",\"command\":\"$RTKBIN hook claude\"}]}]}"
    STATUSLINE="{\"type\":\"command\",\"command\":\"$BASH_BIN $SRC/caveman-statusline.sh\"}"
    # Every toggle of nix/agent-home.toml on but caveman-commit (nix:T154, V45).
    SKILLS="ck-spec ck-build ck-check ck-backprop ck-caveman ck-deepen ck-grill ck-research ck-review caveman caveman-review caveman-help caveman-compress investigate-first surgical-patch safe-refactor lean-build migration verify-and-stop ultracave megacave cavecrew caveman-explore caveman-stats"
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
        printf -- "---\nname: %s\n---\n# %s\n" "$skill" "$skill" >"$CLAUDE/skills/$skill/SKILL.md"
    done
    echo "# format" >"$CLAUDE/FORMAT.md"
    mkdir -p "$CLAUDE/rules/set"
    echo "# set" >"$CLAUDE/rules/set/generic.md"
    echo "# rtk" >"$CLAUDE/RTK.md"
    printf "@RTK.md\n" >"$CLAUDE/CLAUDE.md"
    mkdir -p "$PKG/home-path/bin"
    printf "#!/usr/bin/env bash\n" >"$PKG/home-path/bin/rtk"
    chmod +x "$PKG/home-path/bin/rtk"
    mkdir -p "$SRC" "$(dirname "$NODE")" "$(dirname "$RTKBIN")"
    mkdir -p "$(dirname "$BASH_BIN")"
    touch "$BASH_BIN" "$NODE" "$RTKBIN" "$SRC/caveman-activate.js" "$SRC/caveman-mode-tracker.js" "$SRC/caveman-statusline.sh" "$SRC/caveman-stats.js"
    # cavecrew delegates to its three agents (nix:T154).
    mkdir -p "$CLAUDE/agents"
    for agent in builder investigator reviewer; do
        echo "# cavecrew-$agent" >"$CLAUDE/agents/cavecrew-$agent.md"
    done
    # shellcheck disable=SC2016 # $DRY_RUN_CMD is the activate script's own
    printf '#!/usr/bin/env bash\nnoteEcho claudeSettings\n$DRY_RUN_CMD bash %s\n' "$MERGE" >"$PKG/activate"
    merge_writes "{\"permissions\": $(cat "$PERMS"), \"model\": \"x\", \"hooks\": $HOOKS, \"statusLine\": $STATUSLINE}"
}

@test "complete home: passes and writes OUT" {
    full_home
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 0 ]
    [ -e "$OUT" ]
}

@test "a /ck-<verb> reference to a skill not shipped: fails, names it (nix:V47, nix:B50)" {
    full_home
    rm -r "$CLAUDE/skills/ck-research"
    echo "Run /ck-research first, then /ck-build." >>"$CLAUDE/skills/ck-spec/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" ${SKILLS/ck-research /}
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/ck-spec/SKILL.md"* ]]
    [[ "$output" == *"/ck-research"* ]]
    [[ "$output" != *"/ck-build"* ]]
    [ ! -e "$OUT" ]
}

@test "a /ck-<verb> reference to a shipped skill: passes (nix:V47)" {
    full_home
    echo "Run /ck-build, see skills/ck-spec/SKILL.md." >>"$CLAUDE/skills/ck-spec/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 0 ]
}

@test "missing skill: fails, names it, writes no OUT" {
    full_home
    rm "$CLAUDE/skills/ck-backprop/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/ck-backprop/SKILL.md"* ]]
    [ ! -e "$OUT" ]
}

@test "missing FORMAT.md: fails and names it" {
    full_home
    rm "$CLAUDE/FORMAT.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"FORMAT.md"* ]]
}

@test "every missing file is reported, not only the first" {
    full_home
    rm "$CLAUDE/skills/ck-spec/SKILL.md" "$CLAUDE/skills/caveman/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/ck-spec/SKILL.md"* ]]
    [[ "$output" == *"skills/caveman/SKILL.md"* ]]
}

@test "empty skill file counts as missing" {
    full_home
    : >"$CLAUDE/skills/ck-build/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/ck-build/SKILL.md"* ]]
}

@test "dangling link counts as missing" {
    full_home
    rm "$CLAUDE/skills/ck-check/SKILL.md"
    ln -s "$BATS_TEST_TMPDIR/nowhere" "$CLAUDE/skills/ck-check/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/ck-check/SKILL.md"* ]]
}

@test "set rules dir without any rule: fails" {
    full_home
    rm "$CLAUDE/rules/set/generic.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"rules/set"* ]]
}

@test "not an activation package: fails, nothing checked" {
    mkdir -p "$PKG"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"home-files"* ]]
    [ ! -e "$OUT" ]
}

@test "settings carry other permissions than the list: fails and says so" {
    full_home
    merge_writes '{"permissions":{"allow":["Bash(bats *)","Bash"],"deny":["Bash(git push * main)"]}}'
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"permissions"* ]]
    [ ! -e "$OUT" ]
}

@test "settings without permissions: fails" {
    full_home
    merge_writes '{"model":"x"}'
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"permissions"* ]]
}

@test "activation runs no settings merge: fails and names settings.json" {
    full_home
    printf '#!/usr/bin/env bash\n' >"$PKG/activate"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"settings.json"* ]]
    [ ! -e "$OUT" ]
}

@test "the merge never touches the real HOME" {
    full_home
    run env HOME="$BATS_TEST_TMPDIR/realhome" bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS $SKILLS
    [ "$status" -eq 0 ]
    [ ! -e "$BATS_TEST_TMPDIR/realhome" ]
}

@test "missing RTK.md: fails and names it (nix:T151)" {
    full_home
    rm "$CLAUDE/RTK.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"RTK.md"* ]]
    [ ! -e "$OUT" ]
}

@test "CLAUDE.md without the @RTK.md line: fails (nix:T151)" {
    full_home
    echo "# other" >"$CLAUDE/CLAUDE.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"@RTK.md"* ]]
}

@test "no rtk in home-path/bin: fails (nix:T151)" {
    full_home
    rm "$PKG/home-path/bin/rtk"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"home-path/bin/rtk"* ]]
}

@test "settings without the rtk Bash hook: fails (nix:T151)" {
    full_home
    merge_writes "{\"permissions\": $(cat "$PERMS")}"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"rtk hook claude"* ]]
    [ ! -e "$OUT" ]
}

@test "rtk hook on another matcher than Bash: fails (nix:T151)" {
    full_home
    merge_writes "{\"permissions\": $(cat "$PERMS"), \"hooks\": ${HOOKS/\"Bash\"/\"Read\"}}"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"rtk hook claude"* ]]
}

@test "missing cavekit 4.1 skill: fails and names it (nix:T153)" {
    full_home
    rm "$CLAUDE/skills/ck-grill/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/ck-grill/SKILL.md"* ]]
    [ ! -e "$OUT" ]
}

@test "missing caveman skill: fails and names it (nix:T153)" {
    full_home
    rm "$CLAUDE/skills/caveman-review/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/caveman-review/SKILL.md"* ]]
}

@test "caveman-commit in the home: fails, it competes with commit-msg (nix:V45)" {
    full_home
    mkdir -p "$CLAUDE/skills/caveman-commit"
    echo "# caveman-commit" >"$CLAUDE/skills/caveman-commit/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"caveman-commit"* ]]
    [ ! -e "$OUT" ]
}

# without_hook EVENT: the complete settings minus the hooks of EVENT.
without_hook() {
    merge_writes "{\"permissions\": $(cat "$PERMS"), \"hooks\": $(jq -c --arg e "$1" 'del(.[$e])' <<<"$HOOKS"), \"statusLine\": $STATUSLINE}"
}

@test "no caveman SessionStart hook: fails and names it (nix:T153)" {
    full_home
    without_hook SessionStart
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"SessionStart"* ]]
    [[ "$output" == *"caveman-activate.js"* ]]
    [ ! -e "$OUT" ]
}

@test "no caveman SubagentStart hook: fails and names it (nix:T153)" {
    full_home
    without_hook SubagentStart
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"SubagentStart"* ]]
}

@test "no caveman UserPromptSubmit hook: fails and names it (nix:T153)" {
    full_home
    without_hook UserPromptSubmit
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"UserPromptSubmit"* ]]
    [[ "$output" == *"caveman-mode-tracker.js"* ]]
}

@test "caveman hook run by a bare node: fails (nix:T153)" {
    full_home
    merge_writes "{\"permissions\": $(cat "$PERMS"), \"hooks\": ${HOOKS//$NODE/node}, \"statusLine\": $STATUSLINE}"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"node"* ]]
}

@test "hook script missing from the store: fails and names it (nix:V46)" {
    full_home
    rm "$SRC/caveman-activate.js"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"caveman-activate.js"* ]]
    [ ! -e "$OUT" ]
}

@test "statusLine script missing from the store: fails and names it (nix:V46)" {
    full_home
    rm "$SRC/caveman-statusline.sh"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"caveman-statusline.sh"* ]]
}

@test "caveman hook with a 5 s timeout: fails, upstream gives 30 s (nix:V46)" {
    full_home
    merge_writes "{\"permissions\": $(cat "$PERMS"), \"hooks\": ${HOOKS//\"timeout\":30/\"timeout\":5}, \"statusLine\": $STATUSLINE}"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"timeout"* ]]
    [ ! -e "$OUT" ]
}

@test "statusLine run by a bare bash: fails (nix:V46)" {
    full_home
    merge_writes "{\"permissions\": $(cat "$PERMS"), \"hooks\": $HOOKS, \"statusLine\": ${STATUSLINE//$BASH_BIN/bash}}"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"statusLine"* ]]
    [ ! -e "$OUT" ]
}

@test "settings without a statusLine: fails (nix:T153)" {
    full_home
    merge_writes "{\"permissions\": $(cat "$PERMS"), \"hooks\": $HOOKS}"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"statusLine"* ]]
}

@test "the skills to look for are the arguments, not a list in the script" {
    full_home
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS not-shipped
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/not-shipped/SKILL.md"* ]]
    [ ! -e "$OUT" ]
}

@test "a skill that is not toggled on: fails and names it (nix:V47)" {
    full_home
    mkdir -p "$CLAUDE/skills/stray"
    printf -- "---\nname: stray\n---\n" >"$CLAUDE/skills/stray/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/stray"* ]]
    [ ! -e "$OUT" ]
}

@test "a skill whose name: is not its directory: fails and names both (nix:V47)" {
    full_home
    printf -- "---\nname: spec\n---\n" >"$CLAUDE/skills/ck-spec/SKILL.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"ck-spec"* ]]
    [[ "$output" == *"name: spec"* ]]
}

@test "cavecrew on, no agent at all: fails (nix:T154)" {
    full_home
    rm "$CLAUDE"/agents/cavecrew-*.md
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"cavecrew is on but"* ]]
}

@test "cavecrew on, an empty agent file: fails and names it (nix:T154)" {
    full_home
    : >"$CLAUDE/agents/cavecrew-reviewer.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"agents/cavecrew-reviewer.md"* ]]
}

@test "cavecrew on: agent names come from the source, not the check (nix:T154)" {
    full_home
    rm "$CLAUDE"/agents/cavecrew-*.md
    echo "# planner" >"$CLAUDE/agents/cavecrew-planner.md"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 0 ]
}

@test "cavecrew off: its agents must be gone too (nix:T154)" {
    full_home
    rm -r "$CLAUDE/skills/cavecrew"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" ${SKILLS/ cavecrew/}
    [ "$status" -eq 1 ]
    [[ "$output" == *"agents/cavecrew-"* ]]
}

@test "cavecrew off and no agents: passes (nix:T154)" {
    full_home
    rm -r "$CLAUDE/skills/cavecrew" "$CLAUDE/agents"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" ${SKILLS/ cavecrew/}
    [ "$status" -eq 0 ]
}

@test "caveman-stats on without its SessionEnd hook: fails (nix:T154)" {
    full_home
    without_hook SessionEnd
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" $SKILLS
    [ "$status" -eq 1 ]
    [[ "$output" == *"SessionEnd"* ]]
    [[ "$output" == *"caveman-stats.js"* ]]
}

@test "caveman-stats off: no SessionEnd hook needed (nix:T154)" {
    full_home
    rm -r "$CLAUDE/skills/caveman-stats"
    without_hook SessionEnd
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" ${SKILLS/ caveman-stats/}
    [ "$status" -eq 0 ]
}

@test "caveman-stats off but its SessionEnd hook in settings: fails (nix:V47)" {
    full_home
    rm -r "$CLAUDE/skills/caveman-stats"
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT" ${SKILLS/ caveman-stats/}
    [ "$status" -eq 1 ]
    [[ "$output" == *"caveman-stats is off"* ]]
    [[ "$output" == *"SessionEnd"* ]]
    [ ! -e "$OUT" ]
}

@test "no skill argument is a usage error" {
    run bash "$SCRIPT" "$PKG" "$PERMS" "$OUT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"SKILL"* ]]
}

@test "missing arguments is a usage error" {
    run bash "$SCRIPT" "$PKG" "$OUT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage"* ]]
}
