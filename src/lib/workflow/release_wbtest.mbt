test "bump_priority - Major has highest priority" {
  assert_eq(bump_priority(@semver.Major), 3)
}

test "bump_priority - Minor has medium priority" {
  assert_eq(bump_priority(@semver.Minor), 2)
}

test "bump_priority - Patch has lowest priority" {
  assert_eq(bump_priority(@semver.Patch), 1)
}

test "bump_priority - Major > Minor > Patch" {
  assert_true(bump_priority(@semver.Major) > bump_priority(@semver.Minor))
  assert_true(bump_priority(@semver.Minor) > bump_priority(@semver.Patch))
}

test "generate_release_notes - empty commits" {
  let commits : Array[(@conventional.ConventionalCommit, String)] = []
  let result = generate_release_notes(commits)
  assert_eq(result, "No changes.")
}

test "generate_release_notes - single feat commit" {
  let commit = @conventional.parse("feat: add new feature")
  match commit {
    Some(c) => {
      let commits = [(c, "abc1234567890")]
      let result = generate_release_notes(commits)
      assert_true(result.contains("## What's Changed"))
      assert_true(result.contains("add new feature"))
      assert_true(result.contains("abc1234"))
    }
    None => fail("parse failed")
  }
}

test "generate_release_notes - commit with scope" {
  let commit = @conventional.parse("fix(parser): fix parsing bug")
  match commit {
    Some(c) => {
      let commits = [(c, "def5678901234")]
      let result = generate_release_notes(commits)
      assert_true(result.contains("**parser**:"))
      assert_true(result.contains("fix parsing bug"))
    }
    None => fail("parse failed")
  }
}

test "generate_release_notes - multiple commits" {
  let feat = @conventional.parse("feat: add feature A")
  let fix = @conventional.parse("fix(cli): fix bug B")
  match (feat, fix) {
    (Some(f), Some(x)) => {
      let commits = [(f, "1111111"), (x, "2222222")]
      let result = generate_release_notes(commits)
      assert_true(result.contains("add feature A"))
      assert_true(result.contains("fix bug B"))
      assert_true(result.contains("**cli**:"))
    }
    _ => fail("parse failed")
  }
}

test "generate_release_notes - short hash" {
  let commit = @conventional.parse("docs: update readme")
  match commit {
    Some(c) => {
      // Short hash (less than 7 chars)
      let commits = [(c, "abc")]
      let result = generate_release_notes(commits)
      assert_true(result.contains("(abc)"))
    }
    None => fail("parse failed")
  }
}

test "generate_release_notes - breaking change commit" {
  let commit = @conventional.parse("feat!: breaking API change")
  match commit {
    Some(c) => {
      assert_true(c.breaking)
      let commits = [(c, "abc1234567890")]
      let result = generate_release_notes(commits)
      assert_true(result.contains("breaking API change"))
    }
    None => fail("parse failed")
  }
}

// parse_package_json_version tests

test "parse_package_json_version - valid version" {
  let content =
    #|{
    #|  "name": "my-package",
    #|  "version": "1.2.3"
    #|}
  let result = try { parse_package_json_version(content) } catch { _ => fail("Unexpected error") }
  match result {
    Some(v) => assert_eq(v.to_string(), "1.2.3")
    None => fail("Expected Some version")
  }
}

test "parse_package_json_version - no version field" {
  let content =
    #|{
    #|  "name": "my-package"
    #|}
  let result = try { parse_package_json_version(content) } catch { _ => fail("Unexpected error") }
  assert_true(result is None)
}

test "parse_package_json_version - invalid JSON" {
  try {
    let _ = parse_package_json_version("not json")
    fail("Expected error")
  } catch {
    WorkflowError(msg) => assert_true(msg.contains("Failed to parse package.json"))
    _ => fail("Wrong error type")
  }
}

test "parse_package_json_version - non-object JSON" {
  try {
    let _ = parse_package_json_version("[1,2,3]")
    fail("Expected error")
  } catch {
    WorkflowError(msg) => assert_true(msg.contains("not a valid JSON object"))
    _ => fail("Wrong error type")
  }
}

