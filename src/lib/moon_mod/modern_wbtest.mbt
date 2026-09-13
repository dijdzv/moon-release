///|
test "moon.mod updates only the top-level version literal" {
  let content =
    #|// version = "9.9.9"
    #|name = "owner/日本語"
    #|metadata = { version: "8.8.8" }
    #|version = "1.2.3" // preserve this comment
    #|import { "owner/dep@4.5.6" }
    #|description = "version = \"7.7.7\""
  let parsed = parse(content)
  assert_eq(parsed.name, "owner/日本語")
  assert_eq(parsed.version, "1.2.3")
  let updated = update_version(content, @semver.Version::parse("2.0.0").unwrap())
  assert_eq(updated, content.replace_all(old="version = \"1.2.3\"", new="version = \"2.0.0\""))
}

///|
test "moon.mod accepts name without version for name lookup" {
  assert_eq(read_name("name = \"owner/package\"\n"), "owner/package")
}

///|
test "moon.mod duplicate versions are rejected" {
  let result = try? parse("name = \"x/y\"\nversion = \"1.0.0\"\nversion = \"2.0.0\"")
  assert_true(result is Err(_))
}
