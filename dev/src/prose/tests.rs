//! The numbers prose states, each held to the file that owns it (dev:V1).

use super::{Owners, claims, drift, nix_pinned, probes};

fn owners() -> Owners {
    Owners {
        fast: 32,
        all: 36,
        tests: 600,
        nodes: 6,
        probes: 7,
        nix_floor: "2.34".to_owned(),
        nix_pinned: "2.35.2".to_owned(),
    }
}

const README: &str = "# claudinix

<!-- BEGIN badges -->
[![bats tests 1](x)](tests/unit) took two probe sessions
<!-- END badges -->

Getting `nix develop` to work there took seven probe sessions; the
real probe sessions are listed in FACTS.

- `setup.sh` uses the image's Nix and installs the pinned
  2.35.2 only if the image falls below the floor of 2.34. It only runs
  when the image's Nix is older than 2.34.
- The gate runs 32 steps on every commit and 36 steps on every push, over
  600 bats tests and 6 federated nodes.
";

/// The phrases found, as the doc says them; badges are not prose.
#[test]
fn every_owned_number_in_prose_is_found() {
    let said: Vec<String> = claims(README, &owners())
        .into_iter()
        .map(|claim| claim.said)
        .collect();
    assert_eq!(
        said,
        [
            "seven probe sessions",
            "installs the pinned 2.35.2",
            "floor of 2.34",
            "Nix is older than 2.34",
            "32 steps on every commit",
            "36 steps on every push",
            "600 bats tests",
            "6 federated nodes",
        ]
    );
}

#[test]
fn matching_numbers_have_no_drift() {
    assert_eq!(
        drift("README.md", &claims(README, &owners())),
        Vec::<String>::new()
    );
}

#[test]
fn every_stale_number_names_its_owner_and_the_fix() {
    let moved = Owners {
        fast: 33,
        tests: 601,
        probes: 8,
        nix_floor: "2.36".to_owned(),
        nix_pinned: "2.36.1".to_owned(),
        ..owners()
    };
    assert_eq!(
        drift("README.md", &claims(README, &moved)),
        [
            "README.md: \"seven probe sessions\"; docs/FACTS.md distinct probes is 8: say eight",
            "README.md: \"installs the pinned 2.35.2\"; setup.sh `version=` is 2.36.1: say 2.36.1",
            "README.md: \"floor of 2.34\"; setup.sh `min_version` is 2.36: say 2.36",
            "README.md: \"Nix is older than 2.34\"; setup.sh `min_version` is 2.36: say 2.36",
            "README.md: \"32 steps on every commit\"; hk.pkl pre-commit steps is 33: say 33",
            "README.md: \"600 bats tests\"; tests/unit `@test` lines is 601: say 601",
        ]
    );
}

#[test]
fn words_that_are_not_numbers_are_not_claims() {
    let doc = "the real probe sessions, the pinned release, the floor of the shell\n";
    assert!(claims(doc, &owners()).is_empty());
}

/// The probe count's owner: distinct probe numbers in FACTS.md's table
/// rows, ranges expanded; prose outside the tables does not count.
#[test]
fn probes_are_the_distinct_numbers_the_fact_tables_cite() {
    let facts = "Sources in brackets (probe 1, probe 9, ...) are the order.

| fact | date | source |
|---|---|---|
| a | 2026-10-03 | probe 1 |
| b | 2026-10-03 | probes 1-3 |
| c | 2026-10-03 | probes 5, 7 |
| d | 2026-10-03 | probe 6, sherd #96 session |
| e | 2026-10-03 | usage page |
";
    assert_eq!(probes(facts), 6);
    assert_eq!(probes("no probes here\n"), 0);
}

#[test]
fn the_pinned_nix_is_the_setup_version() {
    let setup = "#!/usr/bin/env bash\nfoo() {\n    version=9\n}\nversion=2.35.2\nmin_version=\"${NIX_MIN_VERSION:-2.34}\"\n";
    assert_eq!(nix_pinned(setup).as_deref(), Some("2.35.2"));
    assert_eq!(nix_pinned("version=\n"), None);
    assert_eq!(nix_pinned("min_version=2.34\n"), None);
}
