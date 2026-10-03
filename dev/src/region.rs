//! Generated blocks inside hand-written docs, between a named pair of
//! markers: `<!-- BEGIN name ... -->` and `<!-- END name -->`. Unlike the
//! README badges, a named block is never inserted: the doc's author places
//! the markers, and a doc without them is an error the caller names.

/// Byte range of block `name`: from the opening marker through the
/// closing marker and the newline after it.
fn span(doc: &str, name: &str) -> Option<(usize, usize)> {
    let begin = format!("<!-- BEGIN {name}");
    let end = format!("<!-- END {name} -->");
    let start = doc.match_indices(&begin).find_map(|(at, _)| {
        let next = doc.get(at + begin.len()..)?.chars().next()?;
        matches!(next, ' ' | ':').then_some(at)
    })?;
    let stop = doc.get(start..)?.find(&end)? + start + end.len();
    let stop = if doc.get(stop..)?.starts_with('\n') {
        stop + 1
    } else {
        stop
    };
    Some((start, stop))
}

/// The block `name` in `doc`, markers and the closing newline included.
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
    let (start, stop) = span(doc, name)?;
    Some(format!("{}{block}{}", doc.get(..start)?, doc.get(stop..)?))
}

#[cfg(test)]
mod tests;
