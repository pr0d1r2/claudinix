//! The price table in `docs/MODEL.md`, between `<!-- BEGIN prices ... -->`
//! and `<!-- END prices -->`, from the one `PRICES` array in
//! `scripts/burn.sh` (dev:T179, scripts:V61). The array is the list price
//! per model; the doc keeps no second copy.

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
pub fn parse(_script: &str) -> Result<Vec<Price>, String> {
    Err(String::new())
}

/// A model id as the doc names it: `claude-opus-5-5` is `Claude Opus 5.5`.
#[must_use]
pub fn display(_model: &str) -> String {
    String::new()
}

/// The table block, markers included, ending in a newline.
#[must_use]
pub fn table(_prices: &[Price]) -> String {
    String::new()
}

#[cfg(test)]
mod tests;
