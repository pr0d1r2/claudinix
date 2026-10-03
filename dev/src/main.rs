//! `claudinix-dev`: the I/O shell over `claudinix_dev` (dev:C31). It alone
//! reads the repository, runs `pkl` and writes; every rule is a pure
//! function in the library.
//!
//! ```text
//! claudinix-dev badges --write|--check [--root DIR]
//! claudinix-dev notices --write|--check [--root DIR]
//! claudinix-dev facts --check [--root DIR]
//! claudinix-dev changelog MESSAGE-FILE
//! claudinix-dev steps --write|--check [--root DIR]
//! claudinix-dev cli --check [--root DIR]
//! ```
//!
//! Exit 0 clean, 1 drift, 2 usage or I/O.

use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};

use claudinix_dev::badges::{Facts, render};
use claudinix_dev::{block, cli, counts, facts, splice, steps};

mod verbs;

const USAGE: &str = "usage: claudinix-dev <badges|notices|steps> <--write|--check> [--root DIR]
       claudinix-dev cli|facts --check [--root DIR]
       claudinix-dev changelog MESSAGE-FILE";

/// The CI workflow the badge links to.
const WORKFLOW: &str = "ci.yml";

/// An exit code and the message to print with it.
type Failed = (u8, String);

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match dispatch(&args) {
        Ok(()) => ExitCode::SUCCESS,
        Err((code, message)) => {
            eprintln!("claudinix-dev: {message}");
            ExitCode::from(code)
        }
    }
}

fn dispatch(args: &[String]) -> Result<(), Failed> {
    let words: Vec<&str> = args.iter().map(String::as_str).collect();
    if let ["changelog", file] = words.as_slice() {
        return verbs::changelog(file);
    }
    let (verb, mode, root) = match words.as_slice() {
        [verb, mode] => (*verb, *mode, "."),
        [verb, mode, "--root", root] => (*verb, *mode, *root),
        _ => return Err(usage()),
    };
    let check = match mode {
        "--check" => true,
        "--write" => false,
        _ => return Err(usage()),
    };
    let root = Path::new(root);
    match verb {
        "badges" => badges(root, check),
        "notices" => verbs::notices(root, check),
        "facts" => verbs::facts(root, check),
        "steps" => step_table(root, check),
        "cli" if check => cli_usages(root),
        _ => Err(usage()),
    }
}

fn usage() -> Failed {
    (2, USAGE.to_owned())
}

/// A file's text, or exit 2 naming it.
fn read(root: &Path, name: &str) -> Result<String, Failed> {
    fs::read_to_string(root.join(name)).map_err(|err| (2, format!("cannot read {name}: {err}")))
}

/// A fact, or exit 2 naming the file it should have come from (dev:V1).
fn need<T>(value: Option<T>, what: &str) -> Result<T, Failed> {
    value.ok_or_else(|| (2, format!("{what} read empty or zero; fix the source")))
}

