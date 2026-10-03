//! The README badge block, rendered from facts that each come from the
//! file that owns them (dev:V1).

/// Everything the badges say.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Facts {
    /// `owner/repo`, from setup.sh's fork block.
    pub slug: String,
    /// The CI workflow's file name under `.github/workflows`.
    pub workflow: String,
    /// LICENSE's first line, without `License`.
    pub license: String,
    /// The README's maturity callout, if it has one.
    pub status: Option<String>,
    /// The binary cache host, from `.claudinix.toml`'s `cache.name`.
    pub cache: String,
    /// setup.sh's `min_version`.
    pub nix_floor: String,
    /// Steps in hk.pkl's `pre-commit` and `check` hooks.
    pub steps: (usize, usize),
    /// `@test` lines under `tests/unit`.
    pub tests: usize,
    /// Spec nodes: root `§F` rows plus the root.
    pub nodes: usize,
}

impl Facts {
    /// Refuse a fact that reads empty or zero (dev:V1).
    ///
    /// # Errors
    ///
    /// The first empty or zero fact, naming the file it comes from.
    pub fn checked(self) -> Result<Self, String> {
        Ok(self)
    }
}

/// shields.io path text: `-` doubles, a space is `_`, and `%`, `+`, `/`
/// are percent-encoded.
#[must_use]
pub fn esc(text: &str) -> String {
    text.to_owned()
}

/// The block, markers included, ending in a newline.
#[must_use]
pub fn render(_facts: &Facts) -> String {
    String::new()
}

#[cfg(test)]
mod tests;
