//! The README badge block, rendered from facts that each come from the
//! file that owns them (dev:V1).

/// Everything the badges say.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Facts {
    /// `owner/repo`, from setup.sh's fork block.
    pub slug: String,
    /// The CI workflow's file name under `.github/workflows`.
    pub workflow: String,
    /// LICENSE's first line, without `License`.
    pub license: String,
    /// The README's maturity callout, if it has one.
    pub status: Option<String>,
    /// The binary cache host, from `.claudinix.toml`'s `cache.name`.
    pub cache: String,
    /// setup.sh's `min_version`.
    pub nix_floor: String,
    /// Steps in hk.pkl's `pre-commit` and `check` hooks.
    pub steps: (usize, usize),
    /// `@test` lines under `tests/unit`.
    pub tests: usize,
    /// Spec nodes: root `§F` rows plus the root.
    pub nodes: usize,
}

impl Facts {
    /// Refuse a fact that reads empty or zero (dev:V1): a badge is not
    /// worth a guessed number.
    ///
    /// # Errors
    ///
    /// The first empty or zero fact, naming the file it comes from.
    pub fn checked(self) -> Result<Self, String> {
        let empty = [
            ("setup.sh fork block `repo=`", self.slug.is_empty()),
            (".github/workflows CI file", self.workflow.is_empty()),
            ("LICENSE first line", self.license.is_empty()),
            (".claudinix.toml `cache.name`", self.cache.is_empty()),
            ("setup.sh `min_version`", self.nix_floor.is_empty()),
            ("hk.pkl step count", self.steps.0 == 0 || self.steps.1 == 0),
            ("tests/unit `@test` lines", self.tests == 0),
            ("SPEC.md §F rows", self.nodes == 0),
        ];
        match empty.iter().find(|(_, is)| *is) {
            Some((what, _)) => Err(format!("{what} read empty or zero; fix the source")),
            None => Ok(self),
        }
    }

    /// The template's facts, by name.
    fn values(&self) -> [(&'static str, String); 8] {
        let (fast, all) = self.steps;
        [
            ("slug", self.slug.clone()),
            ("workflow", self.workflow.clone()),
            ("license", self.license.clone()),
            ("cache", self.cache.clone()),
            ("nix", self.nix_floor.clone()),
            ("steps", format!("{fast} commit / {all} push")),
            ("tests", self.tests.to_string()),
            ("nodes", self.nodes.to_string()),
        ]
    }
}

/// The block. `{name}` is a fact as written, `{name|url}` the same fact
/// escaped for a shields.io path, so a badge's alt text and its URL come
/// from one value and cannot disagree (dev:V2). `{status}` is a line of
/// its own, dropped when the README has no maturity callout. The credits
/// stay literal: they name how the repository is built, not a number.
const TEMPLATE: &str = "<!-- BEGIN badges -->
[![CI](https://github.com/{slug}/actions/workflows/{workflow}/badge.svg)](https://github.com/{slug}/actions/workflows/{workflow})
[![License: {license}](https://img.shields.io/badge/license-{license|url}-blue.svg)](LICENSE)
{status}
[![nix flake](https://img.shields.io/badge/nix-flake-5277C3?logo=nixos&logoColor=white)](flake.nix)
[![Nix ≥ {nix}](https://img.shields.io/badge/Nix-%E2%89%A5{nix|url}-5277C3?logo=nixos&logoColor=white)](setup.sh)
[![cache {cache}](https://img.shields.io/badge/cache-{cache|url}-5277C3?logo=nixos&logoColor=white)](https://{cache})

[![gate hk](https://img.shields.io/badge/gate-hk-6E4AFF)](hk.pkl)
[![gate steps {steps}](https://img.shields.io/badge/gate_steps-{steps|url}-6E4AFF)](hk.pkl)
[![bats tests {tests}](https://img.shields.io/badge/bats_tests-{tests|url}-brightgreen)](tests/unit)
[![federated nodes {nodes}](https://img.shields.io/badge/federated_nodes-{nodes|url}-6E4AFF)](SPEC.md)

[![built with Claude Code](https://img.shields.io/badge/built_with-Claude_Code-D97757)](https://claude.com/claude-code)
[![built with SDD](https://img.shields.io/badge/built_with-spec--driven_development-D97757)](SPEC.md)
<!-- END badges -->
";

/// The status badge and the blank line after it, or the blank line alone.
fn status_lines(status: Option<&str>) -> String {
    status.map_or_else(
        || "\n".to_owned(),
        |value| {
            let url = esc(value);
            format!(
                "[![status {value}](https://img.shields.io/badge/status-{url}-orange)](docs/FACTS.md)\n\n"
            )
        },
    )
}

/// shields.io path text: `-` doubles, a space is `_`, and `%`, `+`, `/`
/// are percent-encoded.
#[must_use]
pub fn esc(text: &str) -> String {
    text.replace('-', "--")
        .replace('%', "%25")
        .replace('+', "%2B")
        .replace('/', "%2F")
        .replace(' ', "_")
}

/// The block, markers included, ending in a newline.
#[must_use]
pub fn render(facts: &Facts) -> String {
    let filled = facts
        .values()
        .into_iter()
        .fold(TEMPLATE.to_owned(), |text, (name, value)| {
            text.replace(&format!("{{{name}|url}}"), &esc(&value))
                .replace(&format!("{{{name}}}"), &value)
        });
    filled.replace("{status}\n", &status_lines(facts.status.as_deref()))
}

#[cfg(test)]
mod tests;
