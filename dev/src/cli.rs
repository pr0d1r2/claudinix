//! The `usage:` lines `docs/CLI.md` quotes, against the usage text each
//! script prints (dev:T107, dev:V1): a page that shows a flag the script
//! lacks, or misses one it has, is drift.

/// The usage strings `source` (a shell script) prints: every
/// `usage: ...` inside a `"..."` or `'...'` string or a `${1:?usage: ...}`
/// expansion, outside comments. A script that prints none (it parses its
/// arguments by hand) falls back to its `# Usage:` header line.
#[must_use]
pub fn script_usages(source: &str) -> Vec<String> {
    let _ = source;
    Vec::new()
}

/// Every line inside a fenced code block of `doc` that starts with
/// `usage: `, with its 1-based line number.
#[must_use]
pub fn doc_usages(doc: &str) -> Vec<(usize, String)> {
    let _ = doc;
    Vec::new()
}

/// One line per `usage:` line in `doc` that no script's usage matches,
/// naming the doc line and the script; empty when all match. `scripts`
/// pairs each script's path with its source; a usage line names its
/// script by its first word, with or without `.sh`.
///
/// # Errors
///
/// When `doc` quotes no usage line at all (dev:V1).
pub fn drift(doc: &str, scripts: &[(&str, &str)]) -> Result<Vec<String>, String> {
    let _ = (doc, scripts);
    Err(String::new())
}

#[cfg(test)]
mod tests;