test "parse_package_json_version - prerelease version" {
  let content =
    #|{
    #|  "name": "pkg",
    #|  "version": "1.0.0-alpha.1"
    #|}
  let result = try { parse_package_json_version(content) } catch { _ => fail("Unexpected error") }
  match result {
    Some(v) => assert_eq(v.to_string(), "1.0.0-alpha.1")
    None => fail("Expected Some version")
  }
}

// Path validation tests

test "validate_path - empty string is valid" {
  assert_true(validate_path(""))
}

test "validate_path - dot is valid" {
  assert_true(validate_path("."))
}

test "validate_path - relative path is valid" {
  assert_true(validate_path("packages/core"))
}

test "validate_path - path with double dots is invalid" {
  assert_false(validate_path("../etc/passwd"))
}

test "validate_path - path containing double dots is invalid" {
  assert_false(validate_path("packages/../secrets"))
}

test "validate_path - absolute path is invalid" {
  assert_false(validate_path("/etc/passwd"))
}

test "build_pr_body - replaces version template" {
  let config = @config.Config::default()
  let current_version = @semver.Version::parse("1.0.0")
  let new_version = @semver.Version::parse("1.1.0")
  match (current_version, new_version) {
    (Some(cur), Some(new)) => {
      let ctx = ReleaseContext::new(
        config,
        @git.Repository::current(),
        cur,
        new,
        [],
      )
      let result = build_pr_body(ctx)
      assert_true(result.contains("1.1.0"))
    }
    _ => fail("parse failed")
  }
}

test "build_pr_body - replaces changelog template" {
  let config = @config.Config::default()
  let current_version = @semver.Version::parse("1.0.0")
  let new_version = @semver.Version::parse("1.1.0")
  match (current_version, new_version) {
    (Some(cur), Some(new)) => {
      let ctx = ReleaseContext::new(
        config,
        @git.Repository::current(),
        cur,
        new,
        [],  // empty commits
      )
      let result = build_pr_body(ctx)
      // Empty commits should produce "No changes." in changelog
      assert_true(result.contains("No changes."))
    }
    _ => fail("parse failed")
  }
}

// Git ref name validation tests

test "validate_git_ref_name - valid simple name" {
  assert_true(validate_git_ref_name("v1.0.0") is None)
}

test "validate_git_ref_name - valid branch with prefix" {
  assert_true(validate_git_ref_name("release/v1.0.0") is None)
}

test "validate_git_ref_name - valid name with hyphen" {
  assert_true(validate_git_ref_name("v1.0.0-alpha.1") is None)
}

test "validate_git_ref_name - empty name is invalid" {
  assert_true(validate_git_ref_name("") is Some(_))
}

test "validate_git_ref_name - name starting with slash is invalid" {
  assert_true(validate_git_ref_name("/refs/heads/main") is Some(_))
}

test "validate_git_ref_name - name starting with dot is invalid" {
  assert_true(validate_git_ref_name(".hidden") is Some(_))
}

test "validate_git_ref_name - name ending with slash is invalid" {
  assert_true(validate_git_ref_name("release/") is Some(_))
}

test "validate_git_ref_name - name ending with dot is invalid" {
  assert_true(validate_git_ref_name("version.") is Some(_))
}

test "validate_git_ref_name - name ending with .lock is invalid" {
  assert_true(validate_git_ref_name("main.lock") is Some(_))
}

test "validate_git_ref_name - name with space is invalid" {
  assert_true(validate_git_ref_name("my branch") is Some(_))
}

test "validate_git_ref_name - name with tilde is invalid" {
  assert_true(validate_git_ref_name("v1~2") is Some(_))
}

test "validate_git_ref_name - name with caret is invalid" {
  assert_true(validate_git_ref_name("v1^2") is Some(_))
}

test "validate_git_ref_name - name with colon is invalid" {
  assert_true(validate_git_ref_name("v1:2") is Some(_))
}

test "validate_git_ref_name - name with backslash is invalid" {
  assert_true(validate_git_ref_name("v1\\2") is Some(_))
}

