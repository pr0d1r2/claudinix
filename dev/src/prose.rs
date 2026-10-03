//! Numbers README.md and docs/LLM-DISCLAIMER.md state in prose, outside
//! the generated badge block, held to the files that own them (dev:V1).
//! Only a number with an owner is a claim; a dated measurement (seconds,
//! sizes, versions seen in a session) belongs to docs/FACTS.md's dated
//! rows and is not checked here.

use std::collections::BTreeSet;

use crate::splice;

/// The value of every owned number.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Owners {
    /// Steps in hk.pkl's `pre-commit` hook.
    pub fast: usize,
    /// Steps in hk.pkl's `check` hook.
    pub all: usize,
    /// `@test` lines under `tests/unit`.
    pub tests: usize,
    /// Spec nodes: root `§F` rows plus the root.
    pub nodes: usize,
    /// Distinct probe numbers docs/FACTS.md's tables cite.
    pub probes: usize,
    /// setup.sh `min_version`.
    pub nix_floor: String,
    /// setup.sh `version=`, the Nix it installs.
    pub nix_pinned: String,
}

/// One number the prose states.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Claim {
    /// The phrase, as the doc says it (whitespace collapsed).
    pub said: String,
    /// The number in it.
    pub stated: String,
    /// What it should say, spelled the way the doc spells it.
    pub want: String,
    /// What the owner holds, in digits.
    pub value: String,
    /// The file that owns it.
    pub owner: &'static str,
}

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

/// The number a word or digits spell.
fn number(text: &str) -> Option<usize> {
    let text = text.to_ascii_lowercase();
    WORDS
        .iter()
        .position(|word| *word == text)
        .or_else(|| text.parse().ok())
}

/// `count` spelled as `like` is: digits for digits, else a word up to
/// twenty.
fn spelled_like(like: &str, count: usize) -> String {
    if like.parse::<usize>().is_ok() {
        return count.to_string();
    }
    WORDS
        .get(count)
        .map_or_else(|| count.to_string(), |word| (*word).to_owned())
}

/// A version as prose writes one: digits and dots, starting with a digit.
fn version(text: &str) -> bool {
    text.starts_with(|c: char| c.is_ascii_digit())
        && text.chars().all(|c| c.is_ascii_digit() || c == '.')
}

/// A word without the punctuation and markup around it.
fn clean(word: &str) -> &str {
    word.trim_matches(|c: char| matches!(c, '.' | ',' | ';' | ':' | '(' | ')' | '`' | '*' | '"'))
}

/// What an owner holds.
enum Value {
    Count(usize),
    Version(String),
}

/// A phrase whose number an owner holds: the number comes right before
/// the words, or right after them.
struct Rule {
    words: &'static [&'static str],
    before: bool,
    owner: &'static str,
    value: Value,
}

fn rules(owners: &Owners) -> Vec<Rule> {
    let count = |words, owner, value| Rule {
        words,
        before: true,
        owner,
        value: Value::Count(value),
    };
    let after = |words, owner, value: &str| Rule {
        words,
        before: false,
        owner,
        value: Value::Version(value.to_owned()),
    };
    let floor = "setup.sh `min_version`";
    let nodes = "SPEC.md §F rows plus the root";
    vec![
        count(
            &["probe", "sessions"],
            "docs/FACTS.md distinct probes",
            owners.probes,
        ),
        count(
            &["steps", "on", "every", "commit"],
            "hk.pkl pre-commit steps",
            owners.fast,
        ),
        count(
            &["steps", "on", "every", "push"],
            "hk.pkl check steps",
            owners.all,
        ),
        count(&["bats", "tests"], "tests/unit `@test` lines", owners.tests),
        count(&["federated", "nodes"], nodes, owners.nodes),
        count(&["spec", "nodes"], nodes, owners.nodes),
        after(
            &["installs", "the", "pinned"],
            "setup.sh `version=`",
            &owners.nix_pinned,
        ),
        after(&["floor", "of"], floor, &owners.nix_floor),
        after(&["Nix", "is", "older", "than"], floor, &owners.nix_floor),
    ]
}

