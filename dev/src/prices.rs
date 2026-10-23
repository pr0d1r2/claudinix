//! The price table in `docs/MODEL.md`, between `<!-- BEGIN prices ... -->`
//! and `<!-- END prices -->`, from the one `PRICES` array in
//! `scripts/burn.sh` (dev:T179, scripts:V61). The array is the list price
//! per model; the doc keeps no second copy.

use std::fmt::Write as _;

/// The block's name.
pub const NAME: &str = "prices";

/// One model's list price, in dollars per million tokens.
#[derive(Debug, Clone, PartialEq)]
pub struct Price {
    /// The model id prefix `burn.sh` matches, such as `claude-opus-5-5`.
    pub model: String,
    /// Dollars per million input tokens.
    pub input: f64,
    /// Dollars per million output tokens.
    pub output: f64,
}

/// Every row of the `PRICES=( ... )` array in `burn.sh`, in source order.
///
/// # Errors
///
/// When the script has no such array, it is empty, or a row is not
/// `"model input output"` with numbers (dev:V1).
pub fn parse(script: &str) -> Result<Vec<Price>, String> {
    let rows = script
        .lines()
        .skip_while(|line| line.trim_end() != "PRICES=(")
        .skip(1)
        .take_while(|line| line.trim() != ")")
        .filter(|line| !line.trim().is_empty() && !line.trim().starts_with('#'));
    let prices = rows.map(row).collect::<Result<Vec<_>, _>>()?;
    if prices.is_empty() {
        return Err("scripts/burn.sh has no `PRICES=(` rows; fix the source".to_owned());
    }
    Ok(prices)
}

/// One `"model input output"` row; a trailing `# note` and extra columns
/// are ignored.
fn row(line: &str) -> Result<Price, String> {
    let bad = || format!("scripts/burn.sh PRICES row {line:?} is not \"model input output\"");
    let quoted = line.trim().trim_start_matches('"');
    let fields: Vec<&str> = quoted
        .split(['"', '#'])
        .next()
        .unwrap_or_default()
        .split_whitespace()
        .collect();
    let [model, input, output, ..] = fields.as_slice() else {
        return Err(bad());
    };
    Ok(Price {
        model: (*model).to_owned(),
        input: input.parse().map_err(|_| bad())?,
        output: output.parse().map_err(|_| bad())?,
    })
}

/// A dated id's `20250929` part: digits too long to be a version number.
fn is_date(part: &str) -> bool {
    part.len() > 2 && part.chars().all(|c| c.is_ascii_digit())
}

/// A model id as the doc names it: `claude-opus-5-5` is `Claude Opus 5.5`.
#[must_use]
pub fn display(model: &str) -> String {
    let (words, version): (Vec<&str>, Vec<&str>) = model
        .split('-')
        .filter(|part| !is_date(part))
        .partition(|part| !part.chars().all(|c| c.is_ascii_digit()));
    let words: Vec<String> = words
        .iter()
        .map(|word| {
            let mut chars = word.chars();
            chars.next().map_or_else(String::new, |first| {
                first.to_uppercase().chain(chars).collect()
            })
        })
        .collect();
    let mut name = words.join(" ");
    if !version.is_empty() {
        name.push(' ');
        name.push_str(&version.join("."));
    }
    name
}

/// The table block, markers included, ending in a newline.
#[must_use]
pub fn table(prices: &[Price]) -> String {
    let mut out = format!(
        "<!-- BEGIN {NAME}: generated from scripts/burn.sh by `claudinix-dev prices --write`; do not edit -->\n\
         | model | input | output |\n\
         |---|---|---|\n"
    );
    for price in prices {
        let _ = writeln!(
            out,
            "| {} | ${:.2} | ${:.2} |",
            display(&price.model),
            price.input,
            price.output
        );
    }
    let _ = writeln!(out, "<!-- END {NAME} -->");
    out
}

#[cfg(test)]
mod tests;
