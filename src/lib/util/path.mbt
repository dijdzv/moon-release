/// Path validation result
pub enum PathValidation {
  /// Path is valid
  Valid
  /// Path contains directory traversal (..)
  DirectoryTraversal
  /// Path is absolute (starts with /)
  AbsolutePath
} derive(Show, Eq)

/// Validate path for directory traversal
/// Returns DirectoryTraversal if path contains ".."
pub fn check_directory_traversal(path : String) -> PathValidation {
  if path.contains("..") {
    DirectoryTraversal
  } else {
    Valid
  }
}

/// Check if path is absolute (starts with /)
pub fn is_absolute_path(path : String) -> Bool {
  let chars = path.to_array()
  chars.length() > 0 && chars[0] == '/'
}

/// Validate path: rejects directory traversal and optionally absolute paths
/// - allow_absolute: if false, absolute paths are rejected
pub fn validate_path_full(path : String, allow_absolute~ : Bool = false) -> PathValidation {
  // Empty string and "." are always valid
  if path.is_empty() || path == "." {
    return Valid
  }

  // Check for directory traversal
  if path.contains("..") {
    return DirectoryTraversal
  }

  // Check for absolute paths if not allowed
  if not(allow_absolute) && is_absolute_path(path) {
    return AbsolutePath
  }

  Valid
}

/// Simple path validation (Bool result)
/// Returns true if path is valid (no directory traversal, not absolute)
pub fn is_safe_path(path : String) -> Bool {
  match validate_path_full(path) {
    Valid => true
    _ => false
  }
}

/// Get error message for validation result
pub fn PathValidation::error_message(self : PathValidation) -> String? {
  match self {
    Valid => None
    DirectoryTraversal => Some("path contains '..' (directory traversal not allowed)")
    AbsolutePath => Some("absolute paths are not allowed")
  }
}
