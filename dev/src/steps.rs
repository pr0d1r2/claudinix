//! The hk step table in `docs/INTEGRATION.md`, between
//! `<!-- BEGIN steps -->` and `<!-- END steps -->`, from the steps hk.pkl
//! gives each hook (dev:T106, dev:V1). One `pkl eval -x` prints every row;
//! the step counts the doc states in prose come from the same rows.

/// The block's name.
pub const NAME: &str = "steps";

/// A `pkl eval -x` expression printing one line per step of the
/// `pre-commit`, `check` and `commit-msg` hooks: hook, step, globs joined
/// by U+001F, check, fix; tab-separated. Text, so the crate needs no JSON
/// parser (dev:C30).
pub const ROWS: &str = r#"List("pre-commit", "check", "commit-msg").map((h) -> hooks[h].steps.toMap().entries.map((e) -> let (s = e.value) List(h, e.key, (if (s.glob is String) List(s.glob) else if (s.glob is List) s.glob else List()).join("\u{1F}"), (s.check ?? "").toString(), (s.fix ?? "").toString()).join("\t")).join("\n")).join("\n")"#;

/// When a step runs.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Layer {
    /// Every commit (`pre-commit`).
    Fast,
    /// Push and `hk check` only: in `check` but not in `pre-commit`.
    All,
    /// The commit message (`commit-msg`).
    CommitMsg,
}

/// One gate step.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Step {
    /// The step's key in hk.pkl.
    pub name: String,
    /// When it runs.
    pub layer: Layer,
    /// The files that trigger it; empty when hk.pkl names none.
    pub globs: Vec<String>,
    /// Its check command, as hk.pkl has it.
    pub check: String,
    /// Its fix command; empty when it has none.
    pub fix: String,
}

/// The steps `rows` (as [`ROWS`] prints them) describe, fast first, then
/// the push-only ones, then the commit-message ones, each in hk.pkl's
/// order.
///
/// # Errors
///
/// A malformed row, or a hook with no steps (dev:V1).
pub fn parse(rows: &str) -> Result<Vec<Step>, String> {
    let _ = rows;
    Err(String::new())
}

/// The `fast` and `all` step counts: `pre-commit` and `check`.
#[must_use]
pub fn counts(steps: &[Step]) -> (usize, usize) {
    let _ = steps;
    (0, 0)
}

/// A command as a human runs it inside the dev shell: without the
/// `scripts/hk/run-tool.sh` wrapper, `{{files}}` as `<files>` and
/// `{{workspace}}` as `<node>`.
#[must_use]
pub fn by_hand(command: &str) -> String {
    command.to_owned()
}

/// The table block, markers included.
#[must_use]
pub fn table(steps: &[Step]) -> String {
    let _ = steps;
    String::new()
}

#[cfg(test)]
mod tests;