/// What `pkl eval hk.pkl -x EXPR` prints.
fn pkl(root: &Path, expr: &str) -> Result<String, Failed> {
    let out = Command::new("pkl")
        .arg("eval")
        .arg("hk.pkl")
        .arg("-x")
        .arg(expr)
        .current_dir(root)
        .output()
        .map_err(|err| (2, format!("pkl could not run ({err}); enter the dev shell")))?;
    if !out.status.success() {
        let stderr = String::from_utf8_lossy(&out.stderr);
        return Err((2, format!("pkl eval hk.pkl -x '{expr}' failed: {stderr}")));
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}

/// Steps in one hk.pkl hook, as the official evaluator counts them.
fn hook_steps(root: &Path, hook: &str) -> Result<usize, Failed> {
    let text = pkl(root, &format!("hooks[\"{hook}\"].steps.length"))?;
    need(facts::step_count(&text), &format!("hk.pkl {hook} steps"))
}

/// The `fast` and `all` step counts: pre-commit and check.
fn gate_steps(root: &Path) -> Result<(usize, usize), Failed> {
    Ok((hook_steps(root, "pre-commit")?, hook_steps(root, "check")?))
}

/// Every `*.bats` file under `dir`, recursively.
fn bats_files(dir: &Path, found: &mut Vec<PathBuf>) -> Result<(), Failed> {
    let entries =
        fs::read_dir(dir).map_err(|err| (2, format!("cannot read {}: {err}", dir.display())))?;
    for entry in entries {
        let path = entry
            .map_err(|err| (2, format!("cannot read {}: {err}", dir.display())))?
            .path();
        if path.is_dir() {
            bats_files(&path, found)?;
        } else if path.extension().is_some_and(|ext| ext == "bats") {
            found.push(path);
        }
    }
    Ok(())
}

/// `@test` lines across `tests/unit/**/*.bats`.
fn bats_tests(root: &Path) -> Result<usize, Failed> {
    let mut files = Vec::new();
    bats_files(&root.join("tests/unit"), &mut files)?;
    let mut total = 0;
    for file in files {
        let text = fs::read_to_string(&file)
            .map_err(|err| (2, format!("cannot read {}: {err}", file.display())))?;
        total += facts::bats_tests(&text);
    }
    Ok(total)
}

/// Every badge fact, each from the file that owns it (dev:V1).
fn gather(root: &Path, readme: &str) -> Result<Facts, Failed> {
    let setup = read(root, "setup.sh")?;
    if !root.join(".github/workflows").join(WORKFLOW).is_file() {
        return Err((2, format!(".github/workflows/{WORKFLOW} is missing")));
    }
    let cache = need(
        facts::cache_name(&read(root, ".claudinix.toml")?),
        ".claudinix.toml `cache.name`",
    )?;
    Facts {
        slug: need(facts::fork_repo(&setup), "setup.sh fork block `repo=`")?,
        workflow: WORKFLOW.to_owned(),
        license: need(
            facts::license(&read(root, "LICENSE")?),
            "LICENSE first line",
        )?,
        status: facts::status(readme),
        cache: format!("{cache}.cachix.org"),
        nix_floor: need(facts::nix_floor(&setup), "setup.sh `min_version`")?,
        steps: gate_steps(root)?,
        tests: bats_tests(root)?,
        nodes: facts::spec_nodes(&read(root, "SPEC.md")?),
    }
    .checked()
    .map_err(|message| (2, message))
}

/// Write the README badge block, or check it is what the facts render.
fn badges(root: &Path, check: bool) -> Result<(), Failed> {
    let readme = read(root, "README.md")?;
    let block = render(&gather(root, &readme)?);
    let fresh = need(
        splice::splice(&readme, &block),
        "README.md title (`# `) or badge markers",
    )?;
    if fresh == readme {
        return Ok(());
    }
    if check {
        let old = splice::current(&readme).unwrap_or_default();
        let diff = splice::diff(old, &block);
        return Err((
            1,
            format!(
                "README.md badges are stale; run: claudinix-dev badges --write\n{}",
                diff.trim_end()
            ),
        ));
    }
    fs::write(root.join("README.md"), fresh)
        .map_err(|err| (2, format!("cannot write README.md: {err}")))
}

/// Write the step table and the step counts docs/INTEGRATION.md states,
/// or check them; one `pkl` run gives both (dev:T106).
fn step_table(root: &Path, check: bool) -> Result<(), Failed> {
    const DOC: &str = "docs/INTEGRATION.md";
    let doc = read(root, DOC)?;
    let rows = pkl(root, steps::ROWS)?;
    let found = steps::parse(&rows).map_err(|message| (2, message))?;
    let (fast, all) = steps::counts(&found);
    let table = steps::table(&found);
    let spliced = block::splice(&doc, steps::NAME, &table).ok_or_else(|| {
        (
            2,
            format!("{DOC} has no <!-- BEGIN steps --> ... <!-- END steps --> block"),
        )
    })?;
    let stale = counts::drift(&doc, fast, all).map_err(|message| (2, message))?;
    let fresh = counts::rewrite(&spliced, fast, all);
    if fresh == doc {
        return Ok(());
    }
    if check {
        let old = block::current(&doc, steps::NAME).unwrap_or_default();
        let mut report = splice::diff(old, &table);
        for line in stale {
            report.push_str(&line);
            report.push('\n');
        }
        return Err((
            1,
            format!(
                "{DOC} step table drifted from hk.pkl; run: claudinix-dev steps --write\n{}",
                report.trim_end()
            ),
        ));
    }
    fs::write(root.join(DOC), fresh).map_err(|err| (2, format!("cannot write {DOC}: {err}")))
}

/// `setup.sh` and every `scripts/*.sh`, path and source, sorted by path.
fn usage_scripts(root: &Path) -> Result<Vec<(String, String)>, Failed> {
    let dir = root.join("scripts");
    let entries =
        fs::read_dir(&dir).map_err(|err| (2, format!("cannot read {}: {err}", dir.display())))?;
    let mut names = vec!["setup.sh".to_owned()];
    for entry in entries {
        let path = entry
            .map_err(|err| (2, format!("cannot read {}: {err}", dir.display())))?
            .path();
        if path.is_file() && path.extension().is_some_and(|ext| ext == "sh") {
            let file = path.file_name().unwrap_or_default().to_string_lossy();
            names.push(format!("scripts/{file}"));
        }
    }
    names.sort();
    names
        .into_iter()
        .map(|name| Ok((read(root, &name)?, name)).map(|(text, name)| (name, text)))
        .collect()
}

/// Check every `usage:` line docs/CLI.md quotes against its script's
/// own usage text (dev:T107).
fn cli_usages(root: &Path) -> Result<(), Failed> {
    const DOC: &str = "docs/CLI.md";
    let doc = read(root, DOC)?;
    let owned = usage_scripts(root)?;
    let scripts: Vec<(&str, &str)> = owned
        .iter()
        .map(|(name, text)| (name.as_str(), text.as_str()))
        .collect();
    let stale = cli::drift(&doc, &scripts).map_err(|message| (2, message))?;
    if stale.is_empty() {
        return Ok(());
    }
    Err((
        1,
        format!(
            "{DOC} quotes usage text its scripts do not print; fix the doc or the script\n{}",
            stale.join("\n")
        ),
    ))
}