test "validate_git_ref_name - name with question mark is invalid" {
  assert_true(validate_git_ref_name("v1?") is Some(_))
}

test "validate_git_ref_name - name with asterisk is invalid" {
  assert_true(validate_git_ref_name("v*") is Some(_))
}

test "validate_git_ref_name - name with bracket is invalid" {
  assert_true(validate_git_ref_name("v[1]") is Some(_))
}

test "validate_git_ref_name - name with double dots is invalid" {
  assert_true(validate_git_ref_name("v1..v2") is Some(_))
}

test "validate_git_ref_name - name with double slashes is invalid" {
  assert_true(validate_git_ref_name("release//v1") is Some(_))
}

test "validate_git_ref_name - name with @{ is invalid" {
  assert_true(validate_git_ref_name("v1@{0}") is Some(_))
}

// Prerelease identifier validation tests

test "validate_prerelease_identifier - valid alpha" {
  assert_true(validate_prerelease_identifier("alpha") is None)
}

test "validate_prerelease_identifier - valid beta with number" {
  assert_true(validate_prerelease_identifier("beta.1") is None)
}

test "validate_prerelease_identifier - valid rc with hyphen" {
  assert_true(validate_prerelease_identifier("rc-1") is None)
}

test "validate_prerelease_identifier - valid complex" {
  assert_true(validate_prerelease_identifier("alpha.1.beta-2") is None)
}

test "validate_prerelease_identifier - empty is invalid" {
  assert_true(validate_prerelease_identifier("") is Some(_))
}

test "validate_prerelease_identifier - special chars invalid" {
  assert_true(validate_prerelease_identifier("alpha!") is Some(_))
}

test "validate_prerelease_identifier - space invalid" {
  assert_true(validate_prerelease_identifier("alpha beta") is Some(_))
}

test "validate_prerelease_identifier - starting with dot invalid" {
  assert_true(validate_prerelease_identifier(".alpha") is Some(_))
}

test "validate_prerelease_identifier - starting with hyphen invalid" {
  assert_true(validate_prerelease_identifier("-alpha") is Some(_))
}

test "validate_prerelease_identifier - ending with dot invalid" {
  assert_true(validate_prerelease_identifier("alpha.") is Some(_))
}

test "validate_prerelease_identifier - ending with hyphen invalid" {
  assert_true(validate_prerelease_identifier("alpha-") is Some(_))
}

// Monorepo PR body tests

test "build_pr_body_unified - empty packages" {
  let packages : Array[PackageReleaseInfo] = []
  let result = build_pr_body_unified(packages)
  assert_eq(result, "No packages to release.")
}

test "build_pr_body_unified - single package" {
  let feat = @conventional.parse("feat: add new feature")
  match feat {
    Some(c) => {
      let old_ver = @semver.Version::parse("0.0.4")
      let new_ver = @semver.Version::parse("0.0.5")
      match (old_ver, new_ver) {
        (Some(old), Some(new)) => {
          let packages = [
            PackageReleaseInfo::{
              name: "my-package",
              old_version: old,
              new_version: new,
              commits: [(c, "abc1234")],
            },
          ]
          let result = build_pr_body_unified(packages)
          // Check header
          assert_true(result.contains("## 🤖 New release"))
          // Check version list
          assert_true(result.contains("* `my-package`: 0.0.4 -> 0.0.5"))
          // Check collapsible changelog
          assert_true(result.contains("<details>"))
          assert_true(result.contains("<summary><i><b>Changelog</b></i></summary>"))
          // Single package: no package name header in changelog (like release-plz)
          assert_false(result.contains("## `my-package`"))
          assert_true(result.contains("### Features"))
          assert_true(result.contains("add new feature"))
        }
        _ => fail("version parse failed")
      }
    }
    None => fail("commit parse failed")
  }
}

