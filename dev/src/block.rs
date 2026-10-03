//! Named generated blocks inside hand-written docs, between
//! `<!-- BEGIN name ... -->` and `<!-- END name -->`. The opening marker
//! may carry a note after the name (who generates it, "do not edit").

/// Byte range of block `name` in `doc`: from the opening marker through
/// the closing marker and the newline after it.
fn span(doc: &str, name: &str) -> Option<(usize, usize)> {
    let _ = (doc, name);
    None
}

/// Block `name` in `doc`, markers and the closing newline included.
#[must_use]
pub fn current<'doc>(doc: &'doc str, name: &str) -> Option<&'doc str> {
    let (start, stop) = span(doc, name)?;
    doc.get(start..stop)
}

/// `doc` with block `name` replaced by `block` (markers included); `None`
/// when `doc` has no complete block of that name. Idempotent:
/// `splice(splice(x)) == splice(x)` (dev:V3).
#[must_use]
pub fn splice(doc: &str, name: &str, block: &str) -> Option<String> {
    let _ = (doc, name, block);
    None
}

#[cfg(test)]
mod tests;
