//! The gate step counts `docs/INTEGRATION.md` states in its caller table
//! (`` `fast`, N steps `` and `` `all`, N steps ``) and in prose
//! (`` `all` is `fast` plus <word> steps ``), against hk.pkl's.

/// The stale statements, one line each; empty when every count matches.
///
/// # Errors
///
/// When the doc states no count for `fast` or for `all` (dev:V1): a check
/// that finds nothing to check is not a pass.
pub fn drift(_doc: &str, _fast: usize, _all: usize) -> Result<Vec<String>, String> {
    Err(String::new())
}

/// `doc` with every stated count set to hk.pkl's.
#[must_use]
pub fn rewrite(doc: &str, _fast: usize, _all: usize) -> String {
    doc.to_owned()
}

#[cfg(test)]
mod tests;