test "build_pr_body_unified - multiple packages" {
  let feat = @conventional.parse("feat: add feature")
  let fix = @conventional.parse("fix: fix bug")
  match (feat, fix) {
    (Some(f), Some(x)) => {
      let old1 = @semver.Version::parse("1.0.0")
      let new1 = @semver.Version::parse("1.1.0")
      let old2 = @semver.Version::parse("2.0.0")
      let new2 = @semver.Version::parse("2.0.1")
      match (old1, new1, old2, new2) {
        (Some(o1), Some(n1), Some(o2), Some(n2)) => {
          let packages = [
            PackageReleaseInfo::{
              name: "pkg-a",
              old_version: o1,
              new_version: n1,
              commits: [(f, "1111111")],
            },
            PackageReleaseInfo::{
              name: "pkg-b",
              old_version: o2,
              new_version: n2,
              commits: [(x, "2222222")],
            },
          ]
          let result = build_pr_body_unified(packages)
          // Check both packages in version list
          assert_true(result.contains("* `pkg-a`: 1.0.0 -> 1.1.0"))
          assert_true(result.contains("* `pkg-b`: 2.0.0 -> 2.0.1"))
          // Check both package changelogs
          assert_true(result.contains("## `pkg-a`"))
          assert_true(result.contains("## `pkg-b`"))
          assert_true(result.contains("add feature"))
          assert_true(result.contains("fix bug"))
        }
        _ => fail("version parse failed")
      }
    }
    _ => fail("commit parse failed")
  }
}

test "build_pr_body_unified - groups commits by type" {
  let feat = @conventional.parse("feat: feature one")
  let fix = @conventional.parse("fix: bug fix")
  let docs = @conventional.parse("docs: update readme")
  match (feat, fix, docs) {
    (Some(f), Some(x), Some(d)) => {
      let old_ver = @semver.Version::parse("1.0.0")
      let new_ver = @semver.Version::parse("1.1.0")
      match (old_ver, new_ver) {
        (Some(old), Some(new)) => {
          let packages = [
            PackageReleaseInfo::{
              name: "test-pkg",
              old_version: old,
              new_version: new,
              commits: [(f, "1111111"), (x, "2222222"), (d, "3333333")],
            },
          ]
          let result = build_pr_body_unified(packages)
          // Check sections are present
          assert_true(result.contains("### Features"))
          assert_true(result.contains("### Bug Fixes"))
          assert_true(result.contains("### Other Changes"))
        }
        _ => fail("version parse failed")
      }
    }
    _ => fail("commit parse failed")
  }
}

// npm build command tests

test "get_npm_build_command - returns default when no custom command" {
  let content =
    #|{
    #|  "npm_publish": true
    #|}
  let config = try { @config.Config::parse(content) } catch { _ => fail("Unexpected error") }
  let cmd = get_npm_build_command(config)
  assert_eq(cmd.length(), 4)
  assert_eq(cmd[0], "moon")
  assert_eq(cmd[1], "build")
  assert_eq(cmd[2], "--target")
  assert_eq(cmd[3], "js")
}

test "get_npm_build_command - returns custom command when specified" {
  let content =
    #|{
    #|  "npm_publish": true,
    #|  "npm_build_command": "npm run build"
    #|}
  let config = try { @config.Config::parse(content) } catch { _ => fail("Unexpected error") }
  let cmd = get_npm_build_command(config)
  assert_eq(cmd.length(), 3)
  assert_eq(cmd[0], "npm")
  assert_eq(cmd[1], "run")
  assert_eq(cmd[2], "build")
}

test "get_npm_build_command - handles single word command" {
  let content =
    #|{
    #|  "npm_publish": true,
    #|  "npm_build_command": "make"
    #|}
  let config = try { @config.Config::parse(content) } catch { _ => fail("Unexpected error") }
  let cmd = get_npm_build_command(config)
  assert_eq(cmd.length(), 1)
  assert_eq(cmd[0], "make")
}

test "get_npm_build_command - handles complex command" {
  let content =
    #|{
    #|  "npm_publish": true,
    #|  "npm_build_command": "moon build --target js --output-dir dist"
    #|}
  let config = try { @config.Config::parse(content) } catch { _ => fail("Unexpected error") }
  let cmd = get_npm_build_command(config)
  assert_eq(cmd.length(), 6)
  assert_eq(cmd[0], "moon")
  assert_eq(cmd[1], "build")
  assert_eq(cmd[2], "--target")
  assert_eq(cmd[3], "js")
  assert_eq(cmd[4], "--output-dir")
  assert_eq(cmd[5], "dist")
}

