# Fixture for the cross-repo launch tests (SPEC cloud:T175): the current dir
# becomes a checkout of me/here, and $CLAUDINIX_PROJECTS/alpha a clean checkout
# of owner/alpha on main whose github.com origin is fetched from the local
# bare repo $BARE. $STUBS/git-real runs the real git, swapping `origin` for
# $BARE on `fetch`; copy it to $STUBS/git, or call it from a git stub.
cross_fixture() {
    local real
    real="$(PATH="${PATH#"$STUBS:"}" command -v git)" # not the stub in front
    BARE="$BATS_TEST_TMPDIR/bare.git"
    PROJECTS="$BATS_TEST_TMPDIR/projects"
    HERE="$BATS_TEST_TMPDIR/here"
    export BARE PROJECTS HERE REAL_GIT="$real" CLAUDINIX_PROJECTS="$PROJECTS"
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_EXEC_PATH
    "$real" init -q --bare -b main "$BARE"
    mkdir -p "$PROJECTS" "$HERE"
    "$real" init -q -b main "$HERE"
    "$real" -C "$HERE" remote add origin https://github.com/me/here
    "$real" clone -q "$BARE" "$PROJECTS/alpha" 2>/dev/null
    "$real" -C "$PROJECTS/alpha" config user.email t@t
    "$real" -C "$PROJECTS/alpha" config user.name t
    "$real" -C "$PROJECTS/alpha" commit -q --allow-empty -m one
    "$real" -C "$PROJECTS/alpha" push -q origin main 2>/dev/null
    "$real" -C "$PROJECTS/alpha" remote set-url origin https://github.com/Owner/Alpha.git
    # shellcheck disable=SC2016 # expands inside the stub, not here
    printf '%s\n' '#!/usr/bin/env bash' \
        'args=("$@")' \
        'case " $* " in *" fetch "*) for i in "${!args[@]}"; do [ "${args[$i]}" != origin ] || args[$i]="$BARE"; done ;; esac' \
        'exec "$REAL_GIT" "${args[@]}"' >"$STUBS/git-real"
    chmod +x "$STUBS/git-real"
    cd "$HERE" || return
}

# cross_refuses_unready COMMAND...: after cross_fixture, COMMAND (a launcher run
# on the other repo's URL, so $STATE/{gh.log,claude.1} show whether it went
# on) is refused, with no session, for each unready checkout: dirty, off the
# base, behind the fetched tip, and with another repo's origin.
cross_refuses_unready() {
    local case_name want
    for case_name in dirty off-base stale-tip other-origin; do
        rm -f "$STATE/gh.log" "$STATE/claude.1"
        case "$case_name" in
        dirty) touch "$PROJECTS/alpha/stray"; want="not clean" ;;
        off-base) rm -f "$PROJECTS/alpha/stray"; git -C "$PROJECTS/alpha" checkout -q -b topic; want="not on main" ;;
        stale-tip)
            git -C "$PROJECTS/alpha" checkout -q main
            git -C "$PROJECTS/alpha" commit -q --allow-empty -m local
            want="not at the fetched"
            ;;
        other-origin)
            git -C "$PROJECTS/alpha" reset -q --hard HEAD~1
            git -C "$PROJECTS/alpha" remote set-url origin https://github.com/owner/zeta
            want="is not a checkout of owner/alpha"
            ;;
        esac
        run "$@"
        # shellcheck disable=SC2154 # status and output: set by bats `run`
        [ "$status" -eq 1 ]
        [[ "$output" == *"$want"* ]]
        [ ! -e "$STATE/claude.1" ]
        if [ "$case_name" = other-origin ]; then [ ! -e "$STATE/gh.log" ]; fi
    done
}
