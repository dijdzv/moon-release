/// Validated git branch name (git-check-ref-format compliant)
/// Constructed only via BranchName::new() which performs validation
pub(all) struct BranchName(String) derive(Show, Eq)

/// Validated git tag name (git-check-ref-format compliant)
pub(all) struct TagName(String) derive(Show, Eq)

/// Validated commit hash (hex characters, 7-40 chars)
pub(all) struct CommitHash(String) derive(Show, Eq)

/// Validated package path (no directory traversal, relative only)
pub(all) struct PackagePath(String) derive(Show, Eq)

/// Validated GitHub repository slug ("owner/repo" format)
pub(all) struct RepositorySlug(String) derive(Show, Eq)

/// Validation error
pub suberror ValidationError {
  ValidationError(String)
}

/// Convert ValidationError to string
pub fn ValidationError::to_string(self : ValidationError) -> String {
  match self {
    ValidationError(msg) => msg
  }
}

// ============================================================================
// BranchName
// ============================================================================

/// Create a validated BranchName
pub fn BranchName::new(s : String) -> BranchName raise ValidationError {
  match validate_git_ref_name_impl(s) {
    Some(reason) => raise ValidationError("Invalid branch name '\{s}': \{reason}")
    None => BranchName(s)
  }
}

/// Get the underlying string value
pub fn BranchName::value(self : BranchName) -> String {
  self.0
}

// ============================================================================
// TagName
// ============================================================================

/// Create a validated TagName
pub fn TagName::new(s : String) -> TagName raise ValidationError {
  match validate_git_ref_name_impl(s) {
    Some(reason) => raise ValidationError("Invalid tag name '\{s}': \{reason}")
    None => TagName(s)
  }
}

/// Get the underlying string value
pub fn TagName::value(self : TagName) -> String {
  self.0
}

// ============================================================================
// CommitHash
// ============================================================================

