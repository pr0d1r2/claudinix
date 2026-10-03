//! Numbers README.md and docs/LLM-DISCLAIMER.md state in prose, outside
//! the generated badge block, held to the files that own them (dev:V1).
//! Only a number with an owner is a claim; a dated measurement (seconds,
//! sizes, versions seen in a session) belongs to docs/FACTS.md's dated
//! rows and is not checked here.

/// The value of every owned number.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Owners {
    /// Steps in hk.pkl's `pre-commit` hook.
    pub fast: usize,
    /// Steps in hk.pkl's `check` hook.
    pub all: usize,
    /// `@test` lines under `tests/unit`.
    pub tests: usize,
    /// Spec nodes: root `§F` rows plus the root.
    pub nodes: usize,
    /// Distinct probe numbers docs/FACTS.md's tables cite.
    pub probes: usize,
    /// setup.sh `min_version`.
    pub nix_floor: String,
    /// setup.sh `version=`, the Nix it installs.
    pub nix_pinned: String,
}

/// One number the prose states.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Claim {
    /// The phrase, as the doc says it (whitespace collapsed).
    pub said: String,
    /// The number in it.
    pub stated: String,
    /// What it should say, spelled the way the doc spells it.
    pub want: String,
    /// What the owner holds, in digits.
    pub value: String,
    /// The file that owns it.
    pub owner: &'static str,
}

/// Every claim `doc` makes, in order.
#[must_use]
pub fn claims(_doc: &str, _owners: &Owners) -> Vec<Claim> {
    Vec::new()
}

/// One line per stale claim in `file`; empty when all match.
#[must_use]
pub fn drift(_file: &str, _claims: &[Claim]) -> Vec<String> {
    Vec::new()
}

/// Distinct probe numbers cited in docs/FACTS.md's table rows (`probe 1`,
/// `probes 1-3`, `probes 5, 7`); 0 when none.
#[must_use]
pub fn probes(_facts_md: &str) -> usize {
    0
}

/// setup.sh's top-level `version=`, the Nix it installs below the floor.
#[must_use]
pub fn nix_pinned(_setup_sh: &str) -> Option<String> {
    None
}

#[cfg(test)]
mod tests;
