//! The reader takes every JSON value and refuses anything else.

use super::{Json, parse};

#[test]
fn scalars_parse() {
    assert_eq!(parse("null"), Some(Json::Null));
    assert_eq!(parse(" true "), Some(Json::Bool(true)));
    assert_eq!(parse("false"), Some(Json::Bool(false)));
    assert_eq!(parse("7"), Some(Json::Num("7".to_owned())));
    assert_eq!(parse("-1.5e3"), Some(Json::Num("-1.5e3".to_owned())));
    assert_eq!(parse("\"a\""), Some(Json::Str("a".to_owned())));
}

#[test]
fn strings_unescape() {
    let text = r#""q\" b\\ s\/ n\n t\t u\u00e9 \ud83d\ude00""#;
    assert_eq!(
        parse(text),
        Some(Json::Str("q\" b\\ s/ n\n t\t u\u{e9} \u{1f600}".to_owned()))
    );
}

#[test]
fn nested_values_keep_their_order() {
    let value = parse("{\"b\": [1, {\"c\": \"d\"}, []], \"a\": {}}").unwrap_or(Json::Null);
    let keys: Vec<&str> = value.members().iter().map(|(k, _)| k.as_str()).collect();
    assert_eq!(keys, ["b", "a"]);
    assert_eq!(
        value.get("b"),
        Some(&Json::Arr(vec![
            Json::Num("1".to_owned()),
            Json::Obj(vec![("c".to_owned(), Json::Str("d".to_owned()))]),
            Json::Arr(Vec::new()),
        ]))
    );
    assert_eq!(value.get("a"), Some(&Json::Obj(Vec::new())));
    assert_eq!(value.get("z"), None);
}

#[test]
fn accessors_answer_only_for_their_kind() {
    let text = Json::Str("x".to_owned());
    assert_eq!(text.as_str(), Some("x"));
    assert_eq!(text.get("x"), None);
    assert!(text.members().is_empty());
    assert_eq!(Json::Null.as_str(), None);
}

#[test]
fn anything_else_is_refused() {
    for bad in [
        "",
        "{",
        "[1,]",
        "{\"a\" 1}",
        "{\"a\": 1,}",
        "\"open",
        "truthy",
        "1 2",
        "{} x",
        "\"\\x\"",
        "[01]",
    ] {
        assert_eq!(parse(bad), None, "{bad:?} must be refused");
    }
}