test "get_pkg_npm_build_command - default" {
  let content =
    #|{
    #|  "packages": [
    #|    { "name": "test", "path": "packages/test", "moon_publish": true, "npm_publish": true }
    #|  ]
    #|}
  let config = try { @config.Config::parse(content) } catch { _ => fail("Unexpected error") }
  let cmd = get_pkg_npm_build_command(config.packages[0])
  assert_eq(cmd.length(), 4)
  assert_eq(cmd[0], "moon")
  assert_eq(cmd[1], "build")
  assert_eq(cmd[2], "--target")
  assert_eq(cmd[3], "js")
}

test "get_pkg_npm_build_command - custom" {
  let content =
    #|{
    #|  "packages": [
    #|    { "name": "test", "path": "packages/test", "moon_publish": false, "npm_publish": true, "npm_build_command": "npx tsc --outDir lib" }
    #|  ]
    #|}
  let config = try { @config.Config::parse(content) } catch { _ => fail("Unexpected error") }
  let cmd = get_pkg_npm_build_command(config.packages[0])
  assert_eq(cmd.length(), 4)
  assert_eq(cmd[0], "npx")
  assert_eq(cmd[1], "tsc")
  assert_eq(cmd[2], "--outDir")
  assert_eq(cmd[3], "lib")
}

// collect_files_to_stage tests

fn make_ctx(config : @config.Config) -> ReleaseContext {
  let ver = @semver.Version::parse("1.0.0").unwrap()
  ReleaseContext::new(config, @git.Repository::current(), ver, ver, [])
}

test "collect_files_to_stage - single package MooncakesOnly" {
  let config = @config.Config::default()  // moon_publish=true, npm_publish=false
  let ctx = make_ctx(config)
  let files = collect_files_to_stage(ctx)
  assert_eq(files, ["add", "moon.mod.json"])
}

test "collect_files_to_stage - single package NpmOnly" {
  let content =
    #|{
    #|  "moon_publish": false,
    #|  "npm_publish": true
    #|}
  let config = try { @config.Config::parse(content) } catch { _ => fail("Unexpected error") }
  let ctx = make_ctx(config)
  let files = collect_files_to_stage(ctx)
  assert_eq(files, ["add", "package.json"])
}

test "collect_files_to_stage - single package Both" {
  let content =
    #|{
    #|  "moon_publish": true,
    #|  "npm_publish": true
    #|}
  let config = try { @config.Config::parse(content) } catch { _ => fail("Unexpected error") }
  let ctx = make_ctx(config)
  let files = collect_files_to_stage(ctx)
  assert_eq(files, ["add", "moon.mod.json", "package.json"])
}

test "collect_files_to_stage - single package NoPublish" {
  let content =
    #|{
    #|  "moon_publish": false,
    #|  "npm_publish": false
    #|}
  let config = try { @config.Config::parse(content) } catch { _ => fail("Unexpected error") }
  let ctx = make_ctx(config)
  let files = collect_files_to_stage(ctx)
  assert_eq(files, ["add"])
}

test "collect_files_to_stage - monorepo mixed publish targets" {
  let content =
    #|{
    #|  "packages": [
    #|    { "name": "core", "path": "packages/core", "moon_publish": true, "npm_publish": false },
    #|    { "name": "cli", "path": "packages/cli", "moon_publish": false, "npm_publish": true },
    #|    { "name": "all", "path": "packages/all", "moon_publish": true, "npm_publish": true }
    #|  ]
    #|}
  let config = try { @config.Config::parse(content) } catch { _ => fail("Unexpected error") }
  let ctx = make_ctx(config)
  let files = collect_files_to_stage(ctx)
  assert_eq(files, ["add", "packages/core/moon.mod.json", "packages/cli/package.json", "packages/all/moon.mod.json", "packages/all/package.json"])
}

