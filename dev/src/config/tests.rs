//! CONFIG.md's key table from config.jq's schema (dev:V1).

use super::{Key, Value, parse, schema, table};

const JQ: &str = r#"# The schema.
def schema: {
  # a comment inside
  session: {
    model: {type: "string", values: ["sonnet", "opus"], default: "sonnet", readers: "`guide`, `probe`"},
    agent_home: {type: "boolean", default: false, readers: "`guide`"}
  },
  network: {
    extra_domains: {type: "strings", rule: "hostname", default: [], readers: "`domains`"}
  },
  cache: {
    name: {type: "string", rule: "cachix", pattern: "^[a-z0-9][a-z0-9-]*$", default: "pr0d1r2", readers: "`inputs`"}
  },
  probe: {
    branch_prefix: {type: "string", rule: "shell", default: "claude/nix-probe", readers: "`probe`"}
  }
};

def hostname: test("^x\\.y$");
"#;

fn key(name: &str, kind: &str, default: &str, readers: &str) -> Key {
    Key {
        name: name.to_owned(),
        kind: kind.to_owned(),
        values: Vec::new(),
        pattern: None,
        rule: None,
        default: default.to_owned(),
        readers: readers.to_owned(),
    }
}

#[test]
fn jq_literals_parse() {
    assert_eq!(
        parse(r#"{a: "x\"y\\z", "b c": [1, true, null], d: {}}"#),
        Ok(Value::Object(vec![
            ("a".to_owned(), Value::Text("x\"y\\z".to_owned())),
            (
                "b c".to_owned(),
                Value::List(vec![
                    Value::Number("1".to_owned()),
                    Value::Bool(true),
                    Value::Null
                ])
            ),
            ("d".to_owned(), Value::Object(Vec::new())),
        ]))
    );
}

#[test]
fn an_expression_is_not_a_literal() {
    assert!(parse(r#"{a: "\(.x)"}"#).is_err());
    assert!(parse("{a: .x}").is_err());
    assert!(parse("{a: 1").is_err());
}

#[test]
fn the_schema_lists_every_key_in_order() {
    let mut model = key("session.model", "string", "\"sonnet\"", "`guide`, `probe`");
    model.values = vec!["sonnet".to_owned(), "opus".to_owned()];
    let mut domains = key("network.extra_domains", "strings", "[]", "`domains`");
    domains.rule = Some("hostname".to_owned());
    let mut cache = key("cache.name", "string", "\"pr0d1r2\"", "`inputs`");
    cache.rule = Some("cachix".to_owned());
    cache.pattern = Some("^[a-z0-9][a-z0-9-]*$".to_owned());
    let mut prefix = key(
        "probe.branch_prefix",
        "string",
        "\"claude/nix-probe\"",
        "`probe`",
    );
    prefix.rule = Some("shell".to_owned());
    assert_eq!(
        schema(JQ),
        Ok(vec![
            model,
            key("session.agent_home", "boolean", "false", "`guide`"),
            domains,
            cache,
            prefix,
        ])
    );
}

/// dev:V1: a schema that reads empty or incomplete is an error.
#[test]
fn a_missing_or_incomplete_schema_is_refused() {
    assert!(schema("def defaults: {};\n").is_err());
    assert!(schema("def schema: {};\n").is_err());
    let err = schema(r#"def schema: {t: {k: {type: "string", readers: "x"}}};"#)
        .err()
        .unwrap_or_default();
    assert!(err.contains("t.k"), "{err}");
}

#[test]
fn the_table_says_each_type_in_words() {
    let block = table(&schema(JQ).unwrap_or_default()).unwrap_or_default();
    assert!(
        block.starts_with("<!-- BEGIN config: generated from scripts/config.jq by `claudinix-dev config --write`; do not edit -->\n"),
        "{block}"
    );
    assert!(block.ends_with("\n<!-- END config -->\n"), "{block}");
    let rows = [
        "| key | type | default | read by |",
        "|---|---|---|---|",
        "| `version` | the number `1` | none; required in a file | every reader (the file is refused without it) |",
        "| `session.model` | `\"sonnet\"` or `\"opus\"` | `\"sonnet\"` | `guide`, `probe` |",
        "| `session.agent_home` | `true` or `false` | `false` | `guide` |",
        "| `network.extra_domains` | list of bare hostnames | `[]` | `domains` |",
        "| `cache.name` | string matching `^[a-z0-9][a-z0-9-]*$` | `\"pr0d1r2\"` | `inputs` |",
        "| `probe.branch_prefix` | string, no whitespace, quote, backtick or control character | `\"claude/nix-probe\"` | `probe` |",
    ];
    for row in rows {
        assert!(block.contains(&format!("{row}\n")), "{row}\n{block}");
    }
}

#[test]
fn a_type_the_table_cannot_say_is_refused() {
    let odd = [key("t.k", "number", "1", "x")];
    assert!(table(&odd).is_err());
    let mut rule = key("t.k", "string", "\"\"", "x");
    rule.rule = Some("new".to_owned());
    assert!(table(&[rule]).is_err());
}
