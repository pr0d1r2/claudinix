//! The key table in `docs/CONFIG.md`, between `<!-- BEGIN config -->` and
//! `<!-- END config -->`, from the one `schema` object in
//! `scripts/config.jq` (dev:T108, dev:V1, scripts:V34). The object is a
//! jq literal; the crate reads it with a small parser of its own, since it
//! takes no dependencies (dev:C30).

/// The block's name.
pub const NAME: &str = "config";

/// A jq literal value.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Value {
    /// `null`.
    Null,
    /// `true` or `false`.
    Bool(bool),
    /// A number, as written.
    Number(String),
    /// A string, escapes resolved.
    Text(String),
    /// `[...]`.
    List(Vec<Value>),
    /// `{...}`, in source order.
    Object(Vec<(String, Value)>),
}

/// One key of the file, as the schema describes it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Key {
    /// `table.key`.
    pub name: String,
    /// `string`, `boolean` or `strings`.
    pub kind: String,
    /// The only strings allowed; empty when any is.
    pub values: Vec<String>,
    /// The regex a string must match, if any.
    pub pattern: Option<String>,
    /// `hostname`, `cachix` or `shell`, if any.
    pub rule: Option<String>,
    /// The default, as a literal (`"sonnet"`, `false`, `[]`).
    pub default: String,
    /// The tools that read it.
    pub readers: String,
}

/// The value of the jq literal `text` starts with.
///
/// # Errors
///
/// Text that is not a jq literal (an interpolation, an expression).
pub fn parse(text: &str) -> Result<Value, String> {
    let _ = text;
    Err(String::new())
}

/// Every key `def schema: {...};` in `jq` (config.jq's source) lists, in
/// order.
///
/// # Errors
///
/// No `def schema:`, a literal that does not parse, a key without a
/// type, default or readers, or no keys at all (dev:V1).
pub fn schema(jq: &str) -> Result<Vec<Key>, String> {
    let _ = jq;
    Err(String::new())
}

/// The key table block, markers included, `version` first.
///
/// # Errors
///
/// A type or rule the table cannot describe: a new kind of key needs a
/// new sentence here, not a guess.
pub fn table(keys: &[Key]) -> Result<String, String> {
    let _ = keys;
    Err(String::new())
}

#[cfg(test)]
mod tests;
