test "generate simple changelog" {
  let commit = @conventional.parse("feat: add new feature")
  let version = @semver.Version::parse("1.0.0")
  match (commit, version) {
    (Some(c), Some(v)) => {
      let commits = [(c, "abc1234def5678")]
      let result = generate(commits, v, "2024-01-15")
      assert_true(result.contains("## [1.0.0] - 2024-01-15"))
      assert_true(result.contains("### Added"))
      assert_true(result.contains("add new feature"))
      assert_true(result.contains("abc1234"))
    }
    _ => fail("Expected Some")
  }
}

test "generate changelog with scope" {
  let commit = @conventional.parse("feat(api): add endpoint")
  let version = @semver.Version::parse("1.1.0")
  match (commit, version) {
    (Some(c), Some(v)) => {
      let commits = [(c, "1234567")]
      let result = generate(commits, v, "2024-01-20")
      assert_true(result.contains("**api**: add endpoint"))
    }
    _ => fail("Expected Some")
  }
}

test "generate changelog with breaking change" {
  let commit = @conventional.parse("feat!: breaking api change")
  let version = @semver.Version::parse("2.0.0")
  match (commit, version) {
    (Some(c), Some(v)) => {
      let commits = [(c, "abcdefg")]
      let result = generate(commits, v, "2024-02-01")
      assert_true(result.contains("### BREAKING CHANGES"))
      assert_true(result.contains("breaking api change"))
    }
    _ => fail("Expected Some")
  }
}

test "generate changelog with fix" {
  let commit = @conventional.parse("fix: correct bug")
  let version = @semver.Version::parse("1.0.1")
  match (commit, version) {
    (Some(c), Some(v)) => {
      let commits = [(c, "xyz9876")]
      let result = generate(commits, v, "2024-01-16")
      assert_true(result.contains("### Fixed"))
      assert_true(result.contains("correct bug"))
    }
    _ => fail("Expected Some")
  }
}

test "generate changelog with multiple commits" {
  let feat = @conventional.parse("feat: add feature")
  let fix = @conventional.parse("fix: fix bug")
  let version = @semver.Version::parse("1.1.0")
  match (feat, fix, version) {
    (Some(f), Some(x), Some(v)) => {
      let commits = [(f, "aaa1111"), (x, "bbb2222")]
      let result = generate(commits, v, "2024-03-01")
      assert_true(result.contains("### Added"))
      assert_true(result.contains("### Fixed"))
      assert_true(result.contains("add feature"))
      assert_true(result.contains("fix bug"))
    }
    _ => fail("Expected Some")
  }
}

test "entry to markdown basic" {
  let version = @semver.Version::parse("0.2.0")
  match version {
    Some(v) => {
      let sections : @hashmap.HashMap[String, Array[ChangelogItem]] = @hashmap.new()
      sections.set("Added", [ChangelogItem::{ description: "new feature", scope: None, commit_hash: Some("abc1234") }])

      let entry = ChangelogEntry::{ version: v, date: "2024-01-15", sections }
      let result = entry_to_markdown(entry)
      assert_true(result.contains("[0.2.0]"))
      assert_true(result.contains("2024-01-15"))
      assert_true(result.contains("new feature"))
    }
    None => fail("Expected Some")
  }
}
