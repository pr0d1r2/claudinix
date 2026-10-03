//! The changelog rule: which commits it binds, which paths are session
//! code, and what it says when it refuses.

use super::{Head, behaviour, check, session, subject};

const FEAT: &str = "feat(setup): pin a newer Nix\n\nWhy: x.\nRefs: y\n";

#[test]
fn the_subject_skips_comments_and_the_scissors() {
    assert_eq!(subject("# note\nfix: a\n\nbody\n"), "fix: a");
    let verbose = "# ------------------------ >8 ------------------------\nfeat: b\n";
    assert_eq!(subject(verbose), "");
    assert_eq!(subject(""), "");
}

#[test]
fn only_feat_and_fix_are_behaviour() {
    for yes in ["feat: a", "fix(setup): a", "feat!: a", "fix(nix)!: a"] {
        assert!(behaviour(yes), "{yes}");
    }
    for no in [
        "docs: a",
        "test(dev): a",
        "refactor: a",
        "chore: a",
        "build(hk): a",
        "ci: a",
        "feature: a",
        "fixup! fix: a",
        "Merge branch 'x'",
        "Revert \"feat: a\"",
    ] {
        assert!(!behaviour(no), "{no}");
    }
}

#[test]
fn session_code_is_what_a_user_gets() {
    for yes in [
        "setup.sh",
        "probe.sh",
        "allowlist.txt",
        "env-names.txt",
        "nix/cloud-home.nix",
        "nix/cloud-permissions.json",
        "nix/apps.nix",
        "scripts/nix-dev.sh",
        "scripts/domains/cargo.sh",
        "scripts/config.jq",
        "scripts/guide-steps.tsv",
    ] {
        assert!(session(yes), "{yes}");
    }
    for no in [
        "scripts/guard/commit-msg.sh",
        "scripts/hk/run-tool.sh",
        "scripts/ci/push-sources.sh",
        "scripts/dev/shell-hook.sh",
        "scripts/nix/cloud-home-check.sh",
        "scripts/SPEC.md",
        "scripts/SPEC-ARCHIVE.md",
        "tests/unit/setup.bats",
        "hk.pkl",
        "flake.nix",
        "nix/dev-shell.nix",
        "dev/src/main.rs",
        "README.md",
        "CHANGELOG.md",
        "setup.sh.orig/x",
    ] {
        assert!(!session(no), "{no}");
    }
}

#[test]
fn a_feat_touching_session_code_without_the_changelog_is_refused() {
    let refused = check(
        FEAT,
        "setup.sh\nscripts/nix-dev.sh\ntests/unit/setup.bats\n",
        None,
    )
    .err()
    .unwrap_or_default();
    for needed in [
        "feat",
        "CHANGELOG.md",
        "  setup.sh\n",
        "  scripts/nix-dev.sh\n",
        "## Unreleased",
        "git add CHANGELOG.md",
    ] {
        assert!(
            refused.contains(needed),
            "{needed:?} missing from {refused:?}"
        );
    }
    assert!(!refused.contains("setup.bats"));
}

#[test]
fn staging_the_changelog_passes() {
    assert_eq!(check(FEAT, "setup.sh\nCHANGELOG.md\n", None), Ok(()));
}

#[test]
fn exempt_kinds_and_paths_pass() {
    for message in [
        "docs(readme): a\n",
        "test(setup): a\n",
        "refactor(setup): a\n",
        "chore: a\n",
        "build(nix): a\n",
        "ci: a\n",
        "Merge branch 'x'\n",
        "Revert \"feat: a\"\n",
        "fixup! feat: a\n",
        "squash! fix: a\n",
        "amend! fix: a\n",
    ] {
        assert_eq!(check(message, "setup.sh\n", None), Ok(()), "{message}");
    }
    assert_eq!(
        check(
            FEAT,
            "scripts/guard/tdd-order.sh\nhk.pkl\ndev/src/main.rs\n",
            None
        ),
        Ok(())
    );
    assert_eq!(check(FEAT, "", None), Ok(()));
}

/// `git commit --amend` with nothing new staged: HEAD already brought the
/// entry under the same subject.
#[test]
fn an_amend_of_a_commit_with_its_entry_passes() {
    let head = Head {
        subject: "feat(setup): pin a newer Nix",
        files: "setup.sh\nCHANGELOG.md\n",
    };
    assert_eq!(check(FEAT, "setup.sh\n", Some(&head)), Ok(()));
    let other = Head {
        subject: "feat(setup): something else",
        files: "CHANGELOG.md\n",
    };
    assert!(check(FEAT, "setup.sh\n", Some(&other)).is_err());
    let bare = Head {
        subject: "feat(setup): pin a newer Nix",
        files: "setup.sh\n",
    };
    assert!(check(FEAT, "setup.sh\n", Some(&bare)).is_err());
}
