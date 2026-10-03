//! docs/CLI.md's usage lines against the scripts' own (dev:V1).

use super::{doc_usages, drift, script_usages};

const INPUTS: &str = r#"#!/usr/bin/env bash
# Usage: inputs.sh [--check] [FLAKE_DIR]   (default: the current directory)
set -euo pipefail
usage() {
    echo "usage: inputs.sh [--check] [FLAKE_DIR]" >&2
    exit 2
}
"#;

const SETUP: &str = r#"#!/usr/bin/env bash
# Usage: setup.sh [SHA] [--agent-home]
usage="usage: setup.sh [SHA] [--agent-home] -- SHA is a full 40-hex commit id"
"#;

const CARGO: &str = r#"#!/usr/bin/env bash
# Usage: cargo.sh PROJECT_DIR   -> `host<TAB>file` lines
dir="${1:?usage: cargo.sh PROJECT_DIR}"
"#;

const NIX_DEV: &str = "#!/usr/bin/env bash
# Usage: nix-dev [INSTALLABLE] [ARGS...]   (as for `nix develop`)
set -euo pipefail
";

#[test]
fn the_printed_usage_strings_are_found_and_comments_skipped() {
    assert_eq!(
        script_usages(INPUTS),
        vec!["usage: inputs.sh [--check] [FLAKE_DIR]".to_owned()]
    );
    assert_eq!(
        script_usages(SETUP),
        vec!["usage: setup.sh [SHA] [--agent-home] -- SHA is a full 40-hex commit id".to_owned()]
    );
    assert_eq!(
        script_usages(CARGO),
        vec!["usage: cargo.sh PROJECT_DIR".to_owned()]
    );
}

#[test]
fn a_script_that_prints_none_falls_back_to_its_header() {
    assert_eq!(
        script_usages(NIX_DEV),
        vec!["usage: nix-dev [INSTALLABLE] [ARGS...]   (as for `nix develop`)".to_owned()]
    );
    assert_eq!(script_usages("#!/bin/sh\necho hi\n"), Vec::<String>::new());
}

const DOC: &str = "# CLI

usage: in prose is not a quote.

```text
usage: inputs.sh [--check] [FLAKE_DIR]
```

```text
usage: setup.sh [SHA] [--agent-home] -- SHA is a full 40-hex commit id
```
";

#[test]
fn only_usage_lines_inside_code_blocks_are_quotes() {
    assert_eq!(
        doc_usages(DOC),
        vec![
            (6, "usage: inputs.sh [--check] [FLAKE_DIR]".to_owned()),
            (
                10,
                "usage: setup.sh [SHA] [--agent-home] -- SHA is a full 40-hex commit id".to_owned()
            ),
        ]
    );
}

#[test]
fn matching_usages_have_no_drift() {
    let scripts = [("scripts/inputs.sh", INPUTS), ("setup.sh", SETUP)];
    assert_eq!(drift(DOC, &scripts), Ok(Vec::new()));
}

#[test]
fn a_stale_quote_names_the_doc_line_and_the_script() {
    let stale = INPUTS.replace(
        "[--check] [FLAKE_DIR]\"",
        "[--check] [--json] [FLAKE_DIR]\"",
    );
    let scripts = [("scripts/inputs.sh", stale.as_str()), ("setup.sh", SETUP)];
    let problems = drift(DOC, &scripts).unwrap_or_default();
    assert_eq!(
        problems,
        vec![
            "docs/CLI.md line 6: `usage: inputs.sh [--check] [FLAKE_DIR]`; scripts/inputs.sh says `usage: inputs.sh [--check] [--json] [FLAKE_DIR]`"
                .to_owned()
        ]
    );
}

#[test]
fn a_quote_of_no_script_is_drift() {
    let scripts = [("setup.sh", SETUP)];
    let problems = drift(DOC, &scripts).unwrap_or_default();
    assert_eq!(
        problems,
        vec![
            "docs/CLI.md line 6: `usage: inputs.sh [--check] [FLAKE_DIR]`; no script inputs.sh in scripts/*.sh or setup.sh"
                .to_owned()
        ]
    );
}

#[test]
fn a_script_without_usage_text_is_drift() {
    let scripts = [("scripts/inputs.sh", "#!/bin/sh\n"), ("setup.sh", SETUP)];
    let problems = drift(DOC, &scripts).unwrap_or_default();
    assert_eq!(
        problems,
        vec![
            "docs/CLI.md line 6: `usage: inputs.sh [--check] [FLAKE_DIR]`; scripts/inputs.sh prints no usage text"
                .to_owned()
        ]
    );
}

/// dev:V1: a doc with nothing to check is an error, not a pass.
#[test]
fn a_doc_without_usage_lines_is_refused() {
    assert!(drift("# CLI\n", &[("setup.sh", SETUP)]).is_err());
}
