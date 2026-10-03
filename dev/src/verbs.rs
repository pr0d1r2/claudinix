//! The I/O for `notices`, `facts` and `changelog` (dev:C31): read the
//! repository, call the pure rules in the library, write or report.

use std::fs;
use std::path::Path;

use claudinix_dev::{notices, region, splice};

use super::{Failed, read};

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
