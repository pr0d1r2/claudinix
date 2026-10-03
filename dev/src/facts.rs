//! The facts the badges state, each parsed from the text of the file that
//! owns it (dev:V1). A fact that is missing or empty reads as `None` (or
//! zero), and the caller names the file.

/// `repo=` inside setup.sh's fork block, so a fork's badges follow it.
#[must_use]
pub fn fork_repo(_setup_sh: &str) -> Option<String> {
    None
}

/// The default of setup.sh's `min_version`, the oldest Nix it accepts.
#[must_use]
pub fn nix_floor(_setup_sh: &str) -> Option<String> {
    None
}

/// LICENSE's first line without the word `License`.
#[must_use]
pub fn license(_license: &str) -> Option<String> {
    None
}

/// `name` in `.claudinix.toml`'s `[cache]` table.
#[must_use]
pub fn cache_name(_toml: &str) -> Option<String> {
    None
}

/// The README's maturity callout (`> **Alpha, <date>.**`), lowercased.
#[must_use]
pub fn status(_readme: &str) -> Option<String> {
    None
}

/// `@test` lines in one bats file.
#[must_use]
pub fn bats_tests(_bats: &str) -> usize {
    0
}

/// Rows of the root spec's `§F` table plus the root itself; 0 without rows.
#[must_use]
pub fn spec_nodes(_root_spec: &str) -> usize {
    0
}

/// The count `pkl eval -x '<steps>.length'` prints; `None` for 0 or junk.
#[must_use]
pub fn step_count(_pkl_out: &str) -> Option<usize> {
    None
}

#[cfg(test)]
mod tests;
