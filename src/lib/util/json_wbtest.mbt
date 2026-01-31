// escape_json_string tests

test "escape_json_string - no escaping needed" {
  assert_eq(escape_json_string("hello"), "hello")
}

test "escape_json_string - double quote" {
  assert_eq(escape_json_string("say \"hello\""), "say \\\"hello\\\"")
}

test "escape_json_string - backslash" {
  assert_eq(escape_json_string("path\\to\\file"), "path\\\\to\\\\file")
}

test "escape_json_string - newline" {
  assert_eq(escape_json_string("line1\nline2"), "line1\\nline2")
}

test "escape_json_string - carriage return" {
  assert_eq(escape_json_string("line1\rline2"), "line1\\rline2")
}

test "escape_json_string - tab" {
  assert_eq(escape_json_string("col1\tcol2"), "col1\\tcol2")
}

test "escape_json_string - backspace" {
  assert_eq(escape_json_string("back\u0008space"), "back\\bspace")
}

test "escape_json_string - form feed" {
  assert_eq(escape_json_string("form\u000Cfeed"), "form\\ffeed")
}

test "escape_json_string - null character" {
  assert_eq(escape_json_string("null\u0000char"), "null\\u0000char")
}

test "escape_json_string - control character" {
  // U+001F is a control character
  assert_eq(escape_json_string("ctrl\u001Fchar"), "ctrl\\u001fchar")
}

test "escape_json_string - mixed escapes" {
  let input = "line1\nline2\t\"quoted\"\\"
  let expected = "line1\\nline2\\t\\\"quoted\\\"\\\\"
  assert_eq(escape_json_string(input), expected)
}

test "escape_json_string - empty string" {
  assert_eq(escape_json_string(""), "")
}

test "escape_json_string - unicode preserved" {
  // Non-control unicode should not be escaped
  assert_eq(escape_json_string("日本語"), "日本語")
  assert_eq(escape_json_string("emoji 🎉"), "emoji 🎉")
}

// json_string tests

test "json_string - simple" {
  assert_eq(json_string("hello"), "\"hello\"")
}

test "json_string - with escapes" {
  assert_eq(json_string("say \"hi\""), "\"say \\\"hi\\\"\"")
}

test "json_string - empty" {
  assert_eq(json_string(""), "\"\"")
}

// build_json_object tests

test "build_json_object - empty" {
  let pairs : Array[(String, String)] = []
  assert_eq(build_json_object(pairs), "{}")
}

test "build_json_object - single pair" {
  let pairs = [("name", "\"John\"")]
  assert_eq(build_json_object(pairs), "{\"name\":\"John\"}")
}

test "build_json_object - multiple pairs" {
  let pairs = [("name", "\"John\""), ("age", "30"), ("active", "true")]
  assert_eq(build_json_object(pairs), "{\"name\":\"John\",\"age\":30,\"active\":true}")
}

test "build_json_object - nested object" {
  let inner = build_json_object([("x", "1"), ("y", "2")])
  let outer = build_json_object([("point", inner)])
  assert_eq(outer, "{\"point\":{\"x\":1,\"y\":2}}")
}

test "build_json_object - key with special characters is escaped" {
  let pairs = [("key\"with\"quotes", "\"value\"")]
  let result = build_json_object(pairs)
  assert_eq(result, "{\"key\\\"with\\\"quotes\":\"value\"}")
}

test "build_json_object - key with newline is escaped" {
  let pairs = [("key\nwith\nnewlines", "\"value\"")]
  let result = build_json_object(pairs)
  assert_eq(result, "{\"key\\nwith\\nnewlines\":\"value\"}")
}

// build_json_array tests

test "build_json_array - empty" {
  let items : Array[String] = []
  assert_eq(build_json_array(items), "[]")
}

test "build_json_array - single item" {
  let items = ["\"hello\""]
  assert_eq(build_json_array(items), "[\"hello\"]")
}

test "build_json_array - multiple items" {
  let items = ["1", "2", "3"]
  assert_eq(build_json_array(items), "[1,2,3]")
}

test "build_json_array - mixed types" {
  let items = ["\"string\"", "42", "true", "null"]
  assert_eq(build_json_array(items), "[\"string\",42,true,null]")
}

// Integration tests

test "json output - realistic example" {
  let version_info = build_json_object([
    ("old_version", json_string("1.0.0")),
    ("new_version", json_string("1.1.0")),
    ("bump_type", json_string("minor")),
    ("commits_count", "5"),
    ("dry_run", "false"),
  ])
  assert_true(version_info.contains("\"old_version\":\"1.0.0\""))
  assert_true(version_info.contains("\"new_version\":\"1.1.0\""))
  assert_true(version_info.contains("\"bump_type\":\"minor\""))
  assert_true(version_info.contains("\"commits_count\":5"))
  assert_true(version_info.contains("\"dry_run\":false"))
}

test "json output - error message with special chars" {
  let error_msg = "Error: file \"config.json\" not found\nPath: /home/user"
  let json_error = build_json_object([
    ("error", json_string(error_msg)),
  ])
  assert_true(json_error.contains("\\\"config.json\\\""))
  assert_true(json_error.contains("\\n"))
}
