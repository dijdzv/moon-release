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

// H-2: False positive tests - ".." inside names should NOT be detected as traversal
test "is_safe_path - double dots in filename is valid" {
  assert_true(is_safe_path("packages/foo..bar"))
}

test "is_safe_path - double dots in directory name is valid" {
  assert_true(is_safe_path("my..project/src"))
}

test "is_safe_path - actual traversal is still detected" {
  assert_false(is_safe_path("packages/../../etc"))
}

test "is_safe_path - traversal at start" {
  assert_false(is_safe_path("../secret"))
}

test "is_safe_path - traversal at end" {
  assert_false(is_safe_path("packages/.."))
}

// L-4: Windows path tests
test "is_absolute_path - Windows drive letter" {
  assert_true(is_absolute_path("C:\\Users\\test"))
  assert_true(is_absolute_path("D:/projects"))
}

test "is_absolute_path - Windows UNC path" {
  assert_true(is_absolute_path("\\\\server\\share"))
}

test "is_safe_path - Windows absolute path is rejected" {
  assert_false(is_safe_path("C:\\Users\\test"))
}

test "is_safe_path - Windows backslash traversal" {
  assert_false(is_safe_path("packages\\..\\secrets"))
}

// M-19: NUL byte should return NullByte variant, not DirectoryTraversal
test "validate_path_full - NUL byte returns NullByte" {
  assert_eq(validate_path_full("path\u0000evil"), NullByte)
}

test "PathValidation error_message - NullByte has message" {
  match NullByte.error_message() {
    Some(msg) => assert_true(msg.contains("NUL byte"))
    None => fail("expected error message")
  }
}

test "is_safe_path - NUL byte is rejected" {
  assert_false(is_safe_path("path\u0000evil"))
}
