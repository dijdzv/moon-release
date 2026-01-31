test "default config" {
  let config = Config::default()
  assert_eq(config.pr_title, "chore: release v{{ version }}")
  assert_eq(config.changelog_include.length(), 4)
  assert_eq(config.allow_prerelease, false)
  assert_eq(config.github_release, true)
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
  assert_eq(config.github_release, true)
}

test "parse config with changelog_include" {
  let content =
    #|{
    #|  "changelog_include": ["feat", "fix"]
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.changelog_include.length(), 2)
  assert_eq(config.changelog_include[0], "feat")
  assert_eq(config.changelog_include[1], "fix")
}

test "parse config with booleans" {
  let content =
    #|{
    #|  "allow_prerelease": true,
    #|  "github_release": false,
    #|  "publish": false
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.allow_prerelease, true)
  assert_eq(config.github_release, false)
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
