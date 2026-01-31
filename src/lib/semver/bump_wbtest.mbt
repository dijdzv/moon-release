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
  // parse 関数を使ってテストデータを作成
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
  let result = bump_with_prerelease(v, Minor, Some("alpha"))
  assert_eq(result.major, 1)
  assert_eq(result.minor, 3)
  assert_eq(result.patch, 0)
  assert_eq(result.prerelease, Some("alpha"))
  assert_eq(result.build_metadata, None)
}

test "bump_with_prerelease rc.1" {
  let v = Version::{
    major: 2,
    minor: 0,
    patch: 0,
    prerelease: None,
    build_metadata: None,
  }
  let result = bump_with_prerelease(v, Major, Some("rc.1"))
  assert_eq(result.major, 3)
  assert_eq(result.minor, 0)
  assert_eq(result.patch, 0)
  assert_eq(result.prerelease, Some("rc.1"))
}

test "bump_with_prerelease None clears prerelease" {
  let v = Version::{
    major: 1,
    minor: 0,
    patch: 0,
    prerelease: Some("beta"),
    build_metadata: Some("build.123"),
  }
  let result = bump_with_prerelease(v, Patch, None)
  assert_eq(result.patch, 1)
  assert_eq(result.prerelease, None)
  assert_eq(result.build_metadata, None)
}
