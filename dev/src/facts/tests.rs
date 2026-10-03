//! Each fact read from the text of the file that owns it (dev:V1).

use super::{
    bats_tests, cache_name, fork_repo, license, nix_floor, spec_nodes, status, step_count,
};

const SETUP: &str = "#!/usr/bin/env bash\n\
# BEGIN fork config (SPEC C11)\n\
cache_host=pr0d1r2.cachix.org\n\
repo=pr0d1r2/claudinix\n\
# END fork config (SPEC C11)\n\
repo=someone/else\n\
min_version=\"${NIX_MIN_VERSION:-2.34}\"\n";

#[test]
fn the_repo_slug_comes_from_the_fork_block_only() {
    assert_eq!(fork_repo(SETUP).as_deref(), Some("pr0d1r2/claudinix"));
    assert_eq!(fork_repo("repo=outside/block\n"), None);
    let empty = "# BEGIN fork config\nrepo=\n# END fork config\n";
    assert_eq!(fork_repo(empty), None);
}

#[test]
fn the_nix_floor_is_the_min_version_default() {
    assert_eq!(nix_floor(SETUP).as_deref(), Some("2.34"));
    assert_eq!(nix_floor("min_version=2.30\n").as_deref(), Some("2.30"));
    assert_eq!(nix_floor("min_version=\"\"\n"), None);
    assert_eq!(nix_floor("nothing here\n"), None);
}

#[test]
fn the_license_is_the_first_line_without_license() {
    assert_eq!(
        license("MIT License\n\nCopyright\n").as_deref(),
        Some("MIT")
    );
    assert_eq!(
        license("Apache License 2.0\n").as_deref(),
        Some("Apache 2.0")
    );
    assert_eq!(license(""), None);
    assert_eq!(license("License\n"), None);
}

#[test]
fn the_cache_name_is_read_from_the_cache_table() {
    let toml = "version = 1\n[session]\nname = \"no\"\n\n[cache]\n# c\nname = \"pr0d1r2\"\npush_sources = true\n";
    assert_eq!(cache_name(toml).as_deref(), Some("pr0d1r2"));
    assert_eq!(cache_name("[cache]\nname = \"\"\n"), None);
    assert_eq!(cache_name("[other]\nname = \"x\"\n"), None);
}

#[test]
fn the_status_follows_the_alpha_callout() {
    let readme = "# t\n\n> **Alpha, 2026-10-03.** Proven in\n> more\n";
    assert_eq!(status(readme).as_deref(), Some("alpha"));
    assert_eq!(
        status("# t\n\n> **Beta, 2027-01-01.** x\n").as_deref(),
        Some("beta")
    );
    assert_eq!(status("# t\n\nAlpha is mentioned in prose.\n"), None);
}

#[test]
fn bats_tests_count_test_lines() {
    let bats = "#!/usr/bin/env bats\n\n@test \"one\" {\n  run x\n}\n\n  @test \"two\" {\n}\n# @test \"not\"\necho @test\n";
    assert_eq!(bats_tests(bats), 2);
    assert_eq!(bats_tests(""), 0);
}

#[test]
fn spec_nodes_are_federation_rows_plus_the_root() {
    let spec = "# SPEC\n\n## §F FEDERATION\n\ndir|owns|⊥owns|tokens\na|x|y|-\nb|x|y|-\n\n## §N NAV\n\nrel|path|lens\nup|-|-\n";
    assert_eq!(spec_nodes(spec), 3);
    assert_eq!(
        spec_nodes("# SPEC\n\n## §F FEDERATION\n\ndir|owns|⊥owns|tokens\n"),
        0
    );
    assert_eq!(spec_nodes("# SPEC\n"), 0);
}

#[test]
fn a_step_count_is_pkls_bare_number() {
    assert_eq!(step_count("27"), Some(27));
    assert_eq!(step_count("30\n"), Some(30));
    assert_eq!(step_count("0"), None);
    assert_eq!(step_count("x"), None);
}
