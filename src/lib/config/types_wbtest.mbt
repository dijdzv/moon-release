test "default config" {
  let config = Config::default()
  assert_eq(config.pr_title, "chore: release v{{ version }}")
  assert_eq(config.allow_prerelease, false)
  assert_eq(config.git_tag_enable, true)
  assert_eq(config.git_release_enable, true)
  assert_eq(config.moon_publish, true)
  assert_eq(config.npm_publish, false)
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
    #|  "moon_publish": false,
    #|  "npm_publish": true
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.allow_prerelease, true)
  assert_eq(config.git_tag_enable, false)
  assert_eq(config.git_release_enable, false)
  assert_eq(config.moon_publish, false)
  assert_eq(config.npm_publish, true)
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

test "default config - new options" {
  let config = Config::default()
  assert_eq(config.git_release_latest, true)
  assert_eq(config.moon_publish_timeout, 300U)
  assert_eq(config.npm_publish_timeout, 300U)
  assert_eq(config.max_analyze_commits, None)
  assert_eq(config.custom_major_increment_regex, None)
  assert_eq(config.custom_minor_increment_regex, None)
  assert_eq(config.pr_labels, [])
}

test "parse config with git_release_latest false" {
  let content =
    #|{
    #|  "git_release_latest": false
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.git_release_latest, false)
}

test "parse config with moon_publish_timeout" {
  let content =
    #|{
    #|  "moon_publish_timeout": 600
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.moon_publish_timeout, 600U)
}

test "parse config with npm_publish_timeout" {
  let content =
    #|{
    #|  "npm_publish_timeout": 120
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.npm_publish_timeout, 120U)
}

test "parse config with max_analyze_commits" {
  let content =
    #|{
    #|  "max_analyze_commits": 100
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.max_analyze_commits, Some(100U))
}

test "parse config with max_analyze_commits null" {
  let content =
    #|{
    #|  "max_analyze_commits": null
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.max_analyze_commits, None)
}

test "parse config with pr_labels" {
  let content =
    #|{
    #|  "pr_labels": ["release", "automated"]
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.pr_labels.length(), 2)
  assert_eq(config.pr_labels[0], "release")
  assert_eq(config.pr_labels[1], "automated")
}

test "parse config with custom_major_increment_regex" {
  let content =
    #|{
    #|  "custom_major_increment_regex": "BREAKING"
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.custom_major_increment_regex, Some("BREAKING"))
}

test "parse config with custom_minor_increment_regex" {
  let content =
    #|{
    #|  "custom_minor_increment_regex": "NEW FEATURE"
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.custom_minor_increment_regex, Some("NEW FEATURE"))
}

test "parse config with invalid pattern - regex metacharacter" {
  let content =
    #|{
    #|  "custom_major_increment_regex": "^break:"
    #|}
  let result : Config? = try {
    Some(Config::parse(content))
  } catch {
    _ => None
  }
  assert_true(result is None)
}

test "parse config with invalid pattern - empty string" {
  let content =
    #|{
    #|  "custom_minor_increment_regex": ""
    #|}
  let result : Config? = try {
    Some(Config::parse(content))
  } catch {
    _ => None
  }
  assert_true(result is None)
}

test "parse invalid moon_publish_timeout - negative" {
  let content =
    #|{
    #|  "moon_publish_timeout": -1
    #|}
  try {
    let _ = Config::parse(content)
    fail("Expected error")
  } catch {
    ConfigError(_) => ()
    _ => fail("Wrong error type")
  }
}

test "parse invalid pr_labels - not array" {
  let content =
    #|{
    #|  "pr_labels": "not an array"
    #|}
  try {
    let _ = Config::parse(content)
    fail("Expected error")
  } catch {
    ConfigError(_) => ()
    _ => fail("Wrong error type")
  }
}

test "parse invalid pr_labels - not strings" {
  let content =
    #|{
    #|  "pr_labels": [1, 2, 3]
    #|}
  try {
    let _ = Config::parse(content)
    fail("Expected error")
  } catch {
    ConfigError(_) => ()
    _ => fail("Wrong error type")
  }
}

test "parse config with packages" {
  let content =
    #|{
    #|  "packages": [
    #|    {"name": "core", "path": "packages/core"},
    #|    {"name": "cli", "path": "packages/cli", "moon_publish": false, "npm_publish": true}
    #|  ]
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.packages.length(), 2)
  assert_eq(config.packages[0].name, "core")
  assert_eq(config.packages[0].path, "packages/core")
  assert_eq(config.packages[0].moon_publish, true)
  assert_eq(config.packages[0].npm_publish, false)
  assert_eq(config.packages[1].name, "cli")
  assert_eq(config.packages[1].moon_publish, false)
  assert_eq(config.packages[1].npm_publish, true)
}

test "parse config with packages - version_group" {
  let content =
    #|{
    #|  "packages": [
    #|    {"name": "pkg1", "version_group": "main"},
    #|    {"name": "pkg2", "version_group": "main"}
    #|  ]
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.packages[0].version_group, Some("main"))
  assert_eq(config.packages[1].version_group, Some("main"))
}

