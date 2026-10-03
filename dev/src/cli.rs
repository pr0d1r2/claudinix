//! The `usage:` lines `docs/CLI.md` quotes, against the usage text each
//! script prints (dev:T107, dev:V1): a page that shows a flag the script
//! lacks, or misses one it has, is drift.

/// What every usage line starts with.
const USAGE: &str = "usage: ";

/// The usage strings `source` (a shell script) prints: every
/// `usage: ...` inside a `"..."` or `'...'` string or a `${1:?usage: ...}`
/// expansion, outside comments. A script that prints none (it parses its
/// arguments by hand) falls back to its `# Usage:` header line.
#[must_use]
pub fn script_usages(source: &str) -> Vec<String> {
    let printed: Vec<String> = source
        .lines()
        .filter(|line| !line.trim_start().starts_with('#'))
        .flat_map(printed_in)
        .collect();
    if !printed.is_empty() {
        return printed;
    }
    source
        .lines()
        .find_map(|line| line.trim().strip_prefix("# Usage: "))
        .map(|rest| vec![format!("usage: {}", rest.trim_end())])
        .unwrap_or_default()
}

/// The usage strings one source line prints.
fn printed_in(line: &str) -> Vec<String> {
    line.match_indices(USAGE)
        .filter_map(|(at, _)| {
            let close = match line.get(..at)?.chars().next_back()? {
                '"' => '"',
                '\'' => '\'',
                '?' => '}',
                _ => return None,
            };
            let rest = line.get(at..)?;
            Some(rest.get(..rest.find(close)?)?.to_owned())
        })
        .collect()
}

/// Every line inside a fenced code block of `doc` that starts with
/// `usage: `, with its 1-based line number.
#[must_use]
pub fn doc_usages(doc: &str) -> Vec<(usize, String)> {
    let mut fenced = false;
    let mut found = Vec::new();
    for (at, line) in doc.lines().enumerate() {
        if line.trim_start().starts_with("```") {
            fenced = !fenced;
        } else if fenced && line.starts_with(USAGE) {
            found.push((at + 1, line.to_owned()));
        }
    }
    found
}

/// The script a usage line names: its file name is the line's first word,
/// with or without `.sh`.
fn named<'a>(quote: &str, scripts: &'a [(&'a str, &'a str)]) -> Option<(&'a str, &'a str)> {
    let name = quote.strip_prefix(USAGE)?.split_whitespace().next()?;
    scripts.iter().copied().find(|(path, _)| {
        let file = path.rsplit('/').next().unwrap_or(path);
        file == name || file.strip_suffix(".sh") == Some(name)
    })
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
    let quotes = doc_usages(doc);
    if quotes.is_empty() {
        return Err("docs/CLI.md quotes no `usage:` line in a code block".to_owned());
    }
    Ok(quotes
        .iter()
        .filter_map(|(line, quote)| {
            let head = format!("docs/CLI.md line {line}: `{quote}`");
            let Some((path, source)) = named(quote, scripts) else {
                let name = quote
                    .strip_prefix(USAGE)
                    .and_then(|rest| rest.split_whitespace().next())
                    .unwrap_or_default();
                return Some(format!(
                    "{head}; no script {name} in scripts/*.sh or setup.sh"
                ));
            };
            let usages = script_usages(source);
            if usages.iter().any(|usage| usage == quote) {
                return None;
            }
            Some(match usages.as_slice() {
                [] => format!("{head}; {path} prints no usage text"),
                _ => format!("{head}; {path} says `{}`", usages.join("` or `")),
            })
        })
        .collect())
}

#[cfg(test)]
mod tests;
