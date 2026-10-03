//! Named blocks: only the named one is replaced, and twice is once
//! (dev:V3).

use super::{current, splice};

const DOC: &str = "# t\n\n<!-- BEGIN x: generated; do not edit -->\nold\n<!-- END x -->\n\n<!-- BEGIN y -->\nkeep\n<!-- END y -->\nbody\n";

#[test]
fn only_the_named_block_is_replaced() {
    let block = "<!-- BEGIN x: generated; do not edit -->\nNEW\n<!-- END x -->\n";
    assert_eq!(
        splice(DOC, "x", block).as_deref(),
        Some(
            "# t\n\n<!-- BEGIN x: generated; do not edit -->\nNEW\n<!-- END x -->\n\n<!-- BEGIN y -->\nkeep\n<!-- END y -->\nbody\n"
        )
    );
}

#[test]
fn a_missing_or_unclosed_block_is_refused() {
    assert_eq!(splice(DOC, "z", "z\n"), None);
    assert_eq!(splice("<!-- BEGIN x -->\nno end\n", "x", "x\n"), None);
    assert_eq!(splice("# no markers\n", "x", "x\n"), None);
}

/// A name that prefixes another (`x` and `xy`) never matches the longer.
#[test]
fn a_name_matches_whole() {
    let doc = "<!-- BEGIN xy -->\na\n<!-- END xy -->\n";
    assert_eq!(splice(doc, "x", "b\n"), None);
    assert_eq!(current(doc, "x"), None);
}

/// dev:V3: splicing twice is splicing once.
#[test]
fn splicing_twice_is_splicing_once() {
    let block = "<!-- BEGIN x -->\nNEW\n<!-- END x -->\n";
    let once = splice(DOC, "x", block).unwrap_or_default();
    assert_eq!(splice(&once, "x", block).as_deref(), Some(once.as_str()));
}

#[test]
fn the_current_block_includes_its_markers() {
    assert_eq!(
        current(DOC, "x"),
        Some("<!-- BEGIN x: generated; do not edit -->\nold\n<!-- END x -->\n")
    );
    assert_eq!(
        current(DOC, "y"),
        Some("<!-- BEGIN y -->\nkeep\n<!-- END y -->\n")
    );
    assert_eq!(current(DOC, "z"), None);
}
