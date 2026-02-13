///|
test "default config" {
  let config = Config::default()
  assert_eq(config.pr_title, "chore: release v{{ version }}")
  assert_eq(config.allow_prerelease, false)
  assert_eq(config.git_tag_enable, true)
  assert_eq(config.git_release_enable, true)
  assert_eq(config.moon_publish, true)
  assert_eq(config.npm_publish, false)
}

///|
test "parse empty config uses defaults" {
  let config = Config::parse("") catch { _ => fail("Unexpected error") }
  assert_eq(config, Config::default())
}

///|
test "parse config with pr_title" {
  let content =
    #|{
    #|  "pr_title": "release: v{{ version }}"
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.pr_title, "release: v{{ version }}")
  // Other fields use defaults
  assert_eq(config.git_release_enable, true)
}

///|
test "parse config with git_tag_enable" {
  let content =
    #|{
    #|  "git_tag_enable": false
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.git_tag_enable, false)
}

///|
test "parse config with git_release_body" {
  let content =
    #|{
    #|  "git_release_body": "Custom body {{ version }}"
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.git_release_body, Some("Custom body {{ version }}"))
}

///|
test "parse config with booleans" {
  let content =
    #|{
    #|  "allow_prerelease": true,
    #|  "git_tag_enable": false,
    #|  "git_release_enable": false,
    #|  "moon_publish": false,
    #|  "npm_publish": true
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.allow_prerelease, true)
  assert_eq(config.git_tag_enable, false)
  assert_eq(config.git_release_enable, false)
  assert_eq(config.moon_publish, false)
  assert_eq(config.npm_publish, true)
}

///|
test "parse invalid json" {
  let content = "not json"
  try {
    let _ = Config::parse(content)
    fail("Expected error")
  } catch {
    ConfigError(msg) =>
      assert_true(msg.contains("JSON") || msg.contains("parse"))
    _ => fail("Wrong error type")
  }
}

///|
test "apply PR title template" {
  let config = Config::default()
  let result = config.apply_pr_title_template("1.2.3")
  assert_eq(result, "chore: release v1.2.3")
}

///|
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

///|
test "parse config with git_release_latest false" {
  let content =
    #|{
    #|  "git_release_latest": false
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.git_release_latest, false)
}

///|
test "parse config with moon_publish_timeout" {
  let content =
    #|{
    #|  "moon_publish_timeout": 600
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.moon_publish_timeout, 600U)
}

///|
test "parse config with npm_publish_timeout" {
  let content =
    #|{
    #|  "npm_publish_timeout": 120
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.npm_publish_timeout, 120U)
}

///|
test "parse config with max_analyze_commits" {
  let content =
    #|{
    #|  "max_analyze_commits": 100
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.max_analyze_commits, Some(100U))
}

///|
test "parse config with max_analyze_commits null" {
  let content =
    #|{
    #|  "max_analyze_commits": null
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.max_analyze_commits, None)
}

///|
test "parse config with pr_labels" {
  let content =
    #|{
    #|  "pr_labels": ["release", "automated"]
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.pr_labels.length(), 2)
  assert_eq(config.pr_labels[0], "release")
  assert_eq(config.pr_labels[1], "automated")
}

///|
test "parse config with custom_major_increment_regex" {
  let content =
    #|{
    #|  "custom_major_increment_regex": "BREAKING"
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.custom_major_increment_regex, Some("BREAKING"))
}

///|
test "parse config with custom_minor_increment_regex" {
  let content =
    #|{
    #|  "custom_minor_increment_regex": "NEW FEATURE"
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.custom_minor_increment_regex, Some("NEW FEATURE"))
}

///|
test "parse config with invalid pattern - regex metacharacter" {
  let content =
    #|{
    #|  "custom_major_increment_regex": "^break:"
    #|}
  let result : Config? = Some(Config::parse(content)) catch { _ => None }
  assert_true(result is None)
}

