// BranchName tests

test "BranchName::new - valid simple name" {
  let b = try { BranchName::new("main") } catch { _ => fail("unexpected error") }
  assert_eq(b.value(), "main")
}

test "BranchName::new - valid with prefix" {
  let b = try { BranchName::new("release/v1.0.0") } catch { _ => fail("unexpected error") }
  assert_eq(b.value(), "release/v1.0.0")
}

test "BranchName::new - rejects empty" {
  try {
    let _ = BranchName::new("")
    fail("expected error")
  } catch {
    ValidationError(msg) => assert_true(msg.contains("empty"))
    _ => fail("wrong error type")
  }
}

test "BranchName::new - rejects space" {
  try {
    let _ = BranchName::new("my branch")
    fail("expected error")
  } catch {
    ValidationError(msg) => assert_true(msg.contains("spaces"))
    _ => fail("wrong error type")
  }
}

test "BranchName::new - rejects double dots" {
  try {
    let _ = BranchName::new("v1..v2")
    fail("expected error")
  } catch {
    ValidationError(msg) => assert_true(msg.contains(".."))
    _ => fail("wrong error type")
  }
}

test "BranchName::new - rejects tilde" {
  try {
    let _ = BranchName::new("v1~2")
    fail("expected error")
  } catch {
    ValidationError(msg) => assert_true(msg.contains("special"))
    _ => fail("wrong error type")
  }
}

test "BranchName::new - rejects .lock suffix" {
  try {
    let _ = BranchName::new("main.lock")
    fail("expected error")
  } catch {
    ValidationError(msg) => assert_true(msg.contains(".lock"))
    _ => fail("wrong error type")
  }
}

// TagName tests

test "TagName::new - valid tag" {
  let t = try { TagName::new("v1.0.0") } catch { _ => fail("unexpected error") }
  assert_eq(t.value(), "v1.0.0")
}

test "TagName::new - valid with prerelease" {
  let t = try { TagName::new("v1.0.0-alpha.1") } catch { _ => fail("unexpected error") }
  assert_eq(t.value(), "v1.0.0-alpha.1")
}

test "TagName::new - rejects empty" {
  try {
    let _ = TagName::new("")
    fail("expected error")
  } catch {
    ValidationError(_) => ()
    _ => fail("wrong error type")
  }
}

test "TagName::new - rejects colon" {
  try {
    let _ = TagName::new("v1:0")
    fail("expected error")
  } catch {
    ValidationError(_) => ()
    _ => fail("wrong error type")
  }
}

// CommitHash tests

test "CommitHash::new - valid full hash" {
  let h = try {
    CommitHash::new("abcdef1234567890abcdef1234567890abcdef12")
  } catch {
    _ => fail("unexpected error")
  }
  assert_eq(h.value(), "abcdef1234567890abcdef1234567890abcdef12")
}

test "CommitHash::new - valid short hash" {
  let h = try { CommitHash::new("abc1234") } catch { _ => fail("unexpected error") }
  assert_eq(h.value(), "abc1234")
}

test "CommitHash::short - returns 7 chars" {
  let h = try {
    CommitHash::new("abcdef1234567890abcdef1234567890abcdef12")
  } catch {
    _ => fail("unexpected error")
  }
  assert_eq(h.short(), "abcdef1")
}

test "CommitHash::short - returns full hash if 7 or less" {
  let h = try { CommitHash::new("abc1234") } catch { _ => fail("unexpected error") }
  assert_eq(h.short(), "abc1234")
}

test "CommitHash::new - rejects empty" {
  try {
    let _ = CommitHash::new("")
    fail("expected error")
  } catch {
    ValidationError(msg) => assert_true(msg.contains("empty"))
    _ => fail("wrong error type")
  }
}

test "CommitHash::new - rejects too short (6 chars)" {
  try {
    let _ = CommitHash::new("abc123")
    fail("expected error")
  } catch {
    ValidationError(msg) => assert_true(msg.contains("7-40"))
    _ => fail("wrong error type")
  }
}

test "CommitHash::new - rejects too long (41 chars)" {
  try {
    let _ = CommitHash::new("abcdef1234567890abcdef1234567890abcdef12b")
    fail("expected error")
  } catch {
    ValidationError(msg) => assert_true(msg.contains("7-40"))
    _ => fail("wrong error type")
  }
}

test "CommitHash::new - rejects non-hex" {
  try {
    let _ = CommitHash::new("xyz1234")
    fail("expected error")
  } catch {
    ValidationError(msg) => assert_true(msg.contains("non-hex"))
    _ => fail("wrong error type")
  }
}

// PackagePath tests

