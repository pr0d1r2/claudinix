//! The hk step table in `docs/INTEGRATION.md`, between
//! `<!-- BEGIN steps -->` and `<!-- END steps -->`, from the steps hk.pkl
//! gives each hook (dev:T106, dev:V1). One `pkl eval -x` prints every row;
//! the step counts the doc states in prose come from the same rows.

use std::fmt::Write as _;

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
    let mut fast: Vec<Step> = Vec::new();
    let mut check: Vec<Step> = Vec::new();
    let mut message: Vec<Step> = Vec::new();
    for line in rows.lines().filter(|line| !line.is_empty()) {
        let cells: Vec<&str> = line.split('\t').collect();
        let [hook, name, globs, command, fix] = cells.as_slice() else {
            return Err(format!(
                "hk.pkl step row is not hook, step, globs, check, fix: {line}"
            ));
        };
        let (into, layer) = match *hook {
            "pre-commit" => (&mut fast, Layer::Fast),
            "check" => (&mut check, Layer::All),
            "commit-msg" => (&mut message, Layer::CommitMsg),
            other => return Err(format!("hk.pkl step row names an unknown hook {other}")),
        };
        into.push(Step {
            name: (*name).to_owned(),
            layer,
            globs: globs
                .split('\u{1F}')
                .filter(|glob| !glob.is_empty())
                .map(str::to_owned)
                .collect(),
            check: (*command).to_owned(),
            fix: (*fix).to_owned(),
        });
    }
    for (hook, steps) in [
        ("pre-commit", &fast),
        ("check", &check),
        ("commit-msg", &message),
    ] {
        if steps.is_empty() {
            return Err(format!("hk.pkl hook {hook} read no steps; fix the source"));
        }
    }
    let push: Vec<Step> = check
        .into_iter()
        .filter(|step| !fast.iter().any(|other| other.name == step.name))
        .collect();
    let mut steps = fast;
    steps.extend(push);
    steps.extend(message);
    Ok(steps)
}

/// The `fast` and `all` step counts: `pre-commit`, and `check`, which
/// is every fast step plus the push-only ones (`all` amends `fast`).
#[must_use]
pub fn counts(steps: &[Step]) -> (usize, usize) {
    let of = |layer| steps.iter().filter(|step| step.layer == layer).count();
    let fast = of(Layer::Fast);
    (fast, fast + of(Layer::All))
}

/// A command as a human runs it inside the dev shell: without the
/// `scripts/hk/run-tool.sh` wrapper, `{{files}}` as `<files>` and
/// `{{workspace}}` as `<node>`.
#[must_use]
pub fn by_hand(command: &str) -> String {
    command
        .strip_prefix("scripts/hk/run-tool.sh ")
        .unwrap_or(command)
        .replace("{{files}}", "<files>")
        .replace("{{workspace}}", "<node>")
}

/// A command as a table cell: a code span, its pipes escaped; `-` when
/// there is none.
fn command_cell(command: &str) -> String {
    if command.is_empty() {
        return "-".to_owned();
    }
    format!("`{}`", by_hand(command).replace('|', "\\|"))
}

/// The globs as code spans; for the message hook, the message.
fn files_cell(step: &Step) -> String {
    if step.globs.is_empty() {
        return match step.layer {
            Layer::CommitMsg => "the message".to_owned(),
            Layer::Fast | Layer::All => "-".to_owned(),
        };
    }
    let spans: Vec<String> = step.globs.iter().map(|glob| format!("`{glob}`")).collect();
    spans.join(" ")
}

/// A layer as the table names it.
fn layer_cell(layer: Layer) -> &'static str {
    match layer {
        Layer::Fast => "fast",
        Layer::All => "all",
        Layer::CommitMsg => "commit-msg",
    }
}

/// The table block, markers included.
#[must_use]
pub fn table(steps: &[Step]) -> String {
    let mut out = format!(
        "<!-- BEGIN {NAME}: generated from hk.pkl by `claudinix-dev steps --write`; do not edit -->\n\
         | step | layer | files | check | fix |\n\
         |---|---|---|---|---|\n"
    );
    for step in steps {
        let _ = writeln!(
            out,
            "| `{}` | {} | {} | {} | {} |",
            step.name,
            layer_cell(step.layer),
            files_cell(step),
            command_cell(&step.check),
            command_cell(&step.fix),
        );
    }
    out + "<!-- END " + NAME + " -->\n"
}

#[cfg(test)]
mod tests;
