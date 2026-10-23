//! MODEL.md's price table from burn.sh's `PRICES` array (dev:V1).

use super::{Price, display, parse, table};

const SCRIPT: &str = r#"#!/usr/bin/env bash
# a comment mentioning PRICES=(
PRICES=(
    "claude-opus-5-5 4 20"
    "claude-haiku-4-5 1 5.5"
)

set -euo pipefail
"#;

fn price(model: &str, input: f64, output: f64) -> Price {
    Price {
        model: model.to_owned(),
        input,
        output,
    }
}

#[test]
fn rows_come_in_source_order() {
    assert_eq!(
        parse(SCRIPT),
        Ok(vec![
            price("claude-opus-5-5", 4.0, 20.0),
            price("claude-haiku-4-5", 1.0, 5.5),
        ])
    );
}

#[test]
fn a_script_without_the_array_is_refused() {
    let err = parse("set -e\n").err().unwrap_or_default();
    assert!(err.contains("scripts/burn.sh"), "{err}");
}

#[test]
fn an_empty_array_is_refused() {
    assert!(parse("PRICES=(\n)\n").is_err());
}

#[test]
fn a_row_with_a_non_number_is_refused() {
    let err = parse("PRICES=(\n    \"claude-x 4 many\"\n)\n")
        .err()
        .unwrap_or_default();
    assert!(err.contains("claude-x"), "{err}");
}

#[test]
fn a_row_with_a_missing_field_is_refused() {
    assert!(parse("PRICES=(\n    \"claude-x 4\"\n)\n").is_err());
}

#[test]
fn a_model_id_reads_as_its_name() {
    assert_eq!(display("claude-opus-5-5"), "Claude Opus 5.5");
    assert_eq!(display("claude-haiku-4-5"), "Claude Haiku 4.5");
    assert_eq!(display("claude-fable-5-1"), "Claude Fable 5.1");
}

#[test]
fn the_table_has_markers_and_two_decimals() {
    assert_eq!(
        table(&[price("claude-opus-5-5", 4.0, 20.0)]),
        "<!-- BEGIN prices: generated from scripts/burn.sh by `claudinix-dev prices --write`; do not edit -->\n\
         | model | input | output |\n\
         |---|---|---|\n\
         | Claude Opus 5.5 | $4.00 | $20.00 |\n\
         <!-- END prices -->\n"
    );
}
