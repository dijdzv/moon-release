/// Shared helper: extract first 7 characters of a hash string
fn short_hash(hash : String) -> String {
  if hash.length() >= 7 {
    let chars = hash.to_array()
    let sb = StringBuilder::new()
    for k = 0; k < 7; k = k + 1 {
      sb.write_char(chars[k])
    }
    sb.to_string()
  } else {
    hash
  }
}

/// Return priority of BumpType (Major > Minor > Patch)
pub fn bump_priority(bump : @semver.BumpType) -> Int {
  match bump {
    Major => 3
    Minor => 2
    Patch => 1
  }
}

/// Validate path does not contain directory traversal
/// Delegates to util module for common validation logic
pub fn validate_path(path : String) -> Bool {
  @util.is_safe_path(path)
}

/// Validate git ref name (branch/tag) according to git-check-ref-format rules
/// Returns None if valid, Some(reason) if invalid
/// Delegates to util module for shared validation logic
pub fn validate_git_ref_name(name : String) -> String? {
  @util.validate_git_ref_name_impl(name)
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

    // Check for consecutive dots (empty segments)
    if c == '.' && i + 1 < chars.length() && chars[i + 1] == '.' {
      return Some("prerelease identifier cannot contain consecutive dots")
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

/// Parse an npm build command string into an argument array.
/// Falls back to the default "moon build --target js" if None.
/// Note: Simple space-based splitting is used. Commands with quoted arguments
/// containing spaces (e.g., 'echo "hello world"') are not supported.
/// Use a wrapper script for complex commands.
fn parse_npm_build_command(cmd : String?) -> Array[String] {
  match cmd {
    Some(c) => c.split(" ").map(fn(s) { s.to_string() }).collect()
    None => ["moon", "build", "--target", "js"]
  }
}

/// Get the npm build command (from config or default)
pub fn get_npm_build_command(config : @config.Config) -> Array[String] {
  parse_npm_build_command(config.npm_build_command)
}

/// Get the npm build command for a package (from package config or default)
pub fn get_pkg_npm_build_command(pkg : @config.PackageConfig) -> Array[String] {
  parse_npm_build_command(pkg.npm_build_command)
}

/// Generate release notes (from commit summary)
pub fn generate_release_notes(
  commits : Array[(@conventional.ConventionalCommit, String)]
) -> String {
  if commits.is_empty() {
    return "No changes."
  }

  let sb = StringBuilder::new()
  sb.write_string("## What's Changed\n\n")

  for i = 0; i < commits.length(); i = i + 1 {
    let (commit, hash) = commits[i]
    let scope_str = match commit.scope {
      Some(s) => "**\{s}**: "
      None => ""
    }
    let shash = short_hash(hash)
    sb.write_string("- \{scope_str}\{commit.description} (\{shash})\n")
  }

  sb.to_string()
}

/// Generate changelog for a single package
fn generate_package_changelog(
  commits : Array[(@conventional.ConventionalCommit, String)]
) -> String {
  if commits.is_empty() {
    return "No changes.\n"
  }

  // Group commits by type
  let features : Array[String] = []
  let fixes : Array[String] = []
  let others : Array[String] = []

  for i = 0; i < commits.length(); i = i + 1 {
    let (commit, hash) = commits[i]
    let shash = short_hash(hash)

    let scope_str = match commit.scope {
      Some(s) => "**\{s}**: "
      None => ""
    }
    let line = "- \{scope_str}\{commit.description} (\{shash})"

    match commit.typ {
      Feat => features.push(line)
      Fix => fixes.push(line)
      _ => others.push(line)
    }
  }

  let sb = StringBuilder::new()

  if not(features.is_empty()) {
    sb.write_string("### Features\n\n")
    for line in features {
      sb.write_string(line)
      sb.write_string("\n")
    }
    sb.write_string("\n")
  }

  if not(fixes.is_empty()) {
    sb.write_string("### Bug Fixes\n\n")
    for line in fixes {
      sb.write_string(line)
      sb.write_string("\n")
    }
    sb.write_string("\n")
  }

  if not(others.is_empty()) {
    sb.write_string("### Other Changes\n\n")
    for line in others {
      sb.write_string(line)
      sb.write_string("\n")
    }
    sb.write_string("\n")
  }

  sb.to_string()
}

/// Build PR body (apply template)
pub fn build_pr_body(ctx : ReleaseContext) -> String {
  ctx.config.pr_body
    .replace(old="{{ version }}", new=ctx.new_version.to_string())
    .replace(old="{{ changelog }}", new=generate_release_notes(ctx.commits))
}

/// Build PR body (release-plz style)
/// Works for both single package and monorepo
pub fn build_pr_body_unified(
  packages : Array[PackageReleaseInfo]
) -> String {
  if packages.is_empty() {
    return "No packages to release."
  }

  let sb = StringBuilder::new()
  let is_single_package = packages.length() == 1

  // Header
  sb.write_string("## 🤖 New release\n\n")

  // Package version list
  for pkg in packages {
    sb.write_string("* `\{pkg.name}`: \{pkg.old_version.to_string()} -> \{pkg.new_version.to_string()}\n")
  }

  // Collapsible changelog
  sb.write_string("\n<details><summary><i><b>Changelog</b></i></summary><p>\n\n")

  for pkg in packages {
    if not(pkg.commits.is_empty()) {
      // Only show package name header if multiple packages (like release-plz)
      if not(is_single_package) {
        sb.write_string("## `\{pkg.name}`\n\n")
        sb.write_string("<blockquote>\n\n")
      }
      sb.write_string(generate_package_changelog(pkg.commits))
      if not(is_single_package) {
        sb.write_string("</blockquote>\n\n")
      }
    }
  }

  sb.write_string("</p></details>\n\n")
  sb.write_string("---\n")
  sb.write_string("*This PR was automatically created by moon-release.*\n")

  sb.to_string()
}