///|
test "parse config with invalid pattern - empty string" {
  let content =
    #|{
    #|  "custom_minor_increment_regex": ""
    #|}
  let result : Config? = Some(Config::parse(content)) catch { _ => None }
  assert_true(result is None)
}

///|
test "parse invalid moon_publish_timeout - negative" {
  let content =
    #|{
    #|  "moon_publish_timeout": -1
    #|}
  try {
    let _ = Config::parse(content)
    fail("Expected error")
  } catch {
    ConfigError(msg) => assert_true(msg.contains("positive integer"))
    _ => fail("Wrong error type")
  }
}

///|
test "parse invalid pr_labels - not array" {
  let content =
    #|{
    #|  "pr_labels": "not an array"
    #|}
  try {
    let _ = Config::parse(content)
    fail("Expected error")
  } catch {
    ConfigError(msg) => assert_true(msg.contains("array"))
    _ => fail("Wrong error type")
  }
}

///|
test "parse invalid pr_labels - not strings" {
  let content =
    #|{
    #|  "pr_labels": [1, 2, 3]
    #|}
  try {
    let _ = Config::parse(content)
    fail("Expected error")
  } catch {
    ConfigError(msg) => assert_true(msg.contains("string"))
    _ => fail("Wrong error type")
  }
}

///|
test "parse config with packages" {
  let content =
    #|{
    #|  "packages": [
    #|    {"name": "core", "path": "packages/core"},
    #|    {"name": "cli", "path": "packages/cli", "moon_publish": false, "npm_publish": true}
    #|  ]
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.packages.length(), 2)
  assert_eq(config.packages[0].name, "core")
  assert_eq(config.packages[0].path, "packages/core")
  assert_eq(config.packages[0].moon_publish, true)
  assert_eq(config.packages[0].npm_publish, false)
  assert_eq(config.packages[1].name, "cli")
  assert_eq(config.packages[1].moon_publish, false)
  assert_eq(config.packages[1].npm_publish, true)
}

///|
test "parse config with packages - version_group" {
  let content =
    #|{
    #|  "packages": [
    #|    {"name": "pkg1", "version_group": "main"},
    #|    {"name": "pkg2", "version_group": "main"}
    #|  ]
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.packages[0].version_group, Some("main"))
  assert_eq(config.packages[1].version_group, Some("main"))
}

///|
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

///|
test "parse invalid packages - not array" {
  let content =
    #|{
    #|  "packages": "not an array"
    #|}
  try {
    let _ = Config::parse(content)
    fail("Expected error")
  } catch {
    ConfigError(msg) => assert_true(msg.contains("array"))
    _ => fail("Wrong error type")
  }
}

///|
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
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.git_release_latest, false)
  assert_eq(config.moon_publish_timeout, 120U)
  assert_eq(config.npm_publish_timeout, 60U)
  assert_eq(config.max_analyze_commits, Some(50U))
  assert_eq(config.allow_dirty, true)
  assert_eq(config.registry_check, true)
}

///|
test "PackageConfig::default" {
  let pkg = PackageConfig::default("my-package", "packages/my-package")
  assert_eq(pkg.name, "my-package")
  assert_eq(pkg.path, "packages/my-package")
  assert_eq(pkg.moon_publish, true)
  assert_eq(pkg.npm_publish, false)
  assert_eq(pkg.version_group, None)
}

///|
test "ConfigError::to_string" {
  let err = ConfigError("Something went wrong")
  assert_eq(err.to_string(), "Something went wrong")
}

// UInt overflow boundary tests

///|
test "parse config with moon_publish_timeout - large valid value" {
  // Large but valid value (within safe Double range for integer precision)
  let content =
    #|{
    #|  "moon_publish_timeout": 1000000000
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.moon_publish_timeout, 1000000000U)
}

///|
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

///|
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

///|
test "parse config with max_analyze_commits - large valid value" {
  // Large but valid value (within safe Double range for integer precision)
  let content =
    #|{
    #|  "max_analyze_commits": 1000000000
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.max_analyze_commits, Some(1000000000U))
}

