//! The step counts docs/INTEGRATION.md states, against hk.pkl's.

use super::{drift, rewrite};

const DOC: &str = "| caller | set | when |
|---|---|---|
| `pre-commit` hook | `fast`, 27 steps | every commit |
| `pre-push` hook | `all`, 30 steps | every push |
| `hk check --all` in CI | `all`, 30 steps | CI |

`all` is `fast` plus three steps that judge the branch rather than a single
commit.
";

#[test]
fn matching_counts_have_no_drift() {
    assert_eq!(drift(DOC, 27, 30), Ok(Vec::new()));
}

#[test]
fn every_stale_number_is_named_with_hk_pkls() {
    let problems = drift(DOC, 31, 35).unwrap_or_default();
    assert_eq!(
        problems,
        vec![
            "line 3: `fast`, 27 steps; hk.pkl has 31".to_owned(),
            "line 4: `all`, 30 steps; hk.pkl has 35".to_owned(),
            "line 5: `all`, 30 steps; hk.pkl has 35".to_owned(),
        ]
    );
    let problems = drift(DOC, 26, 30).unwrap_or_default();
    assert_eq!(
        problems,
        vec![
            "line 3: `fast`, 27 steps; hk.pkl has 26".to_owned(),
            "line 7: `all` is `fast` plus three steps; hk.pkl has four".to_owned(),
        ]
    );
}

/// dev:V1: a doc that states no count is an error, not a pass.
#[test]
fn a_doc_stating_no_count_is_an_error() {
    assert!(drift("# nothing\n", 27, 30).is_err());
    assert!(drift("`fast`, 27 steps\n", 27, 30).is_err());
}

#[test]
fn rewrite_fixes_every_count_and_is_idempotent() {
    let fixed = rewrite(DOC, 31, 35);
    assert_eq!(drift(&fixed, 31, 35), Ok(Vec::new()));
    assert!(fixed.contains("| `pre-commit` hook | `fast`, 31 steps | every commit |"));
    assert!(fixed.contains("`all` is `fast` plus four steps that judge"));
    assert_eq!(rewrite(&fixed, 31, 35), fixed);
    assert_eq!(rewrite(DOC, 27, 30), DOC);
}