/// Create a validated CommitHash
pub fn CommitHash::new(s : String) -> CommitHash raise ValidationError {
  if s.is_empty() {
    raise ValidationError("commit hash cannot be empty")
  }
  let chars = s.to_array()
  let len = chars.length()
  // Allow 7 (short) to 40 (full) character hashes
  if len < 7 || len > 40 {
    raise ValidationError(
      "commit hash must be 7-40 characters, got \{len}",
    )
  }
  // Must be hex characters only
  for i = 0; i < len; i = i + 1 {
    let c = chars[i]
    if not(
      (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'),
    ) {
      raise ValidationError(
        "commit hash contains non-hex character '\{c}'",
      )
    }
  }
  CommitHash(s)
}

/// Get the underlying string value
pub fn CommitHash::value(self : CommitHash) -> String {
  self.0
}

/// Get the short (7-char) version of the hash
pub fn CommitHash::short(self : CommitHash) -> String {
  let s = self.0
  if s.length() <= 7 {
    return s
  }
  let chars = s.to_array()
  let sb = StringBuilder::new()
  for k = 0; k < 7; k = k + 1 {
    sb.write_char(chars[k])
  }
  sb.to_string()
}

// ============================================================================
// PackagePath
// ============================================================================

/// Create a validated PackagePath
pub fn PackagePath::new(s : String) -> PackagePath raise ValidationError {
  match validate_path_full(s, allow_absolute=false) {
    Valid => PackagePath(s)
    DirectoryTraversal =>
      raise ValidationError(
        "package path '\{s}' contains '..' (directory traversal not allowed)",
      )
    AbsolutePath =>
      raise ValidationError(
        "package path '\{s}' is absolute (only relative paths allowed)",
      )
    NullByte =>
      raise ValidationError("package path contains NUL byte")
  }
}

/// Get the underlying string value
pub fn PackagePath::value(self : PackagePath) -> String {
  self.0
}

/// Get the path prefix for file operations (adds trailing "/" unless "." or empty)
pub fn PackagePath::prefix(self : PackagePath) -> String {
  let s = self.0
  if s == "." || s.is_empty() {
    ""
  } else {
    s + "/"
  }
}

// ============================================================================
// RepositorySlug
// ============================================================================

/// Create a validated RepositorySlug from "owner/repo" format
pub fn RepositorySlug::new(
  owner : String,
  repo : String
) -> RepositorySlug raise ValidationError {
  if not(validate_repo_component_impl(owner)) {
    raise ValidationError(
      "Invalid GitHub owner: '\{owner}' (only alphanumeric, hyphen, underscore, and dot allowed)",
    )
  }
  if not(validate_repo_component_impl(repo)) {
    raise ValidationError(
      "Invalid GitHub repo: '\{repo}' (only alphanumeric, hyphen, underscore, and dot allowed)",
    )
  }
  RepositorySlug(owner + "/" + repo)
}

/// Get the underlying string value
pub fn RepositorySlug::value(self : RepositorySlug) -> String {
  self.0
}

/// Get the owner part
pub fn RepositorySlug::owner(self : RepositorySlug) -> String {
  let s = self.0
  let parts : Array[String] = s.split("/").map(fn(sv) { sv.to_string() }).collect()
  parts[0]
}

/// Get the repo part
pub fn RepositorySlug::repo(self : RepositorySlug) -> String {
  let s = self.0
  let parts : Array[String] = s.split("/").map(fn(sv) { sv.to_string() }).collect()
  parts[1]
}

// ============================================================================
// Shared validation logic
// ============================================================================

/// Validate git ref name (branch/tag) according to git-check-ref-format rules
/// Returns None if valid, Some(reason) if invalid
pub fn validate_git_ref_name_impl(name : String) -> String? {
  if name.is_empty() {
    return Some("ref name cannot be empty")
  }

  let chars = name.to_array()
  let len = chars.length()

  // Cannot start with '/' or '.'
  if chars[0] == '/' || chars[0] == '.' {
    return Some("ref name cannot start with '/' or '.'")
  }

  // Cannot end with '/' or '.'
  if chars[len - 1] == '/' || chars[len - 1] == '.' {
    return Some("ref name cannot end with '/' or '.'")
  }

  // Cannot end with ".lock"
  if name.has_suffix(".lock") {
    return Some("ref name cannot end with '.lock'")
  }

  // Check for invalid characters and patterns
  for i = 0; i < len; i = i + 1 {
    let c = chars[i]

    // Control characters (ASCII 0-31, 127)
    if c.to_int() < 32 || c.to_int() == 127 {
      return Some("ref name cannot contain control characters")
    }

    // Space
    if c == ' ' {
      return Some("ref name cannot contain spaces")
    }

    // Invalid special characters: ~ ^ : \ ? * [
    if c == '~' || c == '^' || c == ':' || c == '\\' || c == '?' || c == '*' || c == '[' {
      return Some("ref name cannot contain special characters (~^:\\?*[)")
    }

    // Check for ".." (two consecutive dots)
    if c == '.' && i + 1 < len && chars[i + 1] == '.' {
      return Some("ref name cannot contain '..'")
    }

    // Check for "//" (two consecutive slashes)
    if c == '/' && i + 1 < len && chars[i + 1] == '/' {
      return Some("ref name cannot contain '//'")
    }

    // Check for "@{" sequence
    if c == '@' && i + 1 < len && chars[i + 1] == '{' {
      return Some("ref name cannot contain '@{'")
    }
  }

  None
}

/// Validate a GitHub repository component (owner or repo name)
pub fn validate_repo_component_impl(s : String) -> Bool {
  if s.is_empty() {
    return false
  }
  // Length limit (GitHub allows up to ~100 characters)
  if s.length() > 100 {
    return false
  }
  // Cannot start with a hyphen
  let chars = s.to_array()
  if chars[0] == '-' {
    return false
  }
  // Reject "." and ".." (directory traversal)
  if s == "." || s == ".." {
    return false
  }
  for i = 0; i < chars.length(); i = i + 1 {
    let c = chars[i]
    if not(
      (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.',
    ) {
      return false
    }
  }
  true
}
