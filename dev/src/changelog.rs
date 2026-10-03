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

/// Session code outside `scripts/`, path by path.
const FILES: [&str; 7] = [
    "setup.sh",
    "probe.sh",
    "allowlist.txt",
    "env-names.txt",
    "nix/cloud-home.nix",
    "nix/cloud-permissions.json",
    "nix/apps.nix",
];

/// Directories under `scripts/` that only this repository's gate, CI,
/// dev shell and flake checks run.
const REPO_ONLY: [&str; 5] = [
    "scripts/guard/",
    "scripts/hk/",
    "scripts/ci/",
    "scripts/dev/",
    "scripts/nix/",
];

/// git's scissors line: `git commit -v` puts the diff below it.
const SCISSORS: &str = "# ------------------------ >8 ------------------------";

/// Subjects git writes itself; the commits they name were judged already.
const GIT_SUBJECTS: [&str; 5] = ["Merge ", "Revert ", "fixup! ", "squash! ", "amend! "];

/// The first line git keeps of `message`: comments and everything after
/// the scissors line dropped.
#[must_use]
pub fn subject(message: &str) -> &str {
    message
        .lines()
        .take_while(|line| *line != SCISSORS)
        .find(|line| !line.starts_with('#'))
        .unwrap_or_default()
}

/// Whether a subject is a `feat` or `fix`, scoped or breaking or not.
#[must_use]
pub fn behaviour(subject: &str) -> bool {
    ["feat", "fix"].iter().any(|kind| {
        subject
            .strip_prefix(kind)
            .is_some_and(|rest| rest.starts_with(['(', '!', ':']))
    })
}

/// Whether one repository path is session code.
#[must_use]
pub fn session(path: &str) -> bool {
    if FILES.contains(&path) {
        return true;
    }
    let Some(name) = path.strip_prefix("scripts/") else {
        return false;
    };
    let spec = name
        .rsplit('/')
        .next()
        .is_some_and(|file| file.starts_with("SPEC"));
    !spec && !REPO_ONLY.iter().any(|dir| path.starts_with(dir))
}

/// HEAD as git shows it, for an amend.
pub struct Head<'text> {
    /// HEAD's subject.
    pub subject: &'text str,
    /// The paths HEAD changed, one per line.
    pub files: &'text str,
}

/// Whether a list of paths, one per line, holds the changelog.
fn has_changelog(paths: &str) -> bool {
    paths.lines().any(|path| path == "CHANGELOG.md")
}

/// Pass unless the message is a `feat` or `fix` whose staged paths
/// (`git diff --cached --name-only`, one per line) touch session code
/// without `CHANGELOG.md`. An amend of a commit that brought its own
/// entry under the same subject passes.
///
/// # Errors
///
/// The rule, the session paths and the fix.
pub fn check(message: &str, staged: &str, head: Option<&Head>) -> Result<(), String> {
    let subject = subject(message);
    if GIT_SUBJECTS.iter().any(|git| subject.starts_with(git)) || !behaviour(subject) {
        return Ok(());
    }
    let touched: Vec<&str> = staged.lines().filter(|path| session(path)).collect();
    if touched.is_empty() || has_changelog(staged) {
        return Ok(());
    }
    if head.is_some_and(|head| head.subject == subject && has_changelog(head.files)) {
        return Ok(());
    }
    let kind = subject.split(['(', '!', ':']).next().unwrap_or_default();
    let paths: String = touched.iter().flat_map(|path| ["  ", path, "\n"]).collect();
    Err(format!(
        "a {kind} commit changes what a session VM or a target-project user gets, \
         and CHANGELOG.md is not staged (dev:T111, docs:T37):\n{paths}\
         fix: add a line under ## Unreleased in CHANGELOG.md saying what changes for them, \
         then git add CHANGELOG.md and commit again. A change no user sees is not a {kind}: \
         use refactor, test, docs, chore, build or ci."
    ))
}

#[cfg(test)]
mod tests;
