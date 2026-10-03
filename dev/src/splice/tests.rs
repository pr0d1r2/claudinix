//! The generated block inside the hand-written README (dev:V3).

use super::{current, diff, splice};

const BLOCK: &str = "<!-- BEGIN badges -->\nNEW\n<!-- END badges -->\n";

#[test]
fn an_existing_block_is_replaced_and_nothing_else() {
    let doc = "# t\n\n<!-- BEGIN badges -->\nold\n<!-- END badges -->\n\nbody\n";
    assert_eq!(
        splice(doc, BLOCK).as_deref(),
        Some("# t\n\n<!-- BEGIN badges -->\nNEW\n<!-- END badges -->\n\nbody\n")
    );
}

#[test]
fn a_missing_block_goes_right_under_the_title() {
    let doc = "# claudinix\n\n*tagline*\n\n## Next\n";
    assert_eq!(
        splice(doc, BLOCK).as_deref(),
        Some(
            "# claudinix\n\n<!-- BEGIN badges -->\nNEW\n<!-- END badges -->\n\n*tagline*\n\n## Next\n"
        )
    );
}

#[test]
fn no_title_and_no_block_cannot_be_spliced() {
    assert_eq!(splice("no title\n", BLOCK), None);
    assert_eq!(splice("# t\n<!-- BEGIN badges -->\nno end\n", BLOCK), None);
}

/// dev:V3: splice(splice(x)) == splice(x), with or without a block before.
#[test]
fn splicing_twice_is_splicing_once() {
    for doc in [
        "# t\n\nbody\n",
        "# t\n\n<!-- BEGIN badges -->\nold\n<!-- END badges -->\n\nbody\n",
    ] {
        let once = splice(doc, BLOCK).unwrap_or_default();
        assert_eq!(splice(&once, BLOCK).as_deref(), Some(once.as_str()));
    }
}

#[test]
fn the_current_block_includes_its_markers() {
    let doc = "# t\n\n<!-- BEGIN badges -->\nold\n<!-- END badges -->\n\nbody\n";
    assert_eq!(
        current(doc),
        Some("<!-- BEGIN badges -->\nold\n<!-- END badges -->\n")
    );
    assert_eq!(current("# t\n"), None);
}

#[test]
fn the_diff_shows_only_changed_lines() {
    let old = "a\nb\nc\n";
    let new = "a\nB\nc\nd\n";
    assert_eq!(diff(old, new), "-b\n+B\n+d\n");
    assert_eq!(diff(old, old), "");
}