test "PackagePath::new - valid path" {
  let p = try { PackagePath::new("packages/core") } catch { _ => fail("unexpected error") }
  assert_eq(p.value(), "packages/core")
}

test "PackagePath::new - valid dot" {
  let p = try { PackagePath::new(".") } catch { _ => fail("unexpected error") }
  assert_eq(p.value(), ".")
}

test "PackagePath::new - valid empty" {
  let p = try { PackagePath::new("") } catch { _ => fail("unexpected error") }
  assert_eq(p.value(), "")
}

test "PackagePath::prefix - adds trailing slash" {
  let p = try { PackagePath::new("packages/core") } catch { _ => fail("unexpected error") }
  assert_eq(p.prefix(), "packages/core/")
}

test "PackagePath::prefix - dot returns empty" {
  let p = try { PackagePath::new(".") } catch { _ => fail("unexpected error") }
  assert_eq(p.prefix(), "")
}

test "PackagePath::prefix - empty returns empty" {
  let p = try { PackagePath::new("") } catch { _ => fail("unexpected error") }
  assert_eq(p.prefix(), "")
}

test "PackagePath::new - rejects traversal" {
  try {
    let _ = PackagePath::new("../etc/passwd")
    fail("expected error")
  } catch {
    ValidationError(msg) => assert_true(msg.contains("directory traversal"))
    _ => fail("wrong error type")
  }
}

test "PackagePath::new - rejects traversal in middle" {
  try {
    let _ = PackagePath::new("packages/../secrets")
    fail("expected error")
  } catch {
    ValidationError(msg) => assert_true(msg.contains("directory traversal"))
    _ => fail("wrong error type")
  }
}

test "PackagePath::new - rejects absolute path" {
  try {
    let _ = PackagePath::new("/etc/passwd")
    fail("expected error")
  } catch {
    ValidationError(msg) => assert_true(msg.contains("absolute"))
    _ => fail("wrong error type")
  }
}

test "PackagePath::new - rejects NUL byte" {
  try {
    let _ = PackagePath::new("path\u0000evil")
    fail("expected error")
  } catch {
    ValidationError(msg) => assert_true(msg.contains("NUL"))
    _ => fail("wrong error type")
  }
}

// RepositorySlug tests

test "RepositorySlug::new - valid" {
  let s = try { RepositorySlug::new("owner", "repo") } catch { _ => fail("unexpected error") }
  assert_eq(s.value(), "owner/repo")
  assert_eq(s.owner(), "owner")
  assert_eq(s.repo(), "repo")
}

test "RepositorySlug::new - valid with dots and hyphens" {
  let s = try { RepositorySlug::new("my-org", "my.repo") } catch { _ => fail("unexpected error") }
  assert_eq(s.value(), "my-org/my.repo")
}

test "RepositorySlug::new - rejects empty owner" {
  try {
    let _ = RepositorySlug::new("", "repo")
    fail("expected error")
  } catch {
    ValidationError(msg) => assert_true(msg.contains("owner"))
    _ => fail("wrong error type")
  }
}

test "RepositorySlug::new - rejects empty repo" {
  try {
    let _ = RepositorySlug::new("owner", "")
    fail("expected error")
  } catch {
    ValidationError(msg) => assert_true(msg.contains("repo"))
    _ => fail("wrong error type")
  }
}

test "RepositorySlug::new - rejects owner starting with hyphen" {
  try {
    let _ = RepositorySlug::new("-owner", "repo")
    fail("expected error")
  } catch {
    ValidationError(msg) => assert_true(msg.contains("owner"))
    _ => fail("wrong error type")
  }
}

test "RepositorySlug::new - rejects repo with slash" {
  try {
    let _ = RepositorySlug::new("owner", "re/po")
    fail("expected error")
  } catch {
    ValidationError(msg) => assert_true(msg.contains("repo"))
    _ => fail("wrong error type")
  }
}

// validate_git_ref_name_impl tests

test "validate_git_ref_name_impl - valid simple name" {
  assert_true(validate_git_ref_name_impl("v1.0.0") is None)
}

test "validate_git_ref_name_impl - valid branch with prefix" {
  assert_true(validate_git_ref_name_impl("release/v1.0.0") is None)
}

test "validate_git_ref_name_impl - control character rejected" {
  assert_true(validate_git_ref_name_impl("v1\u0001") is Some(_))
}

test "validate_git_ref_name_impl - @{ rejected" {
  assert_true(validate_git_ref_name_impl("v1@{0}") is Some(_))
}

test "validate_git_ref_name_impl - double slash rejected" {
  assert_true(validate_git_ref_name_impl("release//v1") is Some(_))
}