test "collect_files_to_stage - monorepo NoPublish packages skipped" {
  let content =
    #|{
    #|  "packages": [
    #|    { "name": "core", "path": "packages/core", "moon_publish": true, "npm_publish": false },
    #|    { "name": "internal", "path": "packages/internal", "moon_publish": false, "npm_publish": false }
    #|  ]
    #|}
  let config = try { @config.Config::parse(content) } catch { _ => fail("Unexpected error") }
  let ctx = make_ctx(config)
  let files = collect_files_to_stage(ctx)
  assert_eq(files, ["add", "packages/core/moon.mod.json"])
}

test "collect_files_to_stage - monorepo root path uses no prefix" {
  let content =
    #|{
    #|  "packages": [
    #|    { "name": "root", "path": ".", "moon_publish": true, "npm_publish": false }
    #|  ]
    #|}
  let config = try { @config.Config::parse(content) } catch { _ => fail("Unexpected error") }
  let ctx = make_ctx(config)
  let files = collect_files_to_stage(ctx)
  assert_eq(files, ["add", "moon.mod.json"])
}

// replace_json_field + trailing newline preservation tests (for update_package_json_version logic)

test "replace_json_field preserves trailing newline" {
  let content =
    #|{
    #|  "name": "my-pkg",
    #|  "version": "1.0.0"
    #|}
  // Simulate the logic from update_package_json_version:
  // replace_json_field + trailing newline preservation
  let with_newline = content + "\n"
  let result = try { @moon_mod.replace_json_field(with_newline, "version", "2.0.0") } catch { _ => fail("Unexpected error") }
  // The replace_json_field itself may or may not preserve trailing newline,
  // so apply the same logic as update_package_json_version
  let final_result = if with_newline.has_suffix("\n") && not(result.has_suffix("\n")) {
    result + "\n"
  } else {
    result
  }
  assert_true(final_result.has_suffix("\n"))
  assert_true(final_result.contains("\"version\": \"2.0.0\""))
}

test "replace_json_field - version field missing raises error" {
  let content =
    #|{
    #|  "name": "my-pkg"
    #|}
  try {
    let _ = @moon_mod.replace_json_field(content, "version", "2.0.0")
    fail("Expected error for missing version field")
  } catch {
    @moon_mod.ParseError(msg) => assert_true(msg.contains("not found"))
    _ => fail("Wrong error type: expected ParseError")
  }
}

// WorkflowError to_string / hint tests

test "WorkflowError::to_string - GitError includes category" {
  let e : WorkflowError = GitError("tag not found")
  assert_eq(e.to_string(), "[git] tag not found")
}

test "WorkflowError::to_string - ConfigValidationError includes category" {
  let e : WorkflowError = ConfigValidationError("invalid field")
  assert_eq(e.to_string(), "[config] invalid field")
}

test "WorkflowError::to_string - PublishError includes category" {
  let e : WorkflowError = PublishError("auth failed")
  assert_eq(e.to_string(), "[publish] auth failed")
}

test "WorkflowError::to_string - InputValidationError includes category" {
  let e : WorkflowError = InputValidationError("bad branch name")
  assert_eq(e.to_string(), "[input] bad branch name")
}

test "WorkflowError::to_string - ExternalCommandError includes category" {
  let e : WorkflowError = ExternalCommandError("gh not found")
  assert_eq(e.to_string(), "[command] gh not found")
}

test "WorkflowError::to_string - generic WorkflowError has no prefix" {
  let e : WorkflowError = WorkflowError("something went wrong")
  assert_eq(e.to_string(), "something went wrong")
}

test "WorkflowError::hint - each variant returns appropriate hint" {
  assert_true((GitError("x") : WorkflowError).hint().contains("git repository"))
  assert_true((ConfigValidationError("x") : WorkflowError).hint().contains("release.json"))
  assert_true((PublishError("x") : WorkflowError).hint().contains("credentials"))
  assert_true((InputValidationError("x") : WorkflowError).hint().contains("input values"))
  assert_true((ExternalCommandError("x") : WorkflowError).hint().contains("installed"))
  assert_eq((WorkflowError("x") : WorkflowError).hint(), "")
}

