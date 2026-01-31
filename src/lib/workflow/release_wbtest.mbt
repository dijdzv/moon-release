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
