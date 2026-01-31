test "default config" {
  let config = Config::default()
  assert_eq(config.pr_title, "chore: release v{{ version }}")
  assert_eq(config.allow_prerelease, false)
  assert_eq(config.git_tag_enable, true)
  assert_eq(config.git_release_enable, true)
  assert_eq(config.publish, true)
}

test "parse empty config uses defaults" {
  let config = try { Config::parse("") } catch { _ => fail("Unexpected error") }
  assert_eq(config, Config::default())
}

test "parse config with pr_title" {
  let content =
    #|{
    #|  "pr_title": "release: v{{ version }}"
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.pr_title, "release: v{{ version }}")
  // Other fields use defaults
  assert_eq(config.git_release_enable, true)
}

test "parse config with git_tag_enable" {
  let content =
    #|{
    #|  "git_tag_enable": false
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.git_tag_enable, false)
}

test "parse config with git_release_body" {
  let content =
    #|{
    #|  "git_release_body": "Custom body {{ version }}"
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.git_release_body, Some("Custom body {{ version }}"))
}

test "parse config with booleans" {
  let content =
    #|{
    #|  "allow_prerelease": true,
    #|  "git_tag_enable": false,
    #|  "git_release_enable": false,
    #|  "publish": false
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.allow_prerelease, true)
  assert_eq(config.git_tag_enable, false)
  assert_eq(config.git_release_enable, false)
  assert_eq(config.publish, false)
}

test "parse invalid json" {
  let content = "not json"
  try {
    let _ = Config::parse(content)
    fail("Expected error")
  } catch {
    ConfigError(_) => ()
    _ => fail("Wrong error type")
  }
}

test "apply version template" {
  let config = Config::default()
  let result = config.apply_version_template("1.2.3")
  assert_eq(result, "chore: release v1.2.3")
}
