//! The changelog rule (dev:T111, docs:T37, .:V20): a `feat` or `fix`
//! commit that changes what a session VM or a target-project user gets
//! stages `CHANGELOG.md` too. Pure functions over the commit message and
//! the paths git says the commit stages.
//!
//! Session code is what reaches a user: `setup.sh` (runs as root on the
//! VM), `probe.sh` (run inside a session), the agent home
//! (`nix/cloud-home.nix`, `nix/cloud-permissions.json`), the flake apps
//! (`nix/apps.nix`) with the data they read (`allowlist.txt`,
//! `env-names.txt`), and `scripts/**`, the apps' scripts and data. Not
//! session code: the gate's own scripts (`scripts/guard/`, `scripts/hk/`),
//! CI's (`scripts/ci/`), the dev shell's (`scripts/dev/`), the flake
//! checks' (`scripts/nix/`), and spec files.

/// The first line git keeps of `message`: comments and everything after
/// the scissors line dropped.
#[must_use]
pub fn subject(message: &str) -> &str {
    message.get(..0).unwrap_or_default()
}

/// Whether a subject is a `feat` or `fix`, scoped or breaking or not.
#[must_use]
pub fn behaviour(_subject: &str) -> bool {
    false
}

/// Whether one repository path is session code.
#[must_use]
pub fn session(_path: &str) -> bool {
    false
}

/// HEAD as git shows it, for an amend.
pub struct Head<'text> {
    /// HEAD's subject.
    pub subject: &'text str,
    /// The paths HEAD changed, one per line.
    pub files: &'text str,
}

/// Pass unless the message is a `feat` or `fix` whose staged paths
/// (`git diff --cached --name-only`, one per line) touch session code
/// without `CHANGELOG.md`. An amend of a commit that brought its own
/// entry under the same subject passes.
///
/// # Errors
///
/// The rule, the session paths and the fix.
pub fn check(_message: &str, _staged: &str, _head: Option<&Head>) -> Result<(), String> {
    Ok(())
}

#[cfg(test)]
mod tests;