test "parse invalid packages - missing name" {
  let content =
    #|{
    #|  "packages": [
    #|    {"path": "packages/core"}
    #|  ]
    #|}
  try {
    let _ = Config::parse(content)
    fail("Expected error")
  } catch {
    ConfigError(msg) => assert_true(msg.contains("name"))
    _ => fail("Wrong error type")
  }
}

test "parse invalid packages - not array" {
  let content =
    #|{
    #|  "packages": "not an array"
    #|}
  try {
    let _ = Config::parse(content)
    fail("Expected error")
  } catch {
    ConfigError(_) => ()
    _ => fail("Wrong error type")
  }
}

test "parse config with all new options" {
  let content =
    #|{
    #|  "git_release_latest": false,
    #|  "moon_publish_timeout": 120,
    #|  "npm_publish_timeout": 60,
    #|  "max_analyze_commits": 50,
    #|  "allow_dirty": true,
    #|  "registry_check": true
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.git_release_latest, false)
  assert_eq(config.moon_publish_timeout, 120U)
  assert_eq(config.npm_publish_timeout, 60U)
  assert_eq(config.max_analyze_commits, Some(50U))
  assert_eq(config.allow_dirty, true)
  assert_eq(config.registry_check, true)
}

test "PackageConfig::default" {
  let pkg = PackageConfig::default("my-package", "packages/my-package")
  assert_eq(pkg.name, "my-package")
  assert_eq(pkg.path, "packages/my-package")
  assert_eq(pkg.moon_publish, true)
  assert_eq(pkg.npm_publish, false)
  assert_eq(pkg.version_group, None)
}

test "ConfigError::to_string" {
  let err = ConfigError("Something went wrong")
  assert_eq(err.to_string(), "Something went wrong")
}

// UInt overflow boundary tests

test "parse config with moon_publish_timeout - large valid value" {
  // Large but valid value (within safe Double range for integer precision)
  let content =
    #|{
    #|  "moon_publish_timeout": 1000000000
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.moon_publish_timeout, 1000000000U)
}

test "parse config with moon_publish_timeout - overflow rejected" {
  // 4294967296 exceeds UInt max, should be rejected
  let content =
    #|{
    #|  "moon_publish_timeout": 4294967296
    #|}
  try {
    let _ = Config::parse(content)
    fail("Expected error for overflow value")
  } catch {
    ConfigError(msg) => assert_true(msg.contains("too large"))
    _ => fail("Wrong error type")
  }
}

test "parse config with moon_publish_timeout - float rejected" {
  // Non-integer values should be rejected
  let content =
    #|{
    #|  "moon_publish_timeout": 300.5
    #|}
  try {
    let _ = Config::parse(content)
    fail("Expected error for float value")
  } catch {
    ConfigError(msg) => assert_true(msg.contains("integer"))
    _ => fail("Wrong error type")
  }
}

test "parse config with max_analyze_commits - large valid value" {
  // Large but valid value (within safe Double range for integer precision)
  let content =
    #|{
    #|  "max_analyze_commits": 1000000000
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.max_analyze_commits, Some(1000000000U))
}

test "parse config with max_analyze_commits - overflow rejected" {
  let content =
    #|{
    #|  "max_analyze_commits": 4294967296
    #|}
  try {
    let _ = Config::parse(content)
    fail("Expected error for overflow value")
  } catch {
    ConfigError(msg) => assert_true(msg.contains("too large"))
    _ => fail("Wrong error type")
  }
}

// npm publish configuration tests

test "default config - npm_publish disabled" {
  let config = Config::default()
  assert_eq(config.npm_publish, false)
  assert_eq(config.npm_build_command, None)
  assert_eq(config.npm_publish_timeout, 300U)
}

test "parse config with npm_publish enabled" {
  let content =
    #|{
    #|  "npm_publish": true
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.npm_publish, true)
}

test "parse config with npm_build_command" {
  let content =
    #|{
    #|  "npm_build_command": "npm run build"
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.npm_build_command, Some("npm run build"))
}

test "parse config with npm_build_command null" {
  let content =
    #|{
    #|  "npm_build_command": null
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.npm_build_command, None)
}

test "parse config with npm_publish_timeout custom" {
  let content =
    #|{
    #|  "npm_publish_timeout": 600
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.npm_publish_timeout, 600U)
}

test "parse config with all npm options" {
  let content =
    #|{
    #|  "npm_publish": true,
    #|  "npm_build_command": "moon build --target js",
    #|  "npm_publish_timeout": 180
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.npm_publish, true)
  assert_eq(config.npm_build_command, Some("moon build --target js"))
  assert_eq(config.npm_publish_timeout, 180U)
}

test "parse config with packages - npm_build_command" {
  let content =
    #|{
    #|  "packages": [
    #|    {"name": "pkg1", "npm_publish": true, "npm_build_command": "npm run build:pkg1"}
    #|  ]
    #|}
  let config = try { Config::parse(content) } catch { _ => fail("Unexpected error") }
  assert_eq(config.packages.length(), 1)
  assert_eq(config.packages[0].npm_publish, true)
  assert_eq(config.packages[0].npm_build_command, Some("npm run build:pkg1"))
}

test "PackageConfig::default - npm options" {
  let pkg = PackageConfig::default("my-package", "packages/my")
  assert_eq(pkg.npm_publish, false)
  assert_eq(pkg.npm_build_command, None)
}
