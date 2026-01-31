// Path validation tests

test "is_safe_path - empty string is valid" {
  assert_true(is_safe_path(""))
}

test "is_safe_path - dot is valid" {
  assert_true(is_safe_path("."))
}

test "is_safe_path - relative path is valid" {
  assert_true(is_safe_path("packages/core"))
}

test "is_safe_path - path with double dots is invalid" {
  assert_false(is_safe_path("../etc/passwd"))
}

test "is_safe_path - path containing double dots is invalid" {
  assert_false(is_safe_path("packages/../secrets"))
}

test "is_safe_path - absolute path is invalid" {
  assert_false(is_safe_path("/etc/passwd"))
}

test "validate_path_full - allows absolute with flag" {
  assert_eq(validate_path_full("/etc/passwd", allow_absolute=true), Valid)
}

test "validate_path_full - rejects directory traversal even with absolute allowed" {
  assert_eq(validate_path_full("../etc", allow_absolute=true), DirectoryTraversal)
}

test "is_absolute_path - detects absolute paths" {
  assert_true(is_absolute_path("/home/user"))
  assert_false(is_absolute_path("relative/path"))
  assert_false(is_absolute_path(""))
}

test "PathValidation error_message - Valid has no message" {
  assert_eq(Valid.error_message(), None)
}

test "PathValidation error_message - DirectoryTraversal has message" {
  match DirectoryTraversal.error_message() {
    Some(msg) => assert_true(msg.contains("directory traversal"))
    None => fail("expected error message")
  }
}

test "PathValidation error_message - AbsolutePath has message" {
  match AbsolutePath.error_message() {
    Some(msg) => assert_true(msg.contains("absolute"))
    None => fail("expected error message")
  }
}
