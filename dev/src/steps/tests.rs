//! The hk step table, from the rows `pkl eval -x` prints (dev:V1, V3).

use super::{Layer, Step, by_hand, counts, parse, table};

/// Two fast steps, one push-only step, the commit-msg step: `check` lists
/// the fast ones again, as `all` amends `fast` in hk.pkl.
const ROWS: &str = "pre-commit\tshellcheck\t**/*.sh\u{1F}.envrc\tscripts/hk/run-tool.sh shellcheck {{files}}\t
pre-commit\tspec-fmt\t**/SPEC.md\tscripts/hk/run-tool.sh mth fmt --check {{workspace}}/SPEC.md\tscripts/hk/run-tool.sh mth fmt {{workspace}}/SPEC.md
check\tshellcheck\t**/*.sh\u{1F}.envrc\tscripts/hk/run-tool.sh shellcheck {{files}}\t
check\tspec-fmt\t**/SPEC.md\tscripts/hk/run-tool.sh mth fmt --check {{workspace}}/SPEC.md\tscripts/hk/run-tool.sh mth fmt {{workspace}}/SPEC.md
check\ttdd-order\t**/*\tscripts/guard/tdd-order.sh\t
commit-msg\tcommit-msg\t\tscripts/guard/commit-msg.sh\t
";

fn step(name: &str, layer: Layer, globs: &[&str], check: &str, fix: &str) -> Step {
    Step {
        name: name.to_owned(),
        layer,
        globs: globs.iter().map(|glob| (*glob).to_owned()).collect(),
        check: check.to_owned(),
        fix: fix.to_owned(),
    }
}

#[test]
fn rows_become_steps_in_layers() {
    assert_eq!(
        parse(ROWS),
        Ok(vec![
            step(
                "shellcheck",
                Layer::Fast,
                &["**/*.sh", ".envrc"],
                "scripts/hk/run-tool.sh shellcheck {{files}}",
                "",
            ),
            step(
                "spec-fmt",
                Layer::Fast,
                &["**/SPEC.md"],
                "scripts/hk/run-tool.sh mth fmt --check {{workspace}}/SPEC.md",
                "scripts/hk/run-tool.sh mth fmt {{workspace}}/SPEC.md",
            ),
            step(
                "tdd-order",
                Layer::All,
                &["**/*"],
                "scripts/guard/tdd-order.sh",
                ""
            ),
            step(
                "commit-msg",
                Layer::CommitMsg,
                &[],
                "scripts/guard/commit-msg.sh",
                ""
            ),
        ])
    );
}

#[test]
fn the_counts_are_the_pre_commit_and_check_hooks() {
    let steps = parse(ROWS).unwrap_or_default();
    assert_eq!(counts(&steps), (2, 3));
}

/// dev:V1: a hook that reads empty is an error, not an empty table.
#[test]
fn a_hook_without_steps_is_refused() {
    let no_fast =
        "check\ttdd-order\t**/*\tscripts/guard/tdd-order.sh\t\ncommit-msg\tcommit-msg\t\tx\t\n";
    let err = parse(no_fast).err().unwrap_or_default();
    assert!(err.contains("pre-commit"), "{err}");
    assert!(parse("").is_err());
}

#[test]
fn a_malformed_row_is_refused() {
    let err = parse("pre-commit\tonly-two\n").err().unwrap_or_default();
    assert!(err.contains("only-two"), "{err}");
    let err = parse("pre-push\tx\t\tc\t\n").err().unwrap_or_default();
    assert!(err.contains("pre-push"), "{err}");
}

#[test]
fn a_command_by_hand_drops_the_wrapper_and_names_the_placeholders() {
    assert_eq!(
        by_hand("scripts/hk/run-tool.sh shellcheck {{files}}"),
        "shellcheck <files>"
    );
    assert_eq!(
        by_hand("scripts/hk/run-tool.sh mth fmt --check {{workspace}}/SPEC.md"),
        "mth fmt --check <node>/SPEC.md"
    );
    assert_eq!(
        by_hand("scripts/guard/exec-bit.sh"),
        "scripts/guard/exec-bit.sh"
    );
}

#[test]
fn the_table_has_one_row_per_step_between_markers() {
    let block = table(&parse(ROWS).unwrap_or_default());
    assert!(
        block.starts_with("<!-- BEGIN steps: generated from hk.pkl by `claudinix-dev steps --write`; do not edit -->\n"),
        "{block}"
    );
    assert!(block.ends_with("\n<!-- END steps -->\n"), "{block}");
    let rows = [
        "| step | layer | files | check | fix |",
        "|---|---|---|---|---|",
        "| `shellcheck` | fast | `**/*.sh` `.envrc` | `shellcheck <files>` | - |",
        "| `spec-fmt` | fast | `**/SPEC.md` | `mth fmt --check <node>/SPEC.md` | `mth fmt <node>/SPEC.md` |",
        "| `tdd-order` | all | `**/*` | `scripts/guard/tdd-order.sh` | - |",
        "| `commit-msg` | commit-msg | the message | `scripts/guard/commit-msg.sh` | - |",
    ];
    for row in rows {
        assert!(block.contains(&format!("{row}\n")), "{row}\n{block}");
    }
}

/// A pipe inside a command would split the table cell.
#[test]
fn a_pipe_in_a_command_is_escaped() {
    let steps = [step("p", Layer::Fast, &["x"], "a | b", "")];
    assert!(table(&steps).contains("| `a \\| b` |"), "{}", table(&steps));
}