///|
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

///|
test "default config - npm_publish disabled" {
  let config = Config::default()
  assert_eq(config.npm_publish, false)
  assert_eq(config.npm_build_command, None)
  assert_eq(config.npm_publish_timeout, 300U)
}

///|
test "parse config with npm_publish enabled" {
  let content =
    #|{
    #|  "npm_publish": true
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.npm_publish, true)
}

///|
test "parse config with npm_build_command" {
  let content =
    #|{
    #|  "npm_build_command": "npm run build"
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.npm_build_command, Some("npm run build"))
}

///|
test "parse config with npm_build_command null" {
  let content =
    #|{
    #|  "npm_build_command": null
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.npm_build_command, None)
}

///|
test "parse config with npm_publish_timeout custom" {
  let content =
    #|{
    #|  "npm_publish_timeout": 600
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.npm_publish_timeout, 600U)
}

///|
test "parse config with all npm options" {
  let content =
    #|{
    #|  "npm_publish": true,
    #|  "npm_build_command": "moon build --target js",
    #|  "npm_publish_timeout": 180
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.npm_publish, true)
  assert_eq(config.npm_build_command, Some("moon build --target js"))
  assert_eq(config.npm_publish_timeout, 180U)
}

///|
test "parse config with packages - npm_build_command" {
  let content =
    #|{
    #|  "packages": [
    #|    {"name": "pkg1", "npm_publish": true, "npm_build_command": "npm run build:pkg1"}
    #|  ]
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.packages.length(), 1)
  assert_eq(config.packages[0].npm_publish, true)
  assert_eq(config.packages[0].npm_build_command, Some("npm run build:pkg1"))
}

///|
test "PackageConfig::default - npm options" {
  let pkg = PackageConfig::default("my-package", "packages/my")
  assert_eq(pkg.npm_publish, false)
  assert_eq(pkg.npm_build_command, None)
}

// M-12: npm_build_command shell injection validation tests

///|
test "parse config with npm_build_command - rejects semicolon" {
  let content =
    #|{
    #|  "npm_build_command": "npm run build; rm -rf /"
    #|}
  try {
    let _ = Config::parse(content)
    fail("Expected error for shell injection")
  } catch {
    ConfigError(msg) => assert_true(msg.contains("shell control characters"))
    _ => fail("Wrong error type")
  }
}

///|
test "parse config with npm_build_command - rejects pipe" {
  let content =
    #|{
    #|  "npm_build_command": "npm run build | cat /etc/passwd"
    #|}
  try {
    let _ = Config::parse(content)
    fail("Expected error for shell injection")
  } catch {
    ConfigError(msg) => assert_true(msg.contains("shell control characters"))
    _ => fail("Wrong error type")
  }
}

///|
test "parse config with npm_build_command - rejects ampersand" {
  let content =
    #|{
    #|  "npm_build_command": "npm run build && malicious"
    #|}
  try {
    let _ = Config::parse(content)
    fail("Expected error for shell injection")
  } catch {
    ConfigError(msg) => assert_true(msg.contains("shell control characters"))
    _ => fail("Wrong error type")
  }
}

///|
test "parse config with npm_build_command - rejects backtick" {
  let content =
    #|{
    #|  "npm_build_command": "npm run `whoami`"
    #|}
  try {
    let _ = Config::parse(content)
    fail("Expected error for shell injection")
  } catch {
    ConfigError(msg) => assert_true(msg.contains("shell control characters"))
    _ => fail("Wrong error type")
  }
}

///|
test "parse config with npm_build_command - rejects dollar sign" {
  let content =
    #|{
    #|  "npm_build_command": "npm run $HOME"
    #|}
  try {
    let _ = Config::parse(content)
    fail("Expected error for shell injection")
  } catch {
    ConfigError(msg) => assert_true(msg.contains("shell control characters"))
    _ => fail("Wrong error type")
  }
}

