//! `claudinix-dev`: tooling that maintains this repository and ships to
//! nobody (`dev/SPEC.md`). Every rule is a pure function over text, so it
//! is tested without a repository; `main.rs` alone reads files, runs `pkl`
//! and writes (dev:C31).
//!
//! ```text
//! claudinix-dev badges --write|--check [--root DIR]   README badge block
//! claudinix-dev counts --write|--check [--root DIR]   docs/INTEGRATION.md step counts
//! ```
//!
//! Exit 0 clean, 1 drift, 2 usage or I/O.

pub mod badges;
pub mod counts;
pub mod facts;
pub mod json;
pub mod notices;
pub mod region;
pub mod splice;
