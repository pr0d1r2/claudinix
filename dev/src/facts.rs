//! The facts the badges state, each parsed from the text of the file that
//! owns it (dev:V1). A fact that is missing or empty reads as `None` (or
//! zero), and the caller names the file.

/// `Some(text)` unless it is empty.
fn filled(text: &str) -> Option<String> {
    (!text.is_empty()).then(|| text.to_owned())
}

/// `repo=` inside setup.sh's fork block, so a fork's badges follow it.
#[must_use]
pub fn fork_repo(setup_sh: &str) -> Option<String> {
    let block = setup_sh
        .lines()
        .skip_while(|line| !line.starts_with("# BEGIN fork config"))
        .take_while(|line| !line.starts_with("# END fork config"));
    block
        .filter_map(|line| line.strip_prefix("repo="))
        .find_map(|value| filled(value.trim().trim_matches('"')))
}

/// The default of setup.sh's `min_version`, the oldest Nix it accepts:
/// `min_version="${NIX_MIN_VERSION:-2.34}"` or `min_version=2.34`.
#[must_use]
pub fn nix_floor(setup_sh: &str) -> Option<String> {
    let value = setup_sh
        .lines()
        .find_map(|line| line.trim().strip_prefix("min_version="))?
        .trim()
        .trim_matches('"');
    let floor = match value.split_once(":-") {
        Some((_, default)) => default.trim_end_matches('}'),
        None => value,
    };
    filled(floor)
}

/// LICENSE's first line without the word `License`.
#[must_use]
pub fn license(license: &str) -> Option<String> {
    let first = license.lines().next()?;
    let words: Vec<&str> = first
        .split_whitespace()
        .filter(|word| *word != "License")
        .collect();
    filled(&words.join(" "))
}

/// `name` in `.claudinix.toml`'s `[cache]` table.
#[must_use]
pub fn cache_name(toml: &str) -> Option<String> {
    let table = toml
        .lines()
        .map(str::trim)
        .skip_while(|line| *line != "[cache]")
        .skip(1)
        .take_while(|line| !line.starts_with('['));
    table
        .filter_map(|line| line.strip_prefix("name"))
        .filter_map(|rest| rest.trim_start().strip_prefix('='))
        .find_map(|value| filled(value.trim().trim_matches('"')))
}

/// The README's maturity callout (`> **Alpha, <date>.**`), lowercased.
#[must_use]
pub fn status(readme: &str) -> Option<String> {
    const STAGES: [&str; 3] = ["Alpha", "Beta", "Preview"];
    readme.lines().find_map(|line| {
        let rest = line.strip_prefix("> **")?;
        STAGES
            .iter()
            .find(|stage| rest.starts_with(&format!("{stage},")))
            .map(|stage| stage.to_lowercase())
    })
}

/// `@test` lines in one bats file.
#[must_use]
pub fn bats_tests(bats: &str) -> usize {
    bats.lines()
        .filter(|line| line.trim_start().starts_with("@test "))
        .count()
}

/// Rows of the root spec's `§F` table plus the root itself; 0 without rows.
#[must_use]
pub fn spec_nodes(root_spec: &str) -> usize {
    let rows = root_spec
        .lines()
        .skip_while(|line| !line.starts_with("## §F"))
        .skip(1)
        .take_while(|line| !line.starts_with("## "))
        .filter(|line| line.contains('|'))
        .skip(1)
        .count();
    if rows == 0 { 0 } else { rows + 1 }
}

/// The count `pkl eval -x '<steps>.length'` prints; `None` for 0 or junk.
#[must_use]
pub fn step_count(pkl_out: &str) -> Option<usize> {
    pkl_out.trim().parse().ok().filter(|count| *count > 0)
}

#[cfg(test)]
mod tests;
