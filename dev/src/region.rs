//! Generated blocks inside hand-written docs, between a named pair of
//! markers: `<!-- BEGIN name ... -->` and `<!-- END name -->`. Unlike the
//! README badges, a named block is never inserted: the doc's author places
//! the markers, and a doc without them is an error the caller names.

/// The block `name` in `doc`, markers and the closing newline included.
#[must_use]
pub fn current<'doc>(_doc: &'doc str, _name: &str) -> Option<&'doc str> {
    None
}

/// `doc` with block `name` replaced by `block` (markers included); `None`
/// when `doc` has no complete block of that name. Idempotent:
/// `splice(splice(x)) == splice(x)` (dev:V3).
#[must_use]
pub fn splice(_doc: &str, _name: &str, _block: &str) -> Option<String> {
    None
}

#[cfg(test)]
mod tests;
