//! The key table in `docs/CONFIG.md`, between `<!-- BEGIN config -->` and
//! `<!-- END config -->`, from the one `schema` object in
//! `scripts/config.jq` (dev:T108, dev:V1, scripts:V34). The object is a
//! jq literal; the crate reads it with a small parser of its own, since it
//! takes no dependencies (dev:C30).

use std::fmt::Write as _;

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
    Reader {
        chars: text.chars().collect(),
        at: 0,
    }
    .value()
}

/// A cursor over jq source.
struct Reader {
    chars: Vec<char>,
    at: usize,
}

impl Reader {
    fn peek(&self) -> Option<char> {
        self.chars.get(self.at).copied()
    }

    fn bump(&mut self) -> Option<char> {
        let next = self.peek();
        if next.is_some() {
            self.at += 1;
        }
        next
    }

    /// Past whitespace and `#` comments.
    fn skip(&mut self) {
        while let Some(next) = self.peek() {
            if next.is_whitespace() {
                self.at += 1;
            } else if next == '#' {
                while self.bump().is_some_and(|gone| gone != '\n') {}
            } else {
                break;
            }
        }
    }

    fn fail<T>(&self, what: &str) -> Result<T, String> {
        Err(format!("config.jq schema: {what} at character {}", self.at))
    }

    fn value(&mut self) -> Result<Value, String> {
        self.skip();
        match self.peek() {
            Some('{') => self.object(),
            Some('[') => self.list(),
            Some('"') => self.text().map(Value::Text),
            Some(next) if next == '-' || next.is_ascii_digit() => {
                let mut number = String::new();
                while let Some(digit) = self
                    .peek()
                    .filter(|c| c.is_ascii_digit() || matches!(c, '-' | '.' | 'e' | 'E' | '+'))
                {
                    number.push(digit);
                    self.at += 1;
                }
                Ok(Value::Number(number))
            }
            Some(next) if next.is_ascii_alphabetic() => match self.word().as_str() {
                "true" => Ok(Value::Bool(true)),
                "false" => Ok(Value::Bool(false)),
                "null" => Ok(Value::Null),
                word => self.fail(&format!("`{word}` is not a literal")),
            },
            _ => self.fail("not a jq literal"),
        }
    }

    /// An identifier: letters, digits and `_`.
    fn word(&mut self) -> String {
        let mut word = String::new();
        while let Some(next) = self
            .peek()
            .filter(|c| c.is_ascii_alphanumeric() || *c == '_')
        {
            word.push(next);
            self.at += 1;
        }
        word
    }

    fn text(&mut self) -> Result<String, String> {
        self.bump();
        let mut text = String::new();
        loop {
            match self.bump() {
                None => return self.fail("unterminated string"),
                Some('"') => return Ok(text),
                Some('\\') => match self.bump() {
                    Some('n') => text.push('\n'),
                    Some('t') => text.push('\t'),
                    Some(next @ ('"' | '\\' | '/')) => text.push(next),
                    Some('(') => return self.fail("string interpolation"),
                    _ => return self.fail("unknown escape"),
                },
                Some(next) => text.push(next),
            }
        }
    }

    fn list(&mut self) -> Result<Value, String> {
        self.bump();
        let mut items = Vec::new();
        self.skip();
        if self.peek() == Some(']') {
            self.bump();
            return Ok(Value::List(items));
        }
        loop {
            items.push(self.value()?);
            self.skip();
            match self.bump() {
                Some(',') => {}
                Some(']') => return Ok(Value::List(items)),
                _ => return self.fail("expected `,` or `]`"),
            }
        }
    }

    fn object(&mut self) -> Result<Value, String> {
        self.bump();
        let mut fields = Vec::new();
        self.skip();
        if self.peek() == Some('}') {
            self.bump();
            return Ok(Value::Object(fields));
        }
        loop {
            self.skip();
            let key = if self.peek() == Some('"') {
                self.text()?
            } else {
                self.word()
            };
            if key.is_empty() {
                return self.fail("expected a key");
            }
            self.skip();
            if self.bump() != Some(':') {
                return self.fail("expected `:`");
            }
            fields.push((key, self.value()?));
            self.skip();
            match self.bump() {
                Some(',') => {}
                Some('}') => return Ok(Value::Object(fields)),
                _ => return self.fail("expected `,` or `}`"),
            }
        }
    }
}

/// A value as a literal in the doc: `"x"`, `false`, `[]`.
fn literal(value: &Value) -> String {
    match value {
        Value::Null => "null".to_owned(),
        Value::Bool(flag) => flag.to_string(),
        Value::Number(number) => number.clone(),
        Value::Text(text) => format!("\"{}\"", text.replace('\\', "\\\\").replace('"', "\\\"")),
        Value::List(items) => {
            let items: Vec<String> = items.iter().map(literal).collect();
            format!("[{}]", items.join(", "))
        }
        Value::Object(fields) => {
            let fields: Vec<String> = fields
                .iter()
                .map(|(key, value)| format!("{key}: {}", literal(value)))
                .collect();
            format!("{{{}}}", fields.join(", "))
        }
    }
}

