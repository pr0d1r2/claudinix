# Shared by the launcher tests (cloud:T177, cloud:V63): the launcher reads
# main's sha with `git ls-remote`, which their git stubs answer with BURN_SHA.

BURN_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
# The stub's case arm, one line of the printf that writes the git stub.
BURN_LS_REMOTE_CASE="ls-remote*) printf '%s\\trefs/heads/main\\n' $BURN_SHA; exit 0 ;;"

# assert_prompt_burns FILE: the launcher filled @BURN@ with the command
# pinned to BURN_SHA, and left no placeholder.
assert_prompt_burns() {
    grep -qF "?rev=$BURN_SHA#burn\" -- --self" "$1"
    run ! grep -qF '@BURN@' "$1"
}
