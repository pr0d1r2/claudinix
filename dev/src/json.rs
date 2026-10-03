//! A small JSON reader, enough for `flake.lock` (std only, dev:C30): every
//! JSON value parses, numbers stay as their text, and nothing is written.

/// One JSON value. Object members keep their order.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Json {
    /// `null`.
    Null,
    /// `true` or `false`.
    Bool(bool),
    /// A number, as written.
    Num(String),
    /// A string, unescaped.
    Str(String),
    /// An array.
    Arr(Vec<Json>),
    /// An object.
    Obj(Vec<(String, Json)>),
}

impl Json {
    /// The member `key` of an object; `None` for a missing key or a
    /// value that is not an object.
    #[must_use]
    pub fn get(&self, _key: &str) -> Option<&Json> {
        None
    }

    /// The text of a string value.
    #[must_use]
    pub fn as_str(&self) -> Option<&str> {
        None
    }

    /// The members of an object, in order; empty for any other value.
    #[must_use]
    pub fn members(&self) -> &[(String, Json)] {
        &[]
    }
}

/// The value `text` holds, or `None` unless all of it is one JSON value.
#[must_use]
pub fn parse(_text: &str) -> Option<Json> {
    None
}

#[cfg(test)]
mod tests;