///|
test "parse config with npm_build_command - allows safe command" {
  let content =
    #|{
    #|  "npm_build_command": "moon build --target js --output-dir dist"
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(
    config.npm_build_command,
    Some("moon build --target js --output-dir dist"),
  )
}

///|
test "parse config with packages - npm_build_command rejects injection" {
  let content =
    #|{
    #|  "packages": [
    #|    {"name": "pkg1", "npm_build_command": "npm run build; evil"}
    #|  ]
    #|}
  try {
    let _ = Config::parse(content)
    fail("Expected error for shell injection in package")
  } catch {
    ConfigError(msg) => assert_true(msg.contains("shell control characters"))
    _ => fail("Wrong error type")
  }
}

// This test ensures that the hardcoded JSON in generate_default_config_json (main.mbt)
// stays in sync with Config::default(). If a new field is added to Config::default()
// but not reflected in the init JSON, the parsed config will differ.

///|
test "init JSON produces config matching defaults" {
  // This JSON mirrors generate_default_config_json() in main.mbt.
  // If Config::default() changes, update both this test and generate_default_config_json().
  let init_json =
    #|{
    #|  "pr_title": "chore: release v{{ version }}",
    #|  "pr_draft": false,
    #|  "pr_labels": [],
    #|  "pr_body": "## Release v{{ version }}\n\n{{ changelog }}\n\n---\n*This PR was automatically created by moon-release.*",
    #|  "pr_branch_prefix": "release/",
    #|  "base_branch": "main",
    #|  "allow_prerelease": false,
    #|  "git_tag_enable": true,
    #|  "git_tag_name": "v{{ version }}",
    #|  "git_release_enable": true,
    #|  "git_release_draft": false,
    #|  "git_release_name": "Release v{{ version }}",
    #|  "git_release_body": null,
    #|  "git_release_latest": true,
    #|  "moon_publish": true,
    #|  "moon_publish_frozen": false,
    #|  "moon_publish_timeout": 300,
    #|  "npm_publish": false,
    #|  "npm_publish_provenance": true,
    #|  "npm_publish_timeout": 300,
    #|  "semver_check": false,
    #|  "registry_check": false,
    #|  "allow_dirty": false,
    #|  "packages": []
    #|}
  let parsed = Config::parse(init_json) catch { _ => fail("Parse failed") }
  assert_eq(parsed, Config::default())
}

// ============================================================================
// Phase 2: ADT accessor method tests
// ============================================================================

///|
test "Config::publish_target - default is MooncakesOnly" {
  let config = Config::default()
  assert_true(config.publish_target() is MooncakesOnly)
}

///|
test "Config::publish_target - both enabled" {
  let content =
    #|{
    #|  "moon_publish": true,
    #|  "npm_publish": true,
    #|  "npm_build_command": "npm run build",
    #|  "npm_publish_provenance": false,
    #|  "npm_publish_timeout": 120
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  match config.publish_target() {
    Both(npm) => {
      assert_eq(npm.build_command, Some("npm run build"))
      assert_eq(npm.provenance, false)
      assert_eq(npm.timeout, 120U)
    }
    _ => fail("expected Both")
  }
}

///|
test "Config::publish_target - npm only" {
  let content =
    #|{
    #|  "moon_publish": false,
    #|  "npm_publish": true,
    #|  "npm_build_command": "webpack build",
    #|  "npm_publish_provenance": false,
    #|  "npm_publish_timeout": 60
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  match config.publish_target() {
    NpmOnly(npm) => {
      assert_eq(npm.build_command, Some("webpack build"))
      assert_eq(npm.provenance, false)
      assert_eq(npm.timeout, 60U)
    }
    _ => fail("expected NpmOnly")
  }
}

///|
test "Config::publish_target - no publish" {
  let content =
    #|{
    #|  "moon_publish": false,
    #|  "npm_publish": false
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_true(config.publish_target() is NoPublish)
}

