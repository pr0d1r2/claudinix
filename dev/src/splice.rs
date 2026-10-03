//! The generated badge block inside README.md, between
//! `<!-- BEGIN badges -->` and `<!-- END badges -->`.

/// The opening marker.
pub const BEGIN: &str = "<!-- BEGIN badges -->";
/// The closing marker.
pub const END: &str = "<!-- END badges -->";

/// The block in `doc`, markers and the closing newline included.
#[must_use]
pub fn current(_doc: &str) -> Option<&str> {
    None
}

/// `doc` with its block replaced by `block`, or with `block` inserted
/// under the `# ` title when it has none; `None` when neither fits.
#[must_use]
pub fn splice(_doc: &str, _block: &str) -> Option<String> {
    None
}

/// The lines only `old` has (`-`), then the lines only `new` has (`+`).
#[must_use]
pub fn diff(_old: &str, _new: &str) -> String {
    String::new()
}

#[cfg(test)]
mod tests;
