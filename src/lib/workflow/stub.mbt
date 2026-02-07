/// Stub for non-native targets
/// The workflow module requires native target

/// Release context
pub struct ReleaseContext {
  config : @config.Config
  repo : @git.Repository
  current_version : @semver.Version
  new_version : @semver.Version
  commits : Array[(@conventional.ConventionalCommit, String)]
  dry_run : Bool
  verbose : Bool
}

/// Workflow error
pub suberror WorkflowError {
  WorkflowError(String)
}

/// Create ReleaseContext
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

/// update command (stub)
pub fn run_update(_ctx : ReleaseContext) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

/// release-pr command (stub)
pub fn run_release_pr(
  _ctx : ReleaseContext,
  _github : @github.GitHubClient
) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

/// release command (stub)
pub fn run_release(
  _ctx : ReleaseContext,
  _github : @github.GitHubClient
) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

/// publish command (stub)
pub fn run_publish(_ctx : ReleaseContext) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

/// Monorepo: update multiple packages (stub)
pub fn run_update_packages(
  _config : @config.Config,
  _repo : @git.Repository,
  _dry_run : Bool,
  _verbose : Bool
) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

/// Monorepo: publish multiple packages (stub)
pub fn run_publish_packages(
  _config : @config.Config,
  _dry_run : Bool,
  _verbose : Bool
) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

/// Return priority of BumpType (Major > Minor > Patch)
pub fn bump_priority(bump : @semver.BumpType) -> Int {
  match bump {
    Major => 3
    Minor => 2
    Patch => 1
  }
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
    let short_hash = if hash.length() >= 7 {
      let chars = hash.to_array()
      let hsb = StringBuilder::new()
      for k = 0; k < 7; k = k + 1 {
        hsb.write_char(chars[k])
      }
      hsb.to_string()
    } else {
      hash
    }
    sb.write_string("- \{scope_str}\{commit.description} (\{short_hash})\n")
  }

  sb.to_string()
}

/// Package release info (for PR body generation)
pub struct PackageReleaseInfo {
  name : String
  old_version : @semver.Version
  new_version : @semver.Version
  commits : Array[(@conventional.ConventionalCommit, String)]
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
    let short_hash = if hash.length() >= 7 {
      let chars = hash.to_array()
      let sb = StringBuilder::new()
      for k = 0; k < 7; k = k + 1 {
        sb.write_char(chars[k])
      }
      sb.to_string()
    } else {
      hash
    }

    let scope_str = match commit.scope {
      Some(s) => "**\{s}**: "
      None => ""
    }
    let line = "- \{scope_str}\{commit.description} (\{short_hash})"

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

/// Validate path does not contain directory traversal
pub fn validate_path(path : String) -> Bool {
  @util.is_safe_path(path)
}

/// Build PR body (apply template)
pub fn build_pr_body(ctx : ReleaseContext) -> String {
  ctx.config.pr_body
    .replace(old="{{ version }}", new=ctx.new_version.to_string())
    .replace(old="{{ changelog }}", new=generate_release_notes(ctx.commits))
}

/// Validate git ref name (branch/tag) according to git-check-ref-format rules
/// Returns None if valid, Some(reason) if invalid
pub fn validate_git_ref_name(name : String) -> String? {
  if name.is_empty() {
    return Some("ref name cannot be empty")
  }

  let chars = name.to_array()
  let len = chars.length()

  if chars[0] == '/' || chars[0] == '.' {
    return Some("ref name cannot start with '/' or '.'")
  }

  if chars[len - 1] == '/' || chars[len - 1] == '.' {
    return Some("ref name cannot end with '/' or '.'")
  }

  if name.has_suffix(".lock") {
    return Some("ref name cannot end with '.lock'")
  }

  for i = 0; i < len; i = i + 1 {
    let c = chars[i]

    if c.to_int() < 32 || c.to_int() == 127 {
      return Some("ref name cannot contain control characters")
    }

    if c == ' ' {
      return Some("ref name cannot contain spaces")
    }

    if c == '~' || c == '^' || c == ':' || c == '\\' || c == '?' || c == '*' || c == '[' {
      return Some("ref name cannot contain special characters (~^:\\?*[)")
    }

    if c == '.' && i + 1 < len && chars[i + 1] == '.' {
      return Some("ref name cannot contain '..'")
    }

    if c == '/' && i + 1 < len && chars[i + 1] == '/' {
      return Some("ref name cannot contain '//'")
    }

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

    // Check for consecutive dots (empty segments)
    if c == '.' && i + 1 < chars.length() && chars[i + 1] == '.' {
      return Some("prerelease identifier cannot contain consecutive dots")
    }
  }

  if chars[0] == '.' || chars[0] == '-' {
    return Some("prerelease identifier cannot start with '.' or '-'")
  }

  let last = chars[chars.length() - 1]
  if last == '.' || last == '-' {
    return Some("prerelease identifier cannot end with '.' or '-'")
  }

  None
}

/// Validate publish configuration (stub)
pub fn validate_publish_config(
  _config : @config.Config,
  verbose~ : Bool = false
) -> Unit raise WorkflowError {
  ignore(verbose)
  raise WorkflowError("Workflow requires native target")
}

/// Read version from package.json (stub)
pub fn get_package_json_version() -> @semver.Version? raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

/// Get current version (stub)
pub fn get_current_version(
  _config : @config.Config
) -> @semver.Version raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

/// Pre-build JS target (stub)
pub fn pre_build_js(_ctx : ReleaseContext) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

/// npm publish (stub)
pub fn run_npm_publish(_ctx : ReleaseContext) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

/// Collect package release info (stub)
pub fn collect_package_release_info(
  _config : @config.Config,
  _repo : @git.Repository,
  _verbose : Bool
) -> Array[PackageReleaseInfo] raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

/// Get registry version (stub)
pub fn get_registry_version(
  _package_name : String
) -> @semver.Version? raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

/// Check if should release (stub)
pub fn should_release(
  _local_version : @semver.Version,
  _package_name : String,
  _verbose : Bool
) -> Bool raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

/// Run semver check (stub)
pub fn run_semver_check(
  _repo : @git.Repository,
  _verbose : Bool
) -> @semver_check.CheckResult raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

/// Get the npm build command (from config or default)
pub fn get_npm_build_command(config : @config.Config) -> Array[String] {
  match config.npm_build_command {
    Some(cmd) => cmd.split(" ").map(fn(s) { s.to_string() }).collect()
    None => ["moon", "build", "--target", "js"]
  }
}
