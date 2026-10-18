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
        'for i in "${!args[@]}"; do [ "${args[$i]}" != fetch ] || args[$((i + 1))]="$BARE"; done' \
        'exec "$REAL_GIT" "${args[@]}"' >"$STUBS/git-real"
    chmod +x "$STUBS/git-real"
    cd "$HERE" || return
}
