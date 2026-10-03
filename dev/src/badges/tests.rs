//! The badge block: values from the facts, alt text and URL from one value
//! (dev:V2), and every empty fact refused by name (dev:V1).

use super::{Facts, esc, render};

fn facts() -> Facts {
    Facts {
        slug: "pr0d1r2/claudinix".to_owned(),
        workflow: "ci.yml".to_owned(),
        license: "MIT".to_owned(),
        status: Some("alpha".to_owned()),
        cache: "pr0d1r2.cachix.org".to_owned(),
        nix_floor: "2.34".to_owned(),
        steps: (27, 30),
        tests: 567,
        nodes: 6,
    }
}

const EXPECTED: &str = "<!-- BEGIN badges -->
[![CI](https://github.com/pr0d1r2/claudinix/actions/workflows/ci.yml/badge.svg)](https://github.com/pr0d1r2/claudinix/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![status alpha](https://img.shields.io/badge/status-alpha-orange)](docs/FACTS.md)

[![nix flake](https://img.shields.io/badge/nix-flake-5277C3?logo=nixos&logoColor=white)](flake.nix)
[![Nix ≥ 2.34](https://img.shields.io/badge/Nix-%E2%89%A52.34-5277C3?logo=nixos&logoColor=white)](setup.sh)
[![cache pr0d1r2.cachix.org](https://img.shields.io/badge/cache-pr0d1r2.cachix.org-5277C3?logo=nixos&logoColor=white)](https://pr0d1r2.cachix.org)

[![gate hk](https://img.shields.io/badge/gate-hk-6E4AFF)](hk.pkl)
[![gate steps 27 commit / 30 push](https://img.shields.io/badge/gate_steps-27_commit_%2F_30_push-6E4AFF)](hk.pkl)
[![bats tests 567](https://img.shields.io/badge/bats_tests-567-brightgreen)](tests/unit)
[![federated nodes 6](https://img.shields.io/badge/federated_nodes-6-6E4AFF)](SPEC.md)

[![built with Claude Code](https://img.shields.io/badge/built_with-Claude_Code-D97757)](https://claude.com/claude-code)
[![built with SDD](https://img.shields.io/badge/built_with-spec--driven_development-D97757)](SPEC.md)
<!-- END badges -->
";

#[test]
fn the_block_renders_every_badge_from_the_facts() {
    assert_eq!(render(&facts()), EXPECTED);
}

#[test]
fn no_status_callout_drops_the_status_badge() {
    let block = render(&Facts {
        status: None,
        ..facts()
    });
    assert!(!block.contains("status"));
    assert!(block.contains("License: MIT"));
}

/// dev:V2: a changed value reaches the alt text and the URL together.
#[test]
fn a_value_changes_alt_text_and_url_together() {
    let block = render(&Facts {
        nix_floor: "2.40-pre".to_owned(),
        steps: (31, 35),
        ..facts()
    });
    assert!(
        block.contains("[![Nix ≥ 2.40-pre](https://img.shields.io/badge/Nix-%E2%89%A52.40--pre-")
    );
    assert!(block.contains("[![gate steps 31 commit / 35 push](https://img.shields.io/badge/gate_steps-31_commit_%2F_35_push-"));
    assert!(!block.contains("27 commit"));
    assert!(!block.contains("27_commit"));
}

#[test]
fn shields_paths_escape_dashes_spaces_and_reserved_characters() {
    assert_eq!(esc("a-b c/d%e+f"), "a--b_c%2Fd%25e%2Bf");
}

/// dev:V1: an empty or zero fact is refused, naming its file.
#[test]
fn an_empty_fact_is_refused_naming_its_file() {
    let cases = [
        (
            Facts {
                slug: String::new(),
                ..facts()
            },
            "setup.sh",
        ),
        (
            Facts {
                license: String::new(),
                ..facts()
            },
            "LICENSE",
        ),
        (
            Facts {
                cache: String::new(),
                ..facts()
            },
            ".claudinix.toml",
        ),
        (
            Facts {
                nix_floor: String::new(),
                ..facts()
            },
            "setup.sh",
        ),
        (
            Facts {
                steps: (0, 30),
                ..facts()
            },
            "hk.pkl",
        ),
        (
            Facts {
                tests: 0,
                ..facts()
            },
            "tests/unit",
        ),
        (
            Facts {
                nodes: 0,
                ..facts()
            },
            "SPEC.md",
        ),
        (
            Facts {
                workflow: String::new(),
                ..facts()
            },
            ".github/workflows",
        ),
    ];
    for (bad, file) in cases {
        let refused = bad.checked().err().unwrap_or_default();
        assert!(refused.contains(file), "{refused:?} must name {file}");
    }
    assert!(facts().checked().is_ok());
}
