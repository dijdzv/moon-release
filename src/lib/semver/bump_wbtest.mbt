test "bump major" {
  let v = Version::{ major: 1, minor: 2, patch: 3, prerelease: None, build_metadata: None }
  let result = bump(v, Major)
  assert_eq(result.major, 2)
  assert_eq(result.minor, 0)
  assert_eq(result.patch, 0)
  assert_eq(result.prerelease, None)
}

test "bump minor" {
  let v = Version::{ major: 1, minor: 2, patch: 3, prerelease: None, build_metadata: None }
  let result = bump(v, Minor)
  assert_eq(result.major, 1)
  assert_eq(result.minor, 3)
  assert_eq(result.patch, 0)
  assert_eq(result.prerelease, None)
}

test "bump patch" {
  let v = Version::{ major: 1, minor: 2, patch: 3, prerelease: None, build_metadata: None }
  let result = bump(v, Patch)
  assert_eq(result.major, 1)
  assert_eq(result.minor, 2)
  assert_eq(result.patch, 4)
  assert_eq(result.prerelease, None)
}

test "bump removes prerelease" {
  let v = Version::{ major: 1, minor: 2, patch: 3, prerelease: Some("alpha"), build_metadata: None }
  let result = bump(v, Patch)
  assert_eq(result.prerelease, None)
}

test "determine_bump with parse" {
  // Create test data using parse function
  let commit = @conventional.parse("feat!: breaking change")
  match commit {
    Some(c) => {
      let commits = [c]
      assert_eq(determine_bump(commits), Some(Major))
    }
    None => fail("Expected Some")
  }
}

test "determine_bump feat" {
  let commit = @conventional.parse("feat: add feature")
  match commit {
    Some(c) => {
      let commits = [c]
      assert_eq(determine_bump(commits), Some(Minor))
    }
    None => fail("Expected Some")
  }
}

test "determine_bump fix" {
  let commit = @conventional.parse("fix: correct bug")
  match commit {
    Some(c) => {
      let commits = [c]
      assert_eq(determine_bump(commits), Some(Patch))
    }
    None => fail("Expected Some")
  }
}

test "determine_bump chore returns None" {
  let commit = @conventional.parse("chore: update deps")
  match commit {
    Some(c) => {
      let commits = [c]
      assert_eq(determine_bump(commits), None)
    }
    None => fail("Expected Some")
  }
}

test "bump_with_prerelease alpha" {
  let v = Version::{
    major: 1,
    minor: 2,
    patch: 3,
    prerelease: None,
    build_metadata: None,
  }
  match bump_with_prerelease(v, Minor, Some("alpha")) {
    Some(result) => {
      assert_eq(result.major, 1)
      assert_eq(result.minor, 3)
      assert_eq(result.patch, 0)
      assert_eq(result.prerelease, Some("alpha"))
      assert_eq(result.build_metadata, None)
    }
    None => fail("Expected Some, got None")
  }
}

test "bump_with_prerelease rc.1" {
  let v = Version::{
    major: 2,
    minor: 0,
    patch: 0,
    prerelease: None,
    build_metadata: None,
  }
  match bump_with_prerelease(v, Major, Some("rc.1")) {
    Some(result) => {
      assert_eq(result.major, 3)
      assert_eq(result.minor, 0)
      assert_eq(result.patch, 0)
      assert_eq(result.prerelease, Some("rc.1"))
    }
    None => fail("Expected Some, got None")
  }
}

test "bump_with_prerelease None clears prerelease" {
  let v = Version::{
    major: 1,
    minor: 0,
    patch: 0,
    prerelease: Some("beta"),
    build_metadata: Some("build.123"),
  }
  match bump_with_prerelease(v, Patch, None) {
    Some(result) => {
      assert_eq(result.patch, 1)
      assert_eq(result.prerelease, None)
      assert_eq(result.build_metadata, None)
    }
    None => fail("Expected Some, got None")
  }
}

// determine_bump_with_custom tests

test "determine_bump_with_custom - custom major pattern" {
  let commit = @conventional.parse("fix: BREAKING fix something")
  match commit {
    Some(c) => {
      let commits = [c]
      let result = determine_bump_with_custom(commits, Some("BREAKING"), None)
      assert_eq(result, Some(Major))
    }
    None => fail("parse failed")
  }
}

test "determine_bump_with_custom - custom minor pattern" {
  let commit = @conventional.parse("chore: add NEW feature")
  match commit {
    Some(c) => {
      let commits = [c]
      let result = determine_bump_with_custom(commits, None, Some("NEW"))
      assert_eq(result, Some(Minor))
    }
    None => fail("parse failed")
  }
}

test "determine_bump_with_custom - both patterns None falls back to standard" {
  let commit = @conventional.parse("feat: add feature")
  match commit {
    Some(c) => {
      let commits = [c]
      let result = determine_bump_with_custom(commits, None, None)
      assert_eq(result, Some(Minor))
    }
    None => fail("parse failed")
  }
}

test "determine_bump_with_custom - breaking takes priority over custom major" {
  let commit = @conventional.parse("feat!: breaking change")
  match commit {
    Some(c) => {
      let commits = [c]
      // Even without custom patterns, breaking should return Major
      let result = determine_bump_with_custom(commits, None, None)
      assert_eq(result, Some(Major))
    }
    None => fail("parse failed")
  }
}

test "determine_bump_with_custom - custom major priority over custom minor" {
  let commit = @conventional.parse("chore: MAJOR and MINOR keywords")
  match commit {
    Some(c) => {
      let commits = [c]
      let result = determine_bump_with_custom(commits, Some("MAJOR"), Some("MINOR"))
      // Major pattern should match first and return immediately
      assert_eq(result, Some(Major))
    }
    None => fail("parse failed")
  }
}

test "determine_bump_with_custom - no match returns None" {
  let commit = @conventional.parse("docs: update readme")
  match commit {
    Some(c) => {
      let commits = [c]
      let result = determine_bump_with_custom(commits, Some("BREAKING"), Some("NEW"))
      assert_eq(result, None)
    }
    None => fail("parse failed")
  }
}

test "bump_with_prerelease rejects invalid prerelease" {
  let v = Version::{
    major: 1,
    minor: 0,
    patch: 0,
    prerelease: None,
    build_metadata: None,
  }
  // Underscore is not allowed in prerelease identifiers
  assert_true(bump_with_prerelease(v, Minor, Some("alpha_1")) is None)
  // Empty prerelease is not allowed
  assert_true(bump_with_prerelease(v, Minor, Some("")) is None)
  // Leading zeros in numeric identifiers are not allowed
  assert_true(bump_with_prerelease(v, Minor, Some("01")) is None)
}