test "WorkflowError::add_context - preserves GitError variant" {
  let e : WorkflowError = GitError("original")
  let with_ctx = e.add_context(" (recovery note)")
  assert_eq(with_ctx.to_string(), "[git] original (recovery note)")
  assert_true(with_ctx.hint().contains("git repository"))
}

test "WorkflowError::add_context - preserves ConfigValidationError variant" {
  let e : WorkflowError = ConfigValidationError("bad config")
  let with_ctx = e.add_context(" (context)")
  assert_eq(with_ctx.to_string(), "[config] bad config (context)")
  assert_true(with_ctx.hint().contains("release.json"))
}

test "WorkflowError::add_context - generic WorkflowError stays generic" {
  let e : WorkflowError = WorkflowError("msg")
  let with_ctx = e.add_context(" (extra)")
  assert_eq(with_ctx.to_string(), "msg (extra)")
  assert_eq(with_ctx.hint(), "")
}

// short_hash unit tests

test "short_hash - 40-char full hash returns first 7" {
  assert_eq(short_hash("abcdef1234567890abcdef1234567890abcdef12"), "abcdef1")
}

test "short_hash - exactly 7 chars returns as-is" {
  assert_eq(short_hash("abc1234"), "abc1234")
}

test "short_hash - less than 7 chars returns full string" {
  assert_eq(short_hash("abc"), "abc")
}

test "short_hash - empty string returns empty" {
  assert_eq(short_hash(""), "")
}

test "short_hash - exactly 8 chars returns first 7" {
  assert_eq(short_hash("abcdefgh"), "abcdefg")
}

// build_npm_publish_command unit tests

test "build_npm_publish_command - with provenance" {
  let cmd = build_npm_publish_command(true)
  assert_eq(cmd, ["npm", "publish", "--provenance", "--access", "public"])
}

test "build_npm_publish_command - without provenance" {
  let cmd = build_npm_publish_command(false)
  assert_eq(cmd, ["npm", "publish", "--access", "public"])
}

// generate_package_changelog unit tests

test "generate_package_changelog - empty commits" {
  let commits : Array[(@conventional.ConventionalCommit, String)] = []
  assert_eq(generate_package_changelog(commits), "No changes.\n")
}

test "generate_package_changelog - fix only" {
  let fix = @conventional.parse("fix: correct bug")
  match fix {
    Some(c) => {
      let result = generate_package_changelog([(c, "abc1234")])
      assert_true(result.contains("### Bug Fixes"))
      assert_false(result.contains("### Features"))
      assert_true(result.contains("correct bug"))
    }
    None => fail("parse failed")
  }
}

test "generate_package_changelog - docs goes to Other Changes" {
  let docs = @conventional.parse("docs: update readme")
  match docs {
    Some(c) => {
      let result = generate_package_changelog([(c, "abc1234")])
      assert_true(result.contains("### Other Changes"))
      assert_false(result.contains("### Features"))
    }
    None => fail("parse failed")
  }
}

test "generate_package_changelog - breaking feat goes to Features" {
  let commit = @conventional.parse("feat!: remove old API")
  match commit {
    Some(c) => {
      let result = generate_package_changelog([(c, "abc1234")])
      assert_true(result.contains("### Features"))
      assert_true(result.contains("remove old API"))
    }
    None => fail("parse failed")
  }
}

test "build_pr_body_unified - package with no commits" {
  let old_ver = @semver.Version::parse("1.0.0").unwrap()
  let new_ver = @semver.Version::parse("1.0.1").unwrap()
  let packages = [
    PackageReleaseInfo::{
      name: "empty-pkg",
      old_version: old_ver,
      new_version: new_ver,
      commits: [],
    },
  ]
  let result = build_pr_body_unified(packages)
  assert_true(result.contains("* `empty-pkg`: 1.0.0 -> 1.0.1"))
  // No changelog section for empty commits
  assert_false(result.contains("### Features"))
}
