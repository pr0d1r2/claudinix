//! `claudinix-dev`: tooling that maintains this repository and ships to
//! nobody (`dev/SPEC.md`). Every rule is a pure function over text, so it
//! is tested without a repository; `main.rs` alone reads files, runs `pkl`
//! and writes (dev:C31).
//!
//! ```text
//! claudinix-dev badges --write|--check [--root DIR]   README badge block
//! claudinix-dev notices --write|--check [--root DIR]  docs/THIRD-PARTY-NOTICES.md flake inputs
//! claudinix-dev facts --check [--root DIR]            prose numbers = their owners
//! claudinix-dev changelog MESSAGE-FILE                commit-msg: feat|fix on session code stages CHANGELOG.md
//! claudinix-dev steps --write|--check [--root DIR]    docs/INTEGRATION.md step table and counts
//! claudinix-dev cli --check [--root DIR]               docs/CLI.md usage lines
//! ```
//!
//! Exit 0 clean, 1 drift, 2 usage or I/O.

pub mod badges;
pub mod block;
pub mod changelog;
pub mod cli;
pub mod counts;
pub mod facts;
pub mod json;
pub mod notices;
pub mod prose;
pub mod region;
pub mod splice;
pub mod steps;
