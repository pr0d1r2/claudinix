//! Named blocks inside hand-written docs (dev:V3).

use super::{current, splice};

const DOC: &str = "# t\n\n<!-- BEGIN x: generated; do not edit -->\nold\n<!-- END x -->\n\nbody\n";

#[test]
fn only_the_named_block_is_replaced() {
    let block = "<!-- BEGIN x -->\nNEW\n<!-- END x -->\n";
    assert_eq!(
        splice(DOC, "x", block).as_deref(),
        Some("# t\n\n<!-- BEGIN x -->\nNEW\n<!-- END x -->\n\nbody\n")
    );
}

#[test]
fn a_missing_or_unclosed_block_is_refused() {
    assert_eq!(splice(DOC, "y", "Y\n"), None);
    assert_eq!(splice("<!-- BEGIN x -->\nno end\n", "x", "X\n"), None);
}

#[test]
fn a_name_is_not_a_prefix_of_another() {
    let doc = "<!-- BEGIN steps-old -->\na\n<!-- END steps-old -->\n";
    assert_eq!(splice(doc, "steps", "S\n"), None);
}

#[test]
fn a_block_at_the_end_without_a_newline_is_found() {
    let doc = "<!-- BEGIN x -->\nold\n<!-- END x -->";
    assert_eq!(splice(doc, "x", "NEW\n").as_deref(), Some("NEW\n"));
}

/// dev:V3: splice(splice(x)) == splice(x).
#[test]
fn splicing_twice_is_splicing_once() {
    let block = "<!-- BEGIN x: note -->\nNEW\n<!-- END x -->\n";
    let once = splice(DOC, "x", block).unwrap_or_default();
    assert_eq!(splice(&once, "x", block).as_deref(), Some(once.as_str()));
}

#[test]
fn the_current_block_includes_its_markers() {
    assert_eq!(
        current(DOC, "x"),
        Some("<!-- BEGIN x: generated; do not edit -->\nold\n<!-- END x -->\n")
    );
    assert_eq!(current(DOC, "y"), None);
}