///|
test "Config::git_release_mode - default is GitHubRelease" {
  let config = Config::default()
  match config.git_release_mode() {
    GitHubRelease(draft~, latest~) => {
      assert_eq(draft, false)
      assert_eq(latest, true)
    }
    _ => fail("expected GitHubRelease")
  }
}

///|
test "Config::git_release_mode - tag only" {
  let content =
    #|{
    #|  "git_tag_enable": true,
    #|  "git_release_enable": false
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_true(config.git_release_mode() is TagOnly)
}

///|
test "Config::git_release_mode - no git release" {
  let content =
    #|{
    #|  "git_tag_enable": false,
    #|  "git_release_enable": false
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_true(config.git_release_mode() is NoGitRelease)
}

///|
test "Config::git_release_mode - draft release" {
  let content =
    #|{
    #|  "git_release_draft": true,
    #|  "git_release_latest": false
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  match config.git_release_mode() {
    GitHubRelease(draft~, latest~) => {
      assert_eq(draft, true)
      assert_eq(latest, false)
    }
    _ => fail("expected GitHubRelease")
  }
}

///|
test "PackageConfig::publish_target - mooncakes only" {
  let pkg = PackageConfig::default("pkg", ".")
  assert_true(pkg.publish_target() is MooncakesOnly)
}

///|
test "PackageConfig::publish_target - npm only" {
  let pkg = PackageConfig::{
    name: "pkg",
    path: ".",
    moon_publish: false,
    npm_publish: true,
    npm_build_command: None,
    version_group: None,
  }
  assert_true(pkg.publish_target() is NpmOnly(_))
}

///|
test "NpmConfig::build_args - default" {
  let npm = NpmConfig::{ build_command: None, provenance: true, timeout: 300 }
  assert_eq(npm.build_args(), ["moon", "build", "--target", "js", "--release"])
}

///|
test "NpmConfig::build_args - custom" {
  let npm = NpmConfig::{
    build_command: Some("npm run build"),
    provenance: true,
    timeout: 300,
  }
  assert_eq(npm.build_args(), ["npm", "run", "build"])
}

///|
test "Config::parse collects unknown key warnings" {
  let content =
    #|{
    #|  "pr_title": "release: v{{ version }}",
    #|  "unknown_field": true,
    #|  "another_unknown": 42
    #|}
  let warnings : Array[String] = []
  let config = Config::parse(content, warnings~) catch {
    _ => fail("Unexpected error")
  }
  assert_eq(config.pr_title, "release: v{{ version }}")
  assert_eq(warnings.length(), 2)
  assert_true(warnings[0].contains("unknown_field"))
  assert_true(warnings[1].contains("another_unknown"))
}

///|
test "Config::parse no warnings for valid keys" {
  let content =
    #|{
    #|  "pr_title": "test",
    #|  "git_tag_enable": true
    #|}
  let warnings : Array[String] = []
  let _ = Config::parse(content, warnings~) catch {
    _ => fail("Unexpected error")
  }
  assert_eq(warnings.length(), 0)
}

// Additional config field parse tests

///|
test "parse config with bump_all_packages" {
  let content =
    #|{
    #|  "bump_all_packages": true
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.bump_all_packages, true)
}

///|
test "parse config with pr_branch_prefix" {
  let content =
    #|{
    #|  "pr_branch_prefix": "rel/"
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.pr_branch_prefix, "rel/")
}

///|
test "parse config with moon_publish_frozen" {
  let content =
    #|{
    #|  "moon_publish_frozen": true
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.moon_publish_frozen, true)
}

///|
test "parse config with pr_draft" {
  let content =
    #|{
    #|  "pr_draft": true
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.pr_draft, true)
}

///|
test "parse config with base_branch" {
  let content =
    #|{
    #|  "base_branch": "develop"
    #|}
  let config = Config::parse(content) catch { _ => fail("Unexpected error") }
  assert_eq(config.base_branch, "develop")
}
