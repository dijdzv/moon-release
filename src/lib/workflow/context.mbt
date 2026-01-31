/// リリースコンテキスト
pub struct ReleaseContext {
  config : @config.Config
  repo : @git.Repository
  current_version : @semver.Version
  new_version : @semver.Version
  commits : Array[(@conventional.ConventionalCommit, String)]
  dry_run : Bool
  verbose : Bool
}

/// ワークフローエラー
pub(all) suberror WorkflowError {
  WorkflowError(String)
}

/// WorkflowError を文字列に変換
pub fn WorkflowError::to_string(self : WorkflowError) -> String {
  match self {
    WorkflowError(msg) => msg
  }
}

/// Validate path does not contain directory traversal
pub fn validate_path(path : String) -> Bool {
  // Empty string and "." are allowed
  if path.is_empty() || path == "." {
    return true
  }

  // Reject paths containing ".."
  if path.contains("..") {
    return false
  }

  // Reject absolute paths (starting with /)
  let chars = path.to_array()
  if chars.length() > 0 && chars[0] == '/' {
    return false
  }

  true
}

/// Validate git ref name (branch/tag) according to git-check-ref-format rules
/// Returns None if valid, Some(reason) if invalid
pub fn validate_git_ref_name(name : String) -> String? {
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

/// Validate semver prerelease identifier (alphanumeric and hyphens only)
/// Returns None if valid, Some(reason) if invalid
pub fn validate_prerelease_identifier(id : String) -> String? {
  if id.is_empty() {
    return Some("prerelease identifier cannot be empty")
  }

  let chars = id.to_array()

  for i = 0; i < chars.length(); i = i + 1 {
    let c = chars[i]
    let is_valid = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '.'

    if not(is_valid) {
      return Some(
        "prerelease identifier can only contain alphanumeric characters, hyphens, and dots",
      )
    }
  }

  // Cannot start or end with dot or hyphen
  if chars[0] == '.' || chars[0] == '-' {
    return Some("prerelease identifier cannot start with '.' or '-'")
  }

  let last = chars[chars.length() - 1]
  if last == '.' || last == '-' {
    return Some("prerelease identifier cannot end with '.' or '-'")
  }

  None
}

/// ReleaseContext を作成
pub fn ReleaseContext::new(
  config : @config.Config,
  repo : @git.Repository,
  current_version : @semver.Version,
  new_version : @semver.Version,
  commits : Array[(@conventional.ConventionalCommit, String)],
  dry_run~ : Bool = false,
  verbose~ : Bool = false
) -> ReleaseContext {
  ReleaseContext::{
    config,
    repo,
    current_version,
    new_version,
    commits,
    dry_run,
    verbose,
  }
}
