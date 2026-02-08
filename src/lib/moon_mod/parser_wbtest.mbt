test "parse simple moon.mod.json" {
  let content =
    #|{
    #|  "name": "my-package",
    #|  "version": "1.0.0"
    #|}
  let result = try { parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(result.name, "my-package")
  assert_eq(result.version, "1.0.0")
  assert_eq(result.deps, None)
}

test "parse moon.mod.json with deps" {
  let content =
    #|{
    #|  "name": "my-package",
    #|  "version": "1.2.3",
    #|  "deps": {
    #|    "moonbitlang/core": "0.1.0",
    #|    "other/pkg": "2.0.0"
    #|  }
    #|}
  let result = try { parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(result.name, "my-package")
  assert_eq(result.version, "1.2.3")
  match result.deps {
    Some(deps) => {
      assert_eq(deps.get("moonbitlang/core"), Some("0.1.0"))
      assert_eq(deps.get("other/pkg"), Some("2.0.0"))
    }
    None => fail("Expected deps")
  }
}

test "parse invalid json" {
  let content = "not json"
  try {
    let _ = parse(content)
    fail("Expected error")
  } catch {
    ParseError(_) => ()
    _ => fail("Wrong error type")
  }
}

test "parse missing name" {
  let content =
    #|{
    #|  "version": "1.0.0"
    #|}
  try {
    let _ = parse(content)
    fail("Expected error")
  } catch {
    ParseError(msg) => assert_true(msg.contains("name"))
    _ => fail("Wrong error type")
  }
}

test "parse missing version" {
  let content =
    #|{
    #|  "name": "my-package"
    #|}
  try {
    let _ = parse(content)
    fail("Expected error")
  } catch {
    ParseError(msg) => assert_true(msg.contains("version"))
    _ => fail("Wrong error type")
  }
}

test "update version" {
  let content =
    #|{
    #|  "name": "my-package",
    #|  "version": "1.0.0"
    #|}
  let new_version = @semver.Version::parse("2.0.0")
  match new_version {
    Some(v) => {
      let result = try { update_version(content, v) } catch { _ => fail("Unexpected error") }
      assert_true(result.contains("\"2.0.0\""))
      assert_true(result.contains("\"my-package\""))
    }
    None => fail("Failed to parse version")
  }
}

// replace_json_field tests for package.json-style JSON

test "replace_json_field - package.json style" {
  let content =
    #|{
    #|  "name": "my-npm-package",
    #|  "version": "1.0.0",
    #|  "description": "A package"
    #|}
  let result = try { replace_json_field(content, "version", "2.0.0") } catch { _ => fail("Unexpected error") }
  assert_true(result.contains("\"version\": \"2.0.0\""))
  assert_true(result.contains("\"my-npm-package\""))
  assert_true(result.contains("\"A package\""))
}

test "replace_json_field - preserves formatting and indentation" {
  let content =
    #|{
    #|    "name": "pkg",
    #|    "version": "0.1.0",
    #|    "main": "index.js"
    #|}
  let result = try { replace_json_field(content, "version", "0.2.0") } catch { _ => fail("Unexpected error") }
  // The value should be replaced, but the key + surrounding structure preserved
  assert_true(result.contains("\"0.2.0\""))
  assert_true(result.contains("\"pkg\""))
  assert_true(result.contains("\"index.js\""))
}

test "replace_json_field - rejects special characters in value" {
  let content =
    #|{
    #|  "name": "pkg",
    #|  "version": "1.0.0"
    #|}
  // Quotes in value should be rejected
  try {
    let _ = replace_json_field(content, "version", "1.0.0\"bad")
    fail("Expected error")
  } catch {
    ParseError(msg) => assert_true(msg.contains("Invalid character"))
    _ => fail("Wrong error type")
  }
  // Backslash in value should be rejected
  try {
    let _ = replace_json_field(content, "version", "1.0.0\\bad")
    fail("Expected error")
  } catch {
    ParseError(msg) => assert_true(msg.contains("Invalid character"))
    _ => fail("Wrong error type")
  }
}

test "replace_json_field - field not found" {
  let content =
    #|{
    #|  "name": "pkg",
    #|  "version": "1.0.0"
    #|}
  try {
    let _ = replace_json_field(content, "nonexistent", "value")
    fail("Expected error")
  } catch {
    ParseError(msg) => assert_true(msg.contains("not found"))
    _ => fail("Wrong error type")
  }
}

// H-1: "version" appearing inside a string value should not be matched as key
test "update version - version in value string" {
  let content =
    #|{
    #|  "name": "my-version-checker",
    #|  "version": "1.0.0",
    #|  "description": "checks version compatibility"
    #|}
  let new_version = @semver.Version::parse("2.0.0")
  match new_version {
    Some(v) => {
      let result = try { update_version(content, v) } catch { _ => fail("Unexpected error") }
      // The key "version" should be updated, not the "version" in "my-version-checker"
      assert_true(result.contains("\"2.0.0\""))
      assert_true(result.contains("\"my-version-checker\""))
    }
    None => fail("Failed to parse version")
  }
}
