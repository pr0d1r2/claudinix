//! The I/O for `notices`, `facts` and `changelog` (dev:C31): read the
//! repository, call the pure rules in the library, write or report.

use std::fs;
use std::path::Path;
use std::process::Command;

use claudinix_dev::changelog::{self, Head};
use claudinix_dev::prose::{self, Owners};
use claudinix_dev::{facts, notices, region, splice};

use super::{Failed, bats_tests, gate_steps, need, read};

/// Write `doc`'s named block, or check it is `block`.
fn update(
    root: &Path,
    file: &str,
    name: &str,
    doc: &str,
    block: &str,
    verb: &str,
    check: bool,
) -> Result<(), Failed> {
    let fresh = region::splice(doc, name, block).ok_or_else(|| {
        (
            2,
            format!(
                "{file} has no <!-- BEGIN {name} --> ... <!-- END {name} --> block; add the markers"
            ),
        )
    })?;
    if fresh == doc {
        return Ok(());
    }
    if check {
        let old = region::current(doc, name).unwrap_or_default();
        let diff = splice::diff(old, block);
        return Err((
            1,
            format!(
                "{file} {name} block is stale; run: claudinix-dev {verb} --write\n{}",
                diff.trim_end()
            ),
        ));
    }
    fs::write(root.join(file), fresh).map_err(|err| (2, format!("cannot write {file}: {err}")))
}

/// Write the flake inputs table in the third-party notices, or check it.
pub fn notices(root: &Path, check: bool) -> Result<(), Failed> {
    const DOC: &str = "docs/THIRD-PARTY-NOTICES.md";
    let inputs = notices::inputs(&read(root, "flake.lock")?).map_err(|message| (2, message))?;
    let doc = read(root, DOC)?;
    let block = notices::table(&inputs);
    update(root, DOC, notices::NAME, &doc, &block, "notices", check)
}

/// The docs whose prose numbers `facts --check` holds to their owners.
const PROSE: [&str; 2] = ["README.md", "docs/LLM-DISCLAIMER.md"];

/// Every owned number, each from its file (dev:V1).
fn owners(root: &Path) -> Result<Owners, Failed> {
    let setup = read(root, "setup.sh")?;
    let (fast, all) = gate_steps(root)?;
    let nonzero = |count: usize, what: &str| need((count > 0).then_some(count), what);
    Ok(Owners {
        fast,
        all,
        tests: nonzero(bats_tests(root)?, "tests/unit `@test` lines")?,
        nodes: nonzero(
            facts::spec_nodes(&read(root, "SPEC.md")?),
            "SPEC.md §F rows",
        )?,
        probes: nonzero(
            prose::probes(&read(root, "docs/FACTS.md")?),
            "docs/FACTS.md probe sources",
        )?,
        nix_floor: need(facts::nix_floor(&setup), "setup.sh `min_version`")?,
        nix_pinned: need(prose::nix_pinned(&setup), "setup.sh `version=`")?,
    })
}

/// Check the numbers the prose states against their owners.
pub fn facts(root: &Path, check: bool) -> Result<(), Failed> {
    if !check {
        return Err((2, "facts has no --write: fix the prose by hand".to_owned()));
    }
    let owners = owners(root)?;
    let mut found = 0;
    let mut stale = Vec::new();
    for doc in PROSE {
        let claims = prose::claims(&read(root, doc)?, &owners);
        found += claims.len();
        stale.extend(prose::drift(doc, &claims));
    }
    if found == 0 {
        let docs = PROSE.join(" and ");
        return Err((
            2,
            format!("{docs} state no owned number; nothing was checked"),
        ));
    }
    if stale.is_empty() {
        return Ok(());
    }
    Err((
        1,
        format!(
            "prose numbers drifted from their owners; edit the prose:\n{}",
            stale.join("\n")
        ),
    ))
}

/// What `git ARGS` prints, or `None` when it fails (no HEAD yet).
fn git(args: &[&str]) -> Result<Option<String>, Failed> {
    let out = Command::new("git")
        .args(args)
        .output()
        .map_err(|err| (2, format!("git could not run ({err})")))?;
    Ok(out
        .status
        .success()
        .then(|| String::from_utf8_lossy(&out.stdout).into_owned()))
}

/// The commit-msg rule: a feat or fix touching session code stages
/// CHANGELOG.md (dev:T111). `file` is the message file git hands the hook.
pub fn changelog(file: &str) -> Result<(), Failed> {
    let message =
        fs::read_to_string(file).map_err(|err| (2, format!("cannot read {file}: {err}")))?;
    let staged = git(&["diff", "--cached", "--name-only"])?
        .ok_or_else(|| (2, "git diff --cached --name-only failed".to_owned()))?;
    let subject = git(&["log", "-1", "--format=%s"])?.unwrap_or_default();
    let files = git(&["show", "--name-only", "--format=", "HEAD"])?.unwrap_or_default();
    let head = Head {
        subject: subject.trim_end(),
        files: &files,
    };
    changelog::check(&message, &staged, Some(&head)).map_err(|message| (1, message))
}