/// The fields of an object; nothing for anything else.
fn fields(value: &Value) -> &[(String, Value)] {
    match value {
        Value::Object(fields) => fields,
        _ => &[],
    }
}

/// Field `name` of `spec`.
fn field<'a>(spec: &'a [(String, Value)], name: &str) -> Option<&'a Value> {
    spec.iter()
        .find(|(key, _)| key == name)
        .map(|(_, value)| value)
}

/// Field `name` of `spec`, when it is a string.
fn text_field(spec: &[(String, Value)], name: &str) -> Option<String> {
    match field(spec, name)? {
        Value::Text(text) => Some(text.clone()),
        _ => None,
    }
}

/// One key from its spec object.
fn key(name: String, spec: &[(String, Value)]) -> Result<Key, String> {
    let missing = |what: &str| format!("config.jq schema key {name} has no {what}; fix the source");
    let kind = text_field(spec, "type").ok_or_else(|| missing("type"))?;
    let default = literal(field(spec, "default").ok_or_else(|| missing("default"))?);
    let readers = text_field(spec, "readers").ok_or_else(|| missing("readers"))?;
    let values = match field(spec, "values") {
        Some(Value::List(items)) => items
            .iter()
            .filter_map(|item| match item {
                Value::Text(text) => Some(text.clone()),
                _ => None,
            })
            .collect(),
        _ => Vec::new(),
    };
    Ok(Key {
        pattern: text_field(spec, "pattern"),
        rule: text_field(spec, "rule"),
        name,
        kind,
        values,
        default,
        readers,
    })
}

/// Every key `def schema: {...};` in `jq` (config.jq's source) lists, in
/// order.
///
/// # Errors
///
/// No `def schema:`, a literal that does not parse, a key without a
/// type, default or readers, or no keys at all (dev:V1).
pub fn schema(jq: &str) -> Result<Vec<Key>, String> {
    const DEF: &str = "def schema:";
    let at = jq
        .find(DEF)
        .ok_or_else(|| "config.jq has no `def schema:`; fix the source".to_owned())?;
    let tables = parse(jq.get(at + DEF.len()..).unwrap_or_default())?;
    let mut keys = Vec::new();
    for (table, specs) in fields(&tables) {
        for (name, spec) in fields(specs) {
            keys.push(key(format!("{table}.{name}"), fields(spec))?);
        }
    }
    if keys.is_empty() {
        return Err("config.jq schema lists no keys; fix the source".to_owned());
    }
    Ok(keys)
}

/// The key table block, markers included, `version` first.
///
/// # Errors
///
/// A type or rule the table cannot describe: a new kind of key needs a
/// new sentence here, not a guess.
pub fn table(keys: &[Key]) -> Result<String, String> {
    let mut out = format!(
        "<!-- BEGIN {NAME}: generated from scripts/config.jq by `claudinix-dev config --write`; do not edit -->\n\
         | key | type | default | read by |\n\
         |---|---|---|---|\n\
         | `version` | the number `1` | none; required in a file | every reader (the file is refused without it) |\n"
    );
    for key in keys {
        let _ = writeln!(
            out,
            "| `{}` | {} | `{}` | {} |",
            key.name,
            kind_cell(key)?,
            key.default,
            key.readers.replace('|', "\\|"),
        );
    }
    Ok(out + "<!-- END " + NAME + " -->\n")
}

/// A key's type and rule in words.
fn kind_cell(key: &Key) -> Result<String, String> {
    if !key.values.is_empty() {
        let values: Vec<String> = key.values.iter().map(|v| format!("`\"{v}\"`")).collect();
        return Ok(values.join(" or "));
    }
    let words = match (
        key.kind.as_str(),
        key.rule.as_deref(),
        key.pattern.as_deref(),
    ) {
        ("boolean", None, None) => "`true` or `false`".to_owned(),
        ("string", None, None) => "string".to_owned(),
        ("string", Some("shell"), None) => {
            "string, no whitespace, quote, backtick or control character".to_owned()
        }
        ("string", Some("cachix"), Some(pattern)) => format!("string matching `{pattern}`"),
        ("strings", None, None) => "list of strings".to_owned(),
        ("strings", Some("hostname"), None) => "list of bare hostnames".to_owned(),
        _ => {
            return Err(format!(
                "config.jq schema key {} has a type or rule the CONFIG.md table cannot describe; teach dev/src/config.rs",
                key.name
            ));
        }
    };
    Ok(words)
}

#[cfg(test)]
mod tests;
