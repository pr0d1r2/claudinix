//! The flake inputs table in `docs/THIRD-PARTY-NOTICES.md`, between
//! `<!-- BEGIN inputs ... -->` and `<!-- END inputs -->`, from what
//! `flake.lock` locks (dev:V1). The licence prose around it stays
//! hand-written.

/// The block's name.
pub const NAME: &str = "inputs";

/// One locked flake input.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Input {
    /// The node's name in `flake.lock`.
    pub name: String,
    /// Where it is fetched from, as a flake reference: `git+https://…`
    /// or `github:owner/repo`.
    pub source: String,
    /// The branch or tag it follows, if the lock records one.
    pub reference: Option<String>,
    /// The locked revision, short; `None` for an input without one.
    pub rev: Option<String>,
    /// The lock's `type`: `git`, `github`, ...
    pub kind: String,
}

/// Every locked node of `flake.lock`, sorted by name, the root excluded.
///
/// # Errors
///
/// When the text is not a lock file or locks nothing (dev:V1), naming
/// `flake.lock`.
pub fn inputs(_lock: &str) -> Result<Vec<Input>, String> {
    Err("not written".to_owned())
}

/// The table block, markers included, ending in a newline.
#[must_use]
pub fn table(_inputs: &[Input]) -> String {
    String::new()
}

#[cfg(test)]
mod tests;
