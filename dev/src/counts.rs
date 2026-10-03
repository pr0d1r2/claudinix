//! The gate step counts `docs/INTEGRATION.md` states in its caller table
//! (`` `fast`, N steps `` and `` `all`, N steps ``) and in prose
//! (`` `all` is `fast` plus <word> steps ``), against hk.pkl's.

const FAST: &str = "`fast`, ";
const ALL: &str = "`all`, ";
const PLUS: &str = "`all` is `fast` plus ";
const WORDS: [&str; 21] = [
    "zero",
    "one",
    "two",
    "three",
    "four",
    "five",
    "six",
    "seven",
    "eight",
    "nine",
    "ten",
    "eleven",
    "twelve",
    "thirteen",
    "fourteen",
    "fifteen",
    "sixteen",
    "seventeen",
    "eighteen",
    "nineteen",
    "twenty",
];

/// A count as the prose spells it: a word up to twenty, digits after.
fn spelled(count: usize) -> String {
    WORDS
        .get(count)
        .map_or_else(|| count.to_string(), |word| (*word).to_owned())
}

/// The number a word or digits spell.
fn number(text: &str) -> Option<usize> {
    WORDS
        .iter()
        .position(|word| *word == text)
        .or_else(|| text.parse().ok())
}

/// One stated count: where its value sits in the line, what it says, and
/// what hk.pkl says it should be.
struct Stated {
    start: usize,
    end: usize,
    text: String,
    want: String,
    phrase: &'static str,
}

/// Every count `line` states after `prefix` and before ` steps`.
fn stated(line: &str, prefix: &'static str, want: &str) -> Vec<Stated> {
    line.match_indices(prefix)
        .filter_map(|(at, _)| {
            let start = at + prefix.len();
            let rest = line.get(start..)?;
            let len = rest.find(" steps")?;
            let text = rest.get(..len)?;
            (!text.is_empty() && number(text).is_some()).then(|| Stated {
                start,
                end: start + len,
                text: text.to_owned(),
                want: want.to_owned(),
                phrase: prefix,
            })
        })
        .collect()
}

/// Every count in `line`, ordered by position.
fn line_counts(line: &str, fast: usize, all: usize) -> Vec<Stated> {
    let extra = spelled(all.saturating_sub(fast));
    let mut found: Vec<Stated> = [
        stated(line, FAST, &fast.to_string()),
        stated(line, ALL, &all.to_string()),
        stated(line, PLUS, &extra),
    ]
    .into_iter()
    .flatten()
    .collect();
    found.sort_by_key(|count| count.start);
    found
}

/// The stale statements, one line each; empty when every count matches.
///
/// # Errors
///
/// When the doc states no count for `fast` or for `all` (dev:V1): a check
/// that finds nothing to check is not a pass.
pub fn drift(doc: &str, fast: usize, all: usize) -> Result<Vec<String>, String> {
    let counts: Vec<(usize, Stated)> = doc
        .lines()
        .enumerate()
        .flat_map(|(at, line)| {
            line_counts(line, fast, all)
                .into_iter()
                .map(move |count| (at + 1, count))
        })
        .collect();
    for phrase in [FAST, ALL] {
        if !counts.iter().any(|(_, count)| count.phrase == phrase) {
            let layer = phrase.trim_end_matches(", ");
            return Err(format!(
                "docs/INTEGRATION.md states no {layer} step count (\"{layer}, N steps\")"
            ));
        }
    }
    Ok(counts
        .iter()
        .filter(|(_, count)| count.text != count.want)
        .map(|(line, count)| {
            let Stated {
                phrase, text, want, ..
            } = count;
            format!("line {line}: {phrase}{text} steps; hk.pkl has {want}")
        })
        .collect())
}

/// `line` with every stated count set to hk.pkl's.
fn rewrite_line(line: &str, fast: usize, all: usize) -> String {
    let mut out = String::new();
    let mut from = 0;
    for count in line_counts(line, fast, all) {
        out.push_str(line.get(from..count.start).unwrap_or_default());
        out.push_str(&count.want);
        from = count.end;
    }
    out.push_str(line.get(from..).unwrap_or_default());
    out
}

/// `doc` with every stated count set to hk.pkl's.
#[must_use]
pub fn rewrite(doc: &str, fast: usize, all: usize) -> String {
    doc.split_inclusive('\n')
        .map(|line| rewrite_line(line, fast, all))
        .collect()
}

#[cfg(test)]
mod tests;
