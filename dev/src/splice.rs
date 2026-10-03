//! The generated badge block inside README.md, between
//! `<!-- BEGIN badges -->` and `<!-- END badges -->`.

/// The opening marker.
pub const BEGIN: &str = "<!-- BEGIN badges -->";
/// The closing marker.
pub const END: &str = "<!-- END badges -->";

/// Byte range of the block in `doc`: from the opening marker through the
/// closing marker and the newline after it.
fn span(doc: &str) -> Option<(usize, usize)> {
    let start = doc.find(BEGIN)?;
    let stop = doc.get(start..)?.find(END)? + start + END.len();
    let stop = if doc.get(stop..)?.starts_with('\n') {
        stop + 1
    } else {
        stop
    };
    Some((start, stop))
}

/// The block in `doc`, markers and the closing newline included.
#[must_use]
pub fn current(doc: &str) -> Option<&str> {
    let (start, stop) = span(doc)?;
    doc.get(start..stop)
}

/// `doc` with its block replaced by `block`, or with `block` inserted
/// under the `# ` title when it has none; `None` when neither fits. A doc
/// with an opening marker but no closing one is refused rather than
/// guessed at. Idempotent: `splice(splice(x)) == splice(x)` (dev:V3).
#[must_use]
pub fn splice(doc: &str, block: &str) -> Option<String> {
    if let Some((start, stop)) = span(doc) {
        return Some(format!("{}{block}{}", doc.get(..start)?, doc.get(stop..)?));
    }
    if doc.contains(BEGIN) {
        return None;
    }
    let line_end = title_end(doc)?;
    let body = doc.get(line_end..)?;
    let body = body.strip_prefix('\n').unwrap_or(body);
    Some(format!("{}\n{block}\n{body}", doc.get(..line_end)?))
}

/// Byte offset just past the first `# ` title line's newline.
fn title_end(doc: &str) -> Option<usize> {
    let mut offset = 0;
    for line in doc.split_inclusive('\n') {
        offset += line.len();
        if line.starts_with("# ") && line.ends_with('\n') {
            return Some(offset);
        }
    }
    None
}

/// The lines only `old` has (`-`), then the lines only `new` has (`+`).
#[must_use]
pub fn diff(old: &str, new: &str) -> String {
    let gone = old
        .lines()
        .filter(|line| !new.lines().any(|other| other == *line))
        .map(|line| format!("-{line}\n"));
    let added = new
        .lines()
        .filter(|line| !old.lines().any(|other| other == *line))
        .map(|line| format!("+{line}\n"));
    gone.chain(added).collect()
}

#[cfg(test)]
mod tests;
