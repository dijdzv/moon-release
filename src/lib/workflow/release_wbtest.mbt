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
  let config = @config.Config::default()
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
