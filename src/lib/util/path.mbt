/// Path validation result
pub enum PathValidation {
  /// Path is valid
  Valid
  /// Path contains directory traversal (..)
  DirectoryTraversal
  /// Path is absolute (starts with /)
  AbsolutePath
  /// Path contains a NUL byte
  NullByte
} derive(Show, Eq)

/// Check if path contains a ".." traversal segment
/// Splits on both '/' and '\' to handle Windows paths
fn has_traversal_segment(path : String) -> Bool {
  let chars = path.to_array()
  let len = chars.length()
  let mut seg_start = 0
  let mut i = 0
  while i <= len {
    // At separator or end of string, check the segment
    let is_sep = if i < len { chars[i] == '/' || chars[i] == '\\' } else { true }
    if is_sep {
      let seg_len = i - seg_start
      if seg_len == 2 && seg_start + 1 < len && chars[seg_start] == '.' && chars[seg_start + 1] == '.' {
        return true
      }
      seg_start = i + 1
    }
    i = i + 1
  }
  false
}

/// Validate path for directory traversal
/// Returns DirectoryTraversal if path contains a ".." segment
pub fn check_directory_traversal(path : String) -> PathValidation {
  if has_traversal_segment(path) {
    DirectoryTraversal
  } else {
    Valid
  }
}

/// Check if path is absolute (starts with / or Windows drive letter/UNC path)
pub fn is_absolute_path(path : String) -> Bool {
  let chars = path.to_array()
  if chars.length() == 0 {
    return false
  }
  // Unix absolute path
  if chars[0] == '/' {
    return true
  }
  // Windows drive letter (e.g., C:\ or C:/)
  if chars.length() >= 3 &&
    ((chars[0] >= 'A' && chars[0] <= 'Z') || (chars[0] >= 'a' && chars[0] <= 'z')) &&
    chars[1] == ':' &&
    (chars[2] == '\\' || chars[2] == '/') {
    return true
  }
  // Windows UNC path (e.g., \\server\share)
  if chars.length() >= 2 && chars[0] == '\\' && chars[1] == '\\' {
    return true
  }
  false
}

/// Validate path: rejects directory traversal, NUL bytes, and optionally absolute paths
/// - allow_absolute: if false, absolute paths are rejected
pub fn validate_path_full(path : String, allow_absolute~ : Bool = false) -> PathValidation {
  // Empty string and "." are always valid
  if path.is_empty() || path == "." {
    return Valid
  }

  // Check for NUL byte
  for c in path {
    if c == '\u0000' {
      return NullByte
    }
  }

  // Check for directory traversal (segment-based check)
  if has_traversal_segment(path) {
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
    NullByte => Some("path contains NUL byte")
  }
}
