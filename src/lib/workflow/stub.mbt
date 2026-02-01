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

  let lines : Array[String] = []
  lines.push("## What's Changed\n")

  for i = 0; i < commits.length(); i = i + 1 {
    let (commit, hash) = commits[i]
    let scope_str = match commit.scope {
      Some(s) => "**\{s}**: "
      None => ""
    }
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
    lines.push("- \{scope_str}\{commit.description} (\{short_hash})")
  }

  lines.iter().fold(init="", fn(acc, line) { acc + line + "\n" })
}

/// Package release info (for PR body generation)
pub struct PackageReleaseInfo {
  name : String
  old_version : @semver.Version
  new_version : @semver.Version
  commits : Array[(@conventional.ConventionalCommit, String)]
}

/// Build PR body for monorepo (release-plz style)
pub fn build_pr_body_monorepo(
  packages : Array[PackageReleaseInfo]
) -> String {
  if packages.is_empty() {
    return "No packages to release."
  }

  let sb = StringBuilder::new()

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
      sb.write_string("## `\{pkg.name}`\n\n")
      sb.write_string("<blockquote>\n\n")
      sb.write_string(generate_package_changelog(pkg.commits))
      sb.write_string("</blockquote>\n\n")
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
