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
    pub fn get(&self, key: &str) -> Option<&Json> {
        self.members()
            .iter()
            .find(|(name, _)| name == key)
            .map(|(_, value)| value)
    }

    /// The text of a string value.
    #[must_use]
    pub fn as_str(&self) -> Option<&str> {
        match self {
            Json::Str(text) => Some(text),
            _ => None,
        }
    }

    /// The members of an object, in order; empty for any other value.
    #[must_use]
    pub fn members(&self) -> &[(String, Json)] {
        match self {
            Json::Obj(members) => members,
            _ => &[],
        }
    }
}

/// The value `text` holds, or `None` unless all of it is one JSON value.
#[must_use]
pub fn parse(text: &str) -> Option<Json> {
    let mut reader = Reader { text, at: 0 };
    let value = reader.value()?;
    reader.blank();
    (reader.at == text.len()).then_some(value)
}

/// A cursor over the text.
struct Reader<'text> {
    text: &'text str,
    at: usize,
}

impl Reader<'_> {
    fn rest(&self) -> &str {
        self.text.get(self.at..).unwrap_or_default()
    }

    fn peek(&self) -> Option<char> {
        self.rest().chars().next()
    }

    fn next(&mut self) -> Option<char> {
        let found = self.peek()?;
        self.at += found.len_utf8();
        Some(found)
    }

    fn blank(&mut self) {
        while self
            .peek()
            .is_some_and(|c| matches!(c, ' ' | '\t' | '\n' | '\r'))
        {
            self.at += 1;
        }
    }

    /// Skip blanks, then take `want` if it comes next.
    fn eat(&mut self, want: char) -> bool {
        self.blank();
        let found = self.peek() == Some(want);
        if found {
            self.at += want.len_utf8();
        }
        found
    }

    fn word(&mut self, word: &str, value: Json) -> Option<Json> {
        self.rest().starts_with(word).then(|| {
            self.at += word.len();
            value
        })
    }

    fn value(&mut self) -> Option<Json> {
        self.blank();
        match self.peek()? {
            '{' => self.object(),
            '[' => self.array(),
            '"' => self.string().map(Json::Str),
            't' => self.word("true", Json::Bool(true)),
            'f' => self.word("false", Json::Bool(false)),
            'n' => self.word("null", Json::Null),
            _ => self.number(),
        }
    }

    /// The members after `{`, or `}` at once.
    fn object(&mut self) -> Option<Json> {
        self.at += 1;
        let mut members = Vec::new();
        if self.eat('}') {
            return Some(Json::Obj(members));
        }
        loop {
            self.blank();
            let key = self.string()?;
            if !self.eat(':') {
                return None;
            }
            members.push((key, self.value()?));
            if self.eat('}') {
                return Some(Json::Obj(members));
            }
            if !self.eat(',') {
                return None;
            }
        }
    }

    /// The items after `[`, or `]` at once.
    fn array(&mut self) -> Option<Json> {
        self.at += 1;
        let mut items = Vec::new();
        if self.eat(']') {
            return Some(Json::Arr(items));
        }
        loop {
            items.push(self.value()?);
            if self.eat(']') {
                return Some(Json::Arr(items));
            }
            if !self.eat(',') {
                return None;
            }
        }
    }

    /// A quoted string, unescaped.
    fn string(&mut self) -> Option<String> {
        if self.next()? != '"' {
            return None;
        }
        let mut out = String::new();
        loop {
            match self.next()? {
                '"' => return Some(out),
                '\\' => out.push(self.escape()?),
                c if u32::from(c) < 0x20 => return None,
                c => out.push(c),
            }
        }
    }

    /// The character after a backslash.
    fn escape(&mut self) -> Option<char> {
        Some(match self.next()? {
            '"' => '"',
            '\\' => '\\',
            '/' => '/',
            'b' => '\u{8}',
            'f' => '\u{c}',
            'n' => '\n',
            'r' => '\r',
            't' => '\t',
            'u' => return self.unicode(),
            _ => return None,
        })
    }

    /// `\uXXXX`, joining a surrogate pair into one character.
    fn unicode(&mut self) -> Option<char> {
        let high = self.hex()?;
        if !(0xD800..0xDC00).contains(&high) {
            return char::from_u32(high);
        }
        if !self.rest().starts_with("\\u") {
            return None;
        }
        self.at += 2;
        let low = self.hex()?;
        if !(0xDC00..0xE000).contains(&low) {
            return None;
        }
        char::from_u32(0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00))
    }

    fn hex(&mut self) -> Option<u32> {
        let digits = self.rest().get(..4)?;
        let value = u32::from_str_radix(digits, 16).ok()?;
        self.at += 4;
        Some(value)
    }

    /// `-? int frac? exp?`, as JSON spells numbers.
    fn number(&mut self) -> Option<Json> {
        let start = self.at;
        if self.peek() == Some('-') {
            self.at += 1;
        }
        let int = self.digits();
        if int == 0 || (int > 1 && self.text.get(self.at - int..)?.starts_with('0')) {
            return None;
        }
        if self.peek() == Some('.') {
            self.at += 1;
            if self.digits() == 0 {
                return None;
            }
        }
        if matches!(self.peek(), Some('e' | 'E')) {
            self.at += 1;
            if matches!(self.peek(), Some('+' | '-')) {
                self.at += 1;
            }
            if self.digits() == 0 {
                return None;
            }
        }
        Some(Json::Num(self.text.get(start..self.at)?.to_owned()))
    }

    /// Skip ASCII digits; how many.
    fn digits(&mut self) -> usize {
        let count = self.rest().bytes().take_while(u8::is_ascii_digit).count();
        self.at += count;
        count
    }
}

#[cfg(test)]
mod tests;