/// `words` from `at` are `want`, case aside.
fn says(words: &[&str], at: usize, want: &[&str]) -> bool {
    want.iter().enumerate().all(|(offset, word)| {
        words
            .get(at + offset)
            .is_some_and(|have| clean(have).eq_ignore_ascii_case(word))
    })
}

/// The claim `rule` makes at word `at`, if it makes one there.
fn claim_at(words: &[&str], at: usize, rule: &Rule) -> Option<Claim> {
    let (phrase_at, number_at) = if rule.before {
        (at + 1, at)
    } else {
        (at, at + rule.words.len())
    };
    if !says(words, phrase_at, rule.words) {
        return None;
    }
    let stated = clean(words.get(number_at)?);
    let (want, value) = match &rule.value {
        Value::Count(count) => {
            number(stated)?;
            (spelled_like(stated, *count), count.to_string())
        }
        Value::Version(text) => {
            if !version(stated) {
                return None;
            }
            (text.clone(), text.clone())
        }
    };
    let span = words.get(at..at + rule.words.len() + 1)?;
    let said: Vec<&str> = span.iter().map(|word| clean(word)).collect();
    Some(Claim {
        said: said.join(" "),
        stated: stated.to_owned(),
        want,
        value,
        owner: rule.owner,
    })
}

/// Every claim `doc` makes, in order.
#[must_use]
pub fn claims(doc: &str, owners: &Owners) -> Vec<Claim> {
    let prose =
        splice::current(doc).map_or_else(|| doc.to_owned(), |block| doc.replacen(block, "", 1));
    let words: Vec<&str> = prose.split_whitespace().collect();
    let rules = rules(owners);
    (0..words.len())
        .flat_map(|at| {
            rules
                .iter()
                .filter_map(|rule| claim_at(&words, at, rule))
                .collect::<Vec<_>>()
        })
        .collect()
}

/// One line per stale claim in `file`; empty when all match.
#[must_use]
pub fn drift(file: &str, claims: &[Claim]) -> Vec<String> {
    claims
        .iter()
        .filter(|claim| !claim.stated.eq_ignore_ascii_case(&claim.want))
        .map(|claim| {
            let Claim {
                said,
                want,
                value,
                owner,
                ..
            } = claim;
            format!("{file}: \"{said}\"; {owner} is {value}: say {want}")
        })
        .collect()
}

/// Distinct probe numbers cited in docs/FACTS.md's table rows (`probe 1`,
/// `probes 1-3`, `probes 5, 7`); 0 when none.
#[must_use]
pub fn probes(facts_md: &str) -> usize {
    let mut seen = BTreeSet::new();
    for line in facts_md.lines().filter(|line| line.starts_with('|')) {
        let words: Vec<&str> = line.split_whitespace().collect();
        for (at, word) in words.iter().enumerate() {
            if matches!(clean(word), "probe" | "probes") {
                cited(words.get(at + 1..).unwrap_or_default(), &mut seen);
            }
        }
    }
    seen.len()
}

/// The numbers and ranges at the start of `words`, into `seen`.
fn cited(words: &[&str], seen: &mut BTreeSet<usize>) {
    for word in words {
        let word = clean(word);
        if let Ok(single) = word.parse::<usize>() {
            seen.insert(single);
            continue;
        }
        let range = word
            .split_once('-')
            .and_then(|(from, to)| Some((from.parse::<usize>().ok()?, to.parse::<usize>().ok()?)));
        let Some((from, to)) = range else {
            return;
        };
        seen.extend(from..=to);
    }
}

/// setup.sh's top-level `version=`, the Nix it installs below the floor.
#[must_use]
pub fn nix_pinned(setup_sh: &str) -> Option<String> {
    let value = setup_sh
        .lines()
        .find_map(|line| line.strip_prefix("version="))?
        .trim()
        .trim_matches('"');
    (!value.is_empty()).then(|| value.to_owned())
}

#[cfg(test)]
mod tests;
