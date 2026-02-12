///|
/// Get latest tag from repository
pub async fn get_latest_tag(
  repo : @git.Repository,
) -> String? raise WorkflowError {
  let cmd = repo.get_latest_tag_command()
  let result = try @executor.run_command(cmd) catch {
    e =>
      raise ExternalCommandError("Failed to run git describe: " + e.to_string())
  } noraise {
    r => r
  }
  if result.is_success() {
    let tag = result.stdout_trimmed()
    if tag.is_empty() {
      None
    } else {
      Some(tag)
    }
  } else {
    None
  }
}

///|
/// Get commits from latest tag to current
pub async fn get_commits_since_last_tag(
  repo : @git.Repository,
  pr_title~ : String,
  max_commits? : UInt? = None,
) -> Array[(@conventional.ConventionalCommit, String)] raise WorkflowError {
  // Get latest tag
  let latest_tag = try get_latest_tag(repo) catch {
    _ => None
  } noraise {
    r => r
  }

  // Get commit log
  let log_result = match latest_tag {
    Some(tag) => {
      let cmd = try repo.get_commits_since_tag_command(tag) catch {
        e =>
          raise ExternalCommandError(
            "Failed to build git log command: " + e.to_string(),
          )
      } noraise {
        r => r
      }
      match max_commits {
        Some(n) => {
          cmd.push("-n")
          cmd.push(n.to_string())
        }
        None => ()
      }
      try @executor.run_command(cmd) catch {
        e =>
          raise ExternalCommandError("Failed to run git log: " + e.to_string())
      } noraise {
        r => r
      }
    }
    None => {
      // No tag found — search for the most recent release commit
      let pattern = pr_title.replace(old="{{ version }}", new="")
      let search_cmd = repo.find_release_commit_command(pattern)
      let search_result = try @executor.run_command(search_cmd) catch {
        e =>
          raise ExternalCommandError(
            "Failed to search for release commit: " + e.to_string(),
          )
      } noraise {
        r => r
      }
      let release_hash = if search_result.is_success() {
        search_result.stdout_trimmed()
      } else {
        ""
      }
      if release_hash.is_empty() {
        raise GitError(
          "No previous release found (no git tag or release commit matching '" +
          pattern +
          "').\nHint: Use 'moon-release set-version <version>' to set the initial version, or create a git tag (e.g. 'git tag v0.1.0')",
        )
      }
      let cmd = try repo.get_commits_since_tag_command(release_hash) catch {
        e =>
          raise ExternalCommandError(
            "Failed to build git log command: " + e.to_string(),
          )
      } noraise {
        r => r
      }
      match max_commits {
        Some(n) => {
          cmd.push("-n")
          cmd.push(n.to_string())
        }
        None => ()
      }
      try @executor.run_command(cmd) catch {
        e =>
          raise ExternalCommandError("Failed to run git log: " + e.to_string())
      } noraise {
        r => r
      }
    }
  }

  // Verify git log succeeded
  if not(log_result.is_success()) {
    let detail = if log_result.stderr.is_empty() {
      "exit code " + log_result.exit_code.to_string()
    } else {
      log_result.stderr.trim().to_string()
    }
    raise ExternalCommandError("Failed to read git log: " + detail)
  }

  // Parse
  let git_commits = @git.parse_commit_log(log_result.stdout)
  @git.parse_conventional_commits(git_commits)
}

///|
/// Check working directory for uncommitted changes
/// Raises GitError if dirty and allow_dirty is false
pub async fn check_working_directory(
  config : @config.Config,
  repo : @git.Repository,
  verbose? : Bool = false,
) -> Unit raise WorkflowError {
  if config.allow_dirty {
    return
  }

  let result = try @executor.run_git(repo, ["status", "--porcelain"]) catch {
    e => {
      if verbose {
        println("Warning: Failed to check git status: " + e.to_string())
        println("Assuming working directory has changes.")
      }
      raise GitError("Failed to check git status: " + e.to_string())
    }
  } noraise {
    r => r
  }

  if not(result.stdout.trim().is_empty()) {
    let mut msg = "Working directory has uncommitted changes.\nCommit or stash your changes, or set 'allow_dirty: true' in config."
    if verbose {
      let status_result = try
        @executor.run_git(repo, ["status", "--short"])
      catch {
        _ => @executor.CommandResult::failed("status failed")
      } noraise {
        r => r
      }
      if status_result.is_success() {
        msg = msg + "\n\nChanged files:\n" + status_result.stdout
      }
    }
    raise GitError(msg)
  }
}

///|
/// Get GitHub client (owner/repo from gh CLI)
pub async fn get_github_client() -> @github.GitHubClient raise WorkflowError {
  let result = try
    @executor.run_command(["gh", "repo", "view", "--json", "owner,name"])
  catch {
    e =>
      raise ExternalCommandError(
        "Failed to get repository info: " + e.to_string(),
      )
  } noraise {
    r => r
  }

  if not(result.is_success()) {
    let hint = if result.stderr.contains("not a git repository") {
      "The current directory is not a git repository."
    } else if result.stderr.contains("gh auth login") ||
      result.stderr.contains("authentication") {
      "Run 'gh auth login' to authenticate with GitHub."
    } else if result.stderr.contains("not found") ||
      result.stderr.contains("command not found") {
      "The 'gh' CLI is not installed. Install it from https://cli.github.com/"
    } else {
      "Make sure you are in a GitHub repository and have 'gh' CLI installed and authenticated."
    }
    raise ExternalCommandError(
      "Failed to get repository info: " +
      result.stderr.trim().to_string() +
      "\nHint: " +
      hint,
    )
  }

  let json = try @json.parse(result.stdout) catch {
    e =>
      raise ExternalCommandError(
        "Failed to parse repository info from 'gh' output: " + e.to_string(),
      )
  } noraise {
    r => r
  }

  match json {
    Object(obj) => {
      let owner = match obj.get("owner") {
        Some(Object(o)) =>
          match o.get("login") {
            Some(String(s)) => s
            _ =>
              raise ExternalCommandError(
                "Invalid owner info: expected 'owner.login' to be a string in 'gh' output",
              )
          }
        _ =>
          raise ExternalCommandError(
            "Invalid owner info: expected 'owner' to be an object in 'gh' output",
          )
      }
      let name = match obj.get("name") {
        Some(String(s)) => s
        _ =>
          raise ExternalCommandError(
            "Invalid repo name: expected 'name' to be a string in 'gh' output",
          )
      }
      try @github.GitHubClient::new(owner, name) catch {
        @github.GitHubError(msg) =>
          raise ExternalCommandError("Invalid GitHub repository: " + msg)
      } noraise {
        r => r
      }
    }
    _ =>
      raise ExternalCommandError(
        "Invalid repository info: expected JSON object from 'gh' output",
      )
  }
}

///|
/// Analyze version bump for single-package mode
/// Common pipeline: get_current_version → get_commits → validate → determine_bump → bump
pub async fn analyze_version_bump(
  config : @config.Config,
  repo : @git.Repository,
  forced_bump? : @semver.BumpType? = None,
  max_commits? : UInt? = None,
  allow_empty_commits? : Bool = false,
  default_bump? : @semver.BumpType? = None,
) -> VersionAnalysis raise WorkflowError {
  let current_version = get_current_version(config)

  let commits = get_commits_since_last_tag(
    repo, pr_title=config.pr_title, max_commits~,
  )

  // Validate commits
  if commits.is_empty() && not(allow_empty_commits) {
    raise NoReleasableCommits(
      "No commits found since last tag. Nothing to release.",
    )
  }

  if commits.is_empty() && forced_bump is None && allow_empty_commits {
    // For release command: empty commits with no forced bump → use default
    match default_bump {
      Some(_) => ()
      None =>
        raise NoReleasableCommits(
          "No commits found since last tag. Nothing to release.",
        )
    }
  }

  // Determine bump type
  let bump_type = match forced_bump {
    Some(t) => t
    None =>
      match
        @semver.determine_bump_with_custom(
          commits.map(fn(c) { c.0 }),
          config.custom_major_increment_regex,
          config.custom_minor_increment_regex,
        ) {
        Some(t) => t
        None =>
          match default_bump {
            Some(t) => t
            None =>
              raise NoReleasableCommits(
                "No releasable commits found (no feat, fix, or breaking changes)",
              )
          }
      }
  }

  let new_version = @semver.bump(current_version, bump_type)

  VersionAnalysis::{ current_version, new_version, commits, bump_type }
}

///|
/// Get mooncakes credentials file path
/// Tries HOME (Unix), then USERPROFILE (Windows), then falls back to CWD-relative path.
/// Uses libc getenv for cross-platform compatibility (no dependency on printenv).
fn get_mooncakes_credentials_path() -> String {
  // Try HOME first (Unix / macOS / Linux)
  match @executor.get_env_var("HOME") {
    Some(home) => return home + "/.moon/credentials.json"
    None => ()
  }

  // Try USERPROFILE (Windows)
  match @executor.get_env_var("USERPROFILE") {
    Some(profile) => return profile + "/.moon/credentials.json"
    None => ()
  }

  // Fallback: CWD-relative path
  ".moon/credentials.json"
}

///|
/// Build the npm publish command array with standard flags
fn build_npm_publish_command(provenance : Bool) -> Array[String] {
  let cmd : Array[String] = ["npm", "publish"]
  if provenance {
    cmd.push("--provenance")
  }
  cmd.push("--access")
  cmd.push("public")
  cmd
}

///|
/// Validate publish configuration
/// Ensures required files exist for enabled publish targets
pub async fn validate_publish_config(
  config : @config.Config,
  verbose? : Bool = false,
) -> Unit raise WorkflowError {
  let is_monorepo = not(config.packages.is_empty())

  // Root-level validation: only for single-package mode
  // In monorepo mode, validation is done per-package below
  if not(is_monorepo) {
    let publish_target = config.publish_target()

    // Validate mooncakes publishing requirements
    match publish_target {
      MooncakesOnly | Both(_) => {
        let content = try @fs.read_file("moon.mod.json").text() catch {
          _ =>
            raise ConfigValidationError(
              "moon_publish is enabled but moon.mod.json not found",
            )
        } noraise {
          c => c
        }
        try @moon_mod.parse(content) catch {
          e =>
            raise ConfigValidationError(
              "moon_publish is enabled but moon.mod.json is invalid: " +
              e.to_string(),
            )
        } noraise {
          _ => ()
        }

        // Check if mooncakes credentials exist (warning only, not error)
        let creds_path = get_mooncakes_credentials_path()
        let creds_result = try @fs.read_file(creds_path).text() catch {
          _ => ""
        } noraise {
          c => c
        }

        let has_token = if creds_result.is_empty() {
          false
        } else {
          match (try? @json.parse(creds_result)).to_option() {
            Some(Object(map)) => not(map.get("token") is None)
            _ => false
          }
        }

        if not(has_token) {
          println("Warning: mooncakes credentials not found at " + creds_path)
          println("  moon publish may fail without authentication.")
          println("  Run 'moon login' to authenticate with mooncakes.io")
          if verbose {
            println(
              "  Or set MOONCAKES_TOKEN and MOONCAKES_USERNAME in CI environment",
            )
          }
        }
      }
      _ => ()
    }

    // Validate npm publishing requirements
    match publish_target {
      NpmOnly(_) | Both(_) => {
        try @fs.read_file("package.json").text() catch {
          _ =>
            raise ConfigValidationError(
              "npm_publish is enabled but package.json not found",
            )
        } noraise {
          _ => ()
        }

        if verbose {
          println("npm_publish enabled: using Trusted Publishing (OIDC)")
          println("  Make sure 'id-token: write' permission is set in workflow")
        }
      }
      _ => ()
    }
  }

  // Monorepo: validate each package's required files
  for pkg in config.packages {
    if not(validate_path(pkg.path)) {
      raise InputValidationError(
        "Invalid path for package " + pkg.name + ": " + pkg.path,
      )
    }

    let pkg_path = package_path_prefix(pkg.path)

    match pkg.publish_target() {
      MooncakesOnly | Both(_) => {
        let moon_mod_path = pkg_path + "moon.mod.json"
        let content = try @fs.read_file(moon_mod_path).text() catch {
          _ =>
            raise ConfigValidationError(
              "moon_publish is enabled for " +
              pkg.name +
              " but " +
              moon_mod_path +
              " not found",
            )
        } noraise {
          c => c
        }
        try @moon_mod.parse(content) catch {
          e =>
            raise ConfigValidationError(
              "moon_publish is enabled for " +
              pkg.name +
              " but " +
              moon_mod_path +
              " is invalid: " +
              e.to_string(),
            )
        } noraise {
          _ => ()
        }
      }
      _ => ()
    }

    match pkg.publish_target() {
      NpmOnly(_) | Both(_) => {
        let pkg_json_path = pkg_path + "package.json"
        try @fs.read_file(pkg_json_path).text() catch {
          _ =>
            raise ConfigValidationError(
              "npm_publish is enabled for " +
              pkg.name +
              " but " +
              pkg_json_path +
              " not found",
            )
        } noraise {
          _ => ()
        }
      }
      _ => ()
    }
  }
}

///|
/// Get package name from moon.mod.json
async fn get_package_name() -> String {
  // Try to read package name from moon.mod.json
  let content = try @fs.read_file("moon.mod.json").text() catch {
    _ => return "this-package"
  } noraise {
    c => c
  }

  let moon_mod = try @moon_mod.parse(content) catch {
    _ => return "this-package"
  } noraise {
    m => m
  }

  // Strip owner prefix from MoonBit module name (e.g., "dijdzv/moon-release" -> "moon-release")
  let name = moon_mod.name
  let parts = name.split("/").map(fn(sv) { sv.to_string() }).collect()
  if parts.length() > 1 {
    parts[parts.length() - 1]
  } else {
    name
  }
}

///|
/// Extract version from package.json content using JSON parser
fn parse_package_json_version(
  content : String,
) -> @semver.Version? raise WorkflowError {
  let json = try @json.parse(content) catch {
    e => raise WorkflowError("Failed to parse package.json: " + e.to_string())
  } noraise {
    j => j
  }

  match json {
    Object(map) =>
      match map.get("version") {
        Some(String(version_str)) => @semver.Version::parse(version_str)
        _ => None
      }
    _ => raise WorkflowError("package.json is not a valid JSON object")
  }
}

///|
/// Read version from package.json file
pub async fn get_package_json_version() -> @semver.Version? raise WorkflowError {
  let content = try @fs.read_file("package.json").text() catch {
    _ => return None
  } noraise {
    c => c
  }

  parse_package_json_version(content)
}

///|
/// Get current version from the appropriate source based on config
/// If both moon_publish and npm_publish are enabled, returns the higher version
pub async fn get_current_version(
  config : @config.Config,
) -> @semver.Version raise WorkflowError {
  let publish_target = config.publish_target()
  let mut moon_version : @semver.Version? = None
  let mut npm_version : @semver.Version? = None

  // Read from moon.mod.json if mooncakes publishing is enabled
  match publish_target {
    MooncakesOnly | Both(_) => {
      let content = try @fs.read_file("moon.mod.json").text() catch {
        e =>
          raise WorkflowError("Failed to read moon.mod.json: " + e.to_string())
      } noraise {
        c => c
      }

      let moon_mod = try @moon_mod.parse(content) catch {
        e =>
          raise WorkflowError("Failed to parse moon.mod.json: " + e.to_string())
      } noraise {
        m => m
      }

      match @semver.Version::parse(moon_mod.version) {
        Some(v) => moon_version = Some(v)
        None =>
          raise WorkflowError(
            "Invalid version in moon.mod.json: " + moon_mod.version,
          )
      }
    }
    _ => ()
  }

  // Read from package.json if npm publishing is enabled
  match publish_target {
    NpmOnly(_) | Both(_) =>
      match get_package_json_version() {
        Some(v) => npm_version = Some(v)
        None => raise WorkflowError("Failed to read version from package.json")
      }
    _ => ()
  }

  // Return the higher version if both are available
  match (moon_version, npm_version) {
    (Some(mv), Some(nv)) =>
      // Compare and return higher version
      if mv.compare(nv) >= 0 {
        mv
      } else {
        nv
      }
    (Some(mv), None) => mv
    (None, Some(nv)) => nv
    (None, None) =>
      raise ConfigValidationError(
        "No publish target enabled. Enable moon_publish or npm_publish.",
      )
  }
}

///|
/// Read a package's current version from moon.mod.json and/or package.json
/// If both are enabled, returns the higher version (consistent with get_current_version)
async fn get_package_current_version(
  pkg : @config.PackageConfig,
) -> @semver.Version? raise WorkflowError {
  let pkg_path = package_path_prefix(pkg.path)
  let mut moon_version : @semver.Version? = None
  let mut npm_version : @semver.Version? = None

  // Read from moon.mod.json if moon_publish is enabled
  if pkg.moon_publish {
    let moon_mod_path = pkg_path + "moon.mod.json"
    let content = try @fs.read_file(moon_mod_path).text() catch {
      _ => ""
    } noraise {
      c => c
    }
    if not(content.is_empty()) {
      moon_version = try {
        let moon_mod = @moon_mod.parse(content)
        @semver.Version::parse(moon_mod.version)
      } catch {
        _ => None
      } noraise {
        v => v
      }
    }
  }

  // Read from package.json if npm_publish is enabled
  if pkg.npm_publish {
    let pkg_json_path = pkg_path + "package.json"
    let content = try @fs.read_file(pkg_json_path).text() catch {
      _ => ""
    } noraise {
      c => c
    }
    if not(content.is_empty()) {
      npm_version = try parse_package_json_version(content) catch {
        _ => None
      } noraise {
        v => v
      }
    }
  }

  // Return the higher version if both are available
  match (moon_version, npm_version) {
    (Some(mv), Some(nv)) =>
      if mv.compare(nv) >= 0 {
        Some(mv)
      } else {
        Some(nv)
      }
    (Some(mv), None) => Some(mv)
    (None, Some(nv)) => Some(nv)
    (None, None) => None
  }
}

///|
/// Get monorepo representative version
/// Returns (max_current_version, max_new_version, all_commits) across packages
/// The representative version is the highest new_version among target packages.
/// When bump_all is false, only changed packages are targeted.
/// Determine the effective bump type for bump_all mode (2-pass).
/// Pass 1 scans all packages to find the max bump type, which is then applied uniformly.
/// Returns forced_bump directly if provided, or None if bump_all is false.
async fn compute_effective_bump(
  config : @config.Config,
  repo : @git.Repository,
  forced_bump : @semver.BumpType?,
  bump_all : Bool,
) -> @semver.BumpType? raise WorkflowError {
  if not(bump_all) || forced_bump is Some(_) {
    return forced_bump
  }
  // Pass 1: find the max bump type across changed packages
  let mut max_bump_priority = 0
  let mut max_bump : @semver.BumpType? = None
  for pkg in config.packages {
    if not(validate_path(pkg.path)) {
      continue
    }
    let commits = try get_package_commits(repo, pkg.path, pr_title=config.pr_title) catch {
      _ => continue
    } noraise {
      c => c
    }
    if commits.is_empty() {
      continue
    }
    match
      @semver.determine_bump_with_custom(
        commits.map(fn(c) { c.0 }),
        config.custom_major_increment_regex,
        config.custom_minor_increment_regex,
      ) {
      Some(t) => {
        let p = bump_priority(t)
        if p > max_bump_priority {
          max_bump_priority = p
          max_bump = Some(t)
        }
      }
      None => ()
    }
  }
  max_bump
}

///|
/// When bump_all is true, all packages are targeted (unchanged packages use the max bump type).
/// Used for tag names, branch names, and release titles in monorepo mode
///
/// Note: The order of `all_commits` depends on package traversal order in config,
/// not on chronological commit order. ConventionalCommit has no timestamp field,
/// so chronological sorting is not possible without additional git queries.
pub async fn get_monorepo_representative_version(
  config : @config.Config,
  repo : @git.Repository,
  forced_bump : @semver.BumpType?,
  verbose : Bool,
  bump_all? : Bool = false,
) -> (
  @semver.Version,
  @semver.Version,
  Array[(@conventional.ConventionalCommit, String)],
) raise WorkflowError {
  let plans = resolve_version_plan(
    config,
    repo,
    forced_bump,
    verbose,
    bump_all~,
  )

  if plans.is_empty() {
    raise NoReleasableCommits("No releasable commits found across packages")
  }

  // Extract representative version (highest new_version) and deduplicated commits
  let mut max_new : @semver.Version? = None
  let mut max_current : @semver.Version? = None
  let all_commits : Array[(@conventional.ConventionalCommit, String)] = []
  let seen_hashes : @hashmap.HashMap[String, Bool] = @hashmap.new()

  for plan in plans {
    // Deduplicate commits by hash
    for commit in plan.commits {
      let (_, hash) = commit
      if not(seen_hashes.contains(hash)) {
        seen_hashes.set(hash, true)
        all_commits.push(commit)
      }
    }

    match max_new {
      Some(mn) =>
        if plan.new_version.compare(mn) > 0 {
          max_new = Some(plan.new_version)
          max_current = Some(plan.old_version)
        }
      None => {
        max_new = Some(plan.new_version)
        max_current = Some(plan.old_version)
      }
    }
  }

  let current = match max_current {
    Some(v) => v
    None =>
      raise NoReleasableCommits("No releasable commits found across packages")
  }

  let new_version = match max_new {
    Some(v) => v
    None =>
      raise NoReleasableCommits("No releasable commits found across packages")
  }

  (current, new_version, all_commits)
}

///|
/// Update package.json version field
/// Delegates to @moon_mod.replace_json_field for format-preserving replacement.
/// Returns the updated content, or None if file doesn't exist.
async fn update_package_json_version(
  new_version : @semver.Version,
  path? : String = "package.json",
) -> String? raise WorkflowError {
  // Try to read package.json
  let content = try @fs.read_file(path).text() catch {
    _ => return None // File doesn't exist, that's OK
  } noraise {
    c => c
  }

  // Verify package.json has a valid version field
  match parse_package_json_version(content) {
    Some(_) => ()
    None =>
      raise WorkflowError(
        "package.json does not contain a valid 'version' field",
      )
  }

  // Delegate to replace_json_field (format-preserving, top-level key only)
  let result = try
    @moon_mod.replace_json_field(content, "version", new_version.to_string())
  catch {
    e =>
      raise WorkflowError(
        "Failed to update version in package.json: " + e.to_string(),
      )
  } noraise {
    r => r
  }

  // Preserve trailing newline
  if content.has_suffix("\n") && not(result.has_suffix("\n")) {
    Some(result + "\n")
  } else {
    Some(result)
  }
}

///|
/// update command: local update only
pub async fn run_update(ctx : ReleaseContext) -> Unit raise WorkflowError {
  if ctx.verbose {
    println("Running update workflow...")
    println("  Current version: \{ctx.current_version.to_string()}")
    println("  New version: \{ctx.new_version.to_string()}")
    println("  Commits: \{ctx.commits.length()}")
  }

  let publish_target = ctx.config.publish_target()

  if ctx.dry_run {
    match publish_target {
      MooncakesOnly =>
        println(
          "[dry-run] Would update moon.mod.json to version \{ctx.new_version.to_string()}",
        )
      NpmOnly(_) =>
        println(
          "[dry-run] Would update package.json to version \{ctx.new_version.to_string()}",
        )
      Both(_) => {
        println(
          "[dry-run] Would update moon.mod.json to version \{ctx.new_version.to_string()}",
        )
        println(
          "[dry-run] Would update package.json to version \{ctx.new_version.to_string()}",
        )
      }
      NoPublish => ()
    }
    return
  }

  // Update moon.mod.json if mooncakes publishing is enabled
  match publish_target {
    MooncakesOnly | Both(_) => {
      let moon_mod_content = try @fs.read_file("moon.mod.json").text() catch {
        e =>
          raise WorkflowError(
            "Failed to read moon.mod.json: " +
            e.to_string() +
            ". Make sure the file exists and is readable.",
          )
      } noraise {
        c => c
      }

      let updated_content = try
        @moon_mod.update_version(moon_mod_content, ctx.new_version)
      catch {
        e =>
          raise WorkflowError(
            "Failed to update version in moon.mod.json: " + e.to_string(),
          )
      } noraise {
        c => c
      }

      try @fs.write_file("moon.mod.json", updated_content, create=0o644) catch {
        e =>
          raise WorkflowError(
            "Failed to write moon.mod.json: " +
            e.to_string() +
            ". Check file permissions.",
          )
      } noraise {
        _ => ()
      }

      println("Updated moon.mod.json to version \{ctx.new_version.to_string()}")
    }
    _ => ()
  }

  // Update package.json if npm publishing is enabled
  match publish_target {
    NpmOnly(_) | Both(_) =>
      match update_package_json_version(ctx.new_version) {
        Some(updated_pkg_json) => {
          try
            @fs.write_file("package.json", updated_pkg_json, create=0o644)
          catch {
            e =>
              raise WorkflowError(
                "Failed to write package.json: " + e.to_string(),
              )
          } noraise {
            _ => ()
          }
          println(
            "Updated package.json to version \{ctx.new_version.to_string()}",
          )
        }
        None =>
          raise ConfigValidationError(
            "npm_publish is enabled but package.json not found",
          )
      }
    _ => ()
  }
}

///|
/// release-pr command: create or update PR
pub async fn run_release_pr(
  ctx : ReleaseContext,
  github : @github.GitHubClient,
) -> Unit raise WorkflowError {
  if ctx.verbose {
    println("Running release-pr workflow...")
  }

  let base_branch = ctx.config.base_branch

  // Validate base branch name
  match validate_git_ref_name(base_branch) {
    Some(reason) =>
      raise InputValidationError(
        "Invalid base_branch '\{base_branch}': \{reason}",
      )
    None => ()
  }

  // Find existing release PR (errors are suppressed to None)
  let existing_pr = try
    find_existing_release_pr(github, ctx.config.pr_branch_prefix)
  catch {
    _ => None
  } noraise {
    r => r
  }

  // Reuse existing PR's branch name, or create a new one based on module name.
  let branch_name = match existing_pr {
    Some((_, pr_branch)) => pr_branch
    None => {
      let pkg_name = try get_package_name() catch {
        _ => "this-package"
      } noraise {
        n => n
      }
      ctx.config.pr_branch_prefix + pkg_name
    }
  }

  // Validate branch name
  match validate_git_ref_name(branch_name) {
    Some(reason) =>
      raise InputValidationError(
        "Invalid branch name '\{branch_name}': \{reason}",
      )
    None => ()
  }

  if ctx.dry_run {
    match existing_pr {
      Some((pr_num, _)) => {
        println("[dry-run] Would update existing PR #\{pr_num}")
        println("[dry-run] Would update branch: " + branch_name)
      }
      None => {
        println("[dry-run] Would create release branch: " + branch_name)
        println("[dry-run] Would commit changes")
        println("[dry-run] Would create pull request")
      }
    }
    return
  }

  // Fetch base branch from remote to ensure we branch from the latest state
  let fetch_result = (try? @executor.run_git(ctx.repo, [
    "fetch", "origin", base_branch,
  ])).unwrap_or(@executor.CommandResult::failed("fetch failed"))
  if not(fetch_result.is_success()) && ctx.verbose {
    println(
      "[WARN] Failed to fetch origin/" +
      base_branch +
      ": " +
      fetch_result.stderr,
    )
    println("[WARN] Continuing with local branch state...")
  }

  // Create/reset branch from origin/base_branch (ensures we start from latest base)
  let start_point = if fetch_result.is_success() {
    "origin/" + base_branch
  } else {
    base_branch
  }
  let checkout_result = try
    @executor.run_git(ctx.repo, ["checkout", "-B", branch_name, start_point])
  catch {
    e =>
      raise GitError(
        "Failed to create/checkout branch '" +
        branch_name +
        "': " +
        e.to_string(),
      )
  } noraise {
    r => r
  }
  if not(checkout_result.is_success()) {
    raise GitError(
      "Failed to create/checkout branch '" +
      branch_name +
      "': " +
      checkout_result.stderr,
    )
  }

  let branch_recovery_note = "\nNote: You may be on branch '" +
    branch_name +
    "'. Run 'git checkout " +
    base_branch +
    "' to return."

  // Collect package release info BEFORE file updates (so old_version is accurate)
  let is_monorepo = not(ctx.config.packages.is_empty())
  let monorepo_pkg_info : Array[PackageReleaseInfo] = if is_monorepo {
    try
      collect_package_release_info(
        ctx.config,
        ctx.repo,
        ctx.verbose,
        forced_bump=ctx.forced_bump,
        bump_all=ctx.bump_all,
      )
    catch {
      e => {
        if ctx.verbose {
          println("[WARN] Failed to collect package info: " + e.to_string())
        }
        []
      }
    } noraise {
      r => r
    }
  } else {
    []
  }

  // Run update (file updates)
  if is_monorepo {
    try
      run_update_packages(
        ctx.config,
        ctx.repo,
        ctx.dry_run,
        ctx.verbose,
        forced_bump=ctx.forced_bump,
        bump_all=ctx.bump_all,
      )
    catch {
      e => {
        let _ = try? restore_branch(ctx.repo, base_branch, ctx.verbose)
        raise e.add_context(branch_recovery_note)
      }
    } noraise {
      _ => ()
    }
  } else {
    try run_update(ctx) catch {
      e => {
        let _ = try? restore_branch(ctx.repo, base_branch, ctx.verbose)
        raise e.add_context(branch_recovery_note)
      }
    } noraise {
      _ => ()
    }
  }

  // Stage changes - add relevant files based on publish configuration
  let files_to_stage = collect_files_to_stage(ctx)
  let stage_result = try @executor.run_git(ctx.repo, files_to_stage) catch {
    e => {
      let _ = try? restore_branch(ctx.repo, base_branch, ctx.verbose)
      raise GitError(
        "Failed to stage files: " + e.to_string() + branch_recovery_note,
      )
    }
  } noraise {
    r => r
  }
  if not(stage_result.is_success()) {
    let _ = try? restore_branch(ctx.repo, base_branch, ctx.verbose)
    raise GitError(
      "Failed to stage files: " + stage_result.stderr + branch_recovery_note,
    )
  }

  // Check if there are changes with try-catch-noraise pattern
  let diff_result = try
    @executor.run_git(ctx.repo, ["diff", "--cached", "--quiet"])
  catch {
    e => {
      if ctx.verbose {
        println("[WARN] Failed to check staged changes: " + e.to_string())
      }
      @executor.CommandResult::failed("diff check failed: " + e.to_string())
    }
  } noraise {
    r => r
  }

  if diff_result.is_success() {
    println("No changes to commit. Release PR is up to date.")
    // Return to original branch with try-catch-noraise pattern
    let checkout_back_result = try
      @executor.run_git(ctx.repo, ["checkout", base_branch])
    catch {
      e => {
        if ctx.verbose {
          println("[WARN] Failed to return to base branch: " + e.to_string())
        }
        @executor.CommandResult::failed("checkout failed: " + e.to_string())
      }
    } noraise {
      r => r
    }
    if not(checkout_back_result.is_success()) && ctx.verbose {
      println(
        "[WARN] Could not checkout " +
        base_branch +
        ": " +
        checkout_back_result.stderr,
      )
      println(
        "[WARN] You may need to manually checkout: git checkout " + base_branch,
      )
    }
    return
  }

  // Commit with try-catch-noraise pattern
  let commit_msg = ctx.config.apply_pr_title_template(
    ctx.new_version.to_string(),
  )
  let commit_result = try
    @executor.run_git(ctx.repo, ["commit", "-m", commit_msg])
  catch {
    e => {
      let _ = try? restore_branch(ctx.repo, base_branch, ctx.verbose)
      raise GitError(
        "Failed to commit: " + e.to_string() + branch_recovery_note,
      )
    }
  } noraise {
    r => r
  }
  if not(commit_result.is_success()) {
    let _ = try? restore_branch(ctx.repo, base_branch, ctx.verbose)
    raise GitError(
      "Failed to commit: " + commit_result.stderr + branch_recovery_note,
    )
  }

  // Push (force push to update)
  // Using --force-with-lease instead of --force for safety:
  // it will fail if someone else pushed to the branch since our last fetch
  if ctx.verbose {
    println("Pushing with --force-with-lease (safe force push)...")
  }
  let push_result = try
    @executor.run_git(ctx.repo, [
      "push", "-u", "--force-with-lease", "origin", branch_name,
    ])
  catch {
    e => {
      let _ = try? restore_branch(ctx.repo, base_branch, ctx.verbose)
      raise GitError(
        "Failed to push branch '" +
        branch_name +
        "' to origin: " +
        e.to_string() +
        branch_recovery_note,
      )
    }
  } noraise {
    r => r
  }
  if not(push_result.is_success()) {
    let hint = if push_result.stderr.contains("permission") ||
      push_result.stderr.contains("denied") {
      " Check your GitHub permissions for this repository."
    } else if push_result.stderr.contains("force-with-lease") {
      " The remote branch has been updated since last fetch. Pull and resolve conflicts first."
    } else {
      ""
    }
    let _ = try? restore_branch(ctx.repo, base_branch, ctx.verbose)
    raise GitError(
      "Failed to push branch '" +
      branch_name +
      "' to origin: " +
      push_result.stderr +
      hint +
      branch_recovery_note,
    )
  }

  // Return to original branch with try-catch-noraise pattern
  let return_result = try
    @executor.run_git(ctx.repo, ["checkout", base_branch])
  catch {
    e => {
      if ctx.verbose {
        println("[WARN] Failed to return to base branch: " + e.to_string())
      }
      @executor.CommandResult::failed("checkout failed: " + e.to_string())
    }
  } noraise {
    r => r
  }
  if not(return_result.is_success()) && ctx.verbose {
    println(
      "[WARN] Could not checkout " + base_branch + ": " + return_result.stderr,
    )
    println(
      "[WARN] You may need to manually checkout: git checkout " + base_branch,
    )
  }

  // Generate PR body (unified release-plz style format)
  let pr_body = generate_pr_body(ctx, monorepo_pkg_info)

  match existing_pr {
    Some((pr_num, _)) => {
      // Update existing PR title and body
      let update_result = try
        @executor.run_gh([
          "pr", "edit", pr_num.to_string(), "--title", commit_msg, "--body",
          pr_body,
        ])
      catch {
        e =>
          raise GitError(
            "Failed to update PR: " + e.to_string() + branch_recovery_note,
          )
      } noraise {
        r => r
      }
      if not(update_result.is_success()) {
        println("Warning: Failed to update PR body: " + update_result.stderr)
      }
      println("Updated pull request #\{pr_num}")
    }
    None => {
      // Create new PR
      let pr_title = commit_msg
      let pr_cmd = github.create_pull_request_command(
        pr_title,
        pr_body,
        branch_name,
        base_branch,
        draft=ctx.config.pr_draft,
        labels=ctx.config.pr_labels,
      )

      // Extract gh command arguments
      let gh_args : Array[String] = []
      for i = 1; i < pr_cmd.length(); i = i + 1 {
        gh_args.push(pr_cmd[i])
      }

      // Create PR with try-catch-noraise pattern
      let pr_result = try @executor.run_gh(gh_args) catch {
        e =>
          raise GitError(
            "Failed to create pull request: " +
            e.to_string() +
            branch_recovery_note,
          )
      } noraise {
        r => r
      }
      if not(pr_result.is_success()) {
        let hint = if pr_result.stderr.contains("already exists") {
          " A pull request for this branch may already exist."
        } else if pr_result.stderr.contains("permission") ||
          pr_result.stderr.contains("denied") {
          " Check your GitHub permissions for this repository."
        } else if pr_result.stderr.contains("authentication") {
          " Run 'gh auth login' to authenticate with GitHub."
        } else {
          ""
        }
        raise GitError(
          "Failed to create pull request: " +
          pr_result.stderr +
          hint +
          branch_recovery_note,
        )
      }

      println("Created pull request: " + pr_result.stdout_trimmed())
    }
  }
}

///|
/// Collect files to stage based on publish configuration
fn collect_files_to_stage(ctx : ReleaseContext) -> Array[String] {
  let files : Array[String] = ["add"]
  let is_monorepo = not(ctx.config.packages.is_empty())
  if is_monorepo {
    for pkg in ctx.config.packages {
      if not(validate_path(pkg.path)) {
        continue
      }
      let pkg_path = package_path_prefix(pkg.path)
      match pkg.publish_target() {
        MooncakesOnly => files.push(pkg_path + "moon.mod.json")
        NpmOnly(_) => files.push(pkg_path + "package.json")
        Both(_) => {
          files.push(pkg_path + "moon.mod.json")
          files.push(pkg_path + "package.json")
        }
        NoPublish => ()
      }
    }
  } else {
    match ctx.config.publish_target() {
      MooncakesOnly => files.push("moon.mod.json")
      NpmOnly(_) => files.push("package.json")
      Both(_) => {
        files.push("moon.mod.json")
        files.push("package.json")
      }
      NoPublish => ()
    }
  }
  files
}

///|
/// Generate PR body from release context and package info
async fn generate_pr_body(
  ctx : ReleaseContext,
  monorepo_pkg_info : Array[PackageReleaseInfo],
) -> String raise WorkflowError {
  let is_monorepo = not(ctx.config.packages.is_empty())

  let pkg_name = try get_package_name() catch {
    _ => "this-package"
  } noraise {
    n => n
  }

  let single_pkg_info = [
    PackageReleaseInfo::{
      name: pkg_name,
      old_version: ctx.current_version,
      new_version: ctx.new_version,
      commits: ctx.commits,
    },
  ]

  if is_monorepo {
    if ctx.verbose {
      println("Generating PR body for monorepo...")
    }
    build_pr_body_unified(
      if monorepo_pkg_info.is_empty() {
        single_pkg_info
      } else {
        monorepo_pkg_info
      },
    )
  } else {
    if ctx.verbose {
      println("Generating PR body for single package...")
    }
    build_pr_body_unified(single_pkg_info)
  }
}

///|
/// Find existing release PR
/// Note: Returns None on any error (error suppression for optional lookup)
/// Suppress: Error type is declared but all errors are caught and converted to None
#warnings("-unused_error_type")
async fn find_existing_release_pr(
  github : @github.GitHubClient,
  branch_prefix : String,
) -> (UInt, String)? raise Error {
  let list_cmd = github.list_pull_requests_command(state="open")

  // Extract gh command arguments
  let gh_args : Array[String] = []
  for i = 1; i < list_cmd.length(); i = i + 1 {
    gh_args.push(list_cmd[i])
  }

  // Run gh command with try-catch-noraise pattern
  let result = try @executor.run_gh(gh_args) catch {
    _ => return None
  } noraise {
    r => r
  }

  if not(result.is_success()) {
    return None
  }

  // Parse PR list with try-catch-noraise pattern
  let prs = try @github.parse_pull_request_list_json(result.stdout) catch {
    _ => return None
  } noraise {
    p => p
  }

  // Find PR with branch starting with release/
  for pr in prs {
    if pr.head.has_prefix(branch_prefix) && pr.number > 0U {
      return Some((pr.number, pr.head))
    }
  }

  None
}

///|
/// Pre-build JS target for npm publish (called before tag creation)
/// This ensures build failures happen before any artifacts are created
pub async fn pre_build_js(ctx : ReleaseContext) -> Unit raise WorkflowError {
  let is_monorepo = not(ctx.config.packages.is_empty())

  if is_monorepo {
    // Monorepo: check package-level npm_publish
    let has_npm_packages = ctx.config.packages
      .iter()
      .any(fn(p) { p.npm_publish })
    if not(has_npm_packages) {
      return
    }

    for pkg in ctx.config.packages {
      if not(pkg.npm_publish) {
        continue
      }

      // Path validation (prevent directory traversal)
      if not(validate_path(pkg.path)) {
        println("  Warning: Invalid path for " + pkg.name + ": " + pkg.path)
        continue
      }

      let build_cmd = get_pkg_npm_build_command(pkg)
      let build_cmd_str = @executor.join_command_args(build_cmd)

      if ctx.dry_run {
        println(
          "[dry-run] Would pre-build JS target for " +
          pkg.name +
          " in " +
          pkg.path +
          ": " +
          build_cmd_str,
        )
        continue
      }

      if ctx.verbose {
        println("Pre-building JS target for " + pkg.name + "...")
        println("  Command: " + build_cmd_str)
        println("  Working directory: " + pkg.path)
      }

      let build_result = try
        @executor.run_command_in_dir(build_cmd, pkg.path)
      catch {
        e =>
          raise ExternalCommandError(
            "Failed to build JS target for " + pkg.name + ": " + e.to_string(),
          )
      } noraise {
        r => r
      }

      if not(build_result.is_success()) {
        raise ExternalCommandError(
          "Failed to build JS target for " +
          pkg.name +
          ": " +
          build_result.stderr,
        )
      }

      if ctx.verbose {
        println("  JS build successful for " + pkg.name)
      }
    }
  } else {
    // Single package: use root-level npm_publish
    if not(ctx.config.npm_publish) {
      return
    }

    let build_cmd = get_npm_build_command(ctx.config)
    let build_cmd_str = @executor.join_command_args(build_cmd)

    if ctx.dry_run {
      println("[dry-run] Would pre-build JS target: " + build_cmd_str)
      return
    }

    if ctx.verbose {
      println("Pre-building JS target for npm publish...")
      println("  Command: " + build_cmd_str)
    }

    // Run build command - fail if build fails (before any tag/release creation)
    let build_result = try @executor.run_command(build_cmd) catch {
      e =>
        raise ExternalCommandError(
          "Failed to build JS target: " + e.to_string(),
        )
    } noraise {
      r => r
    }

    if not(build_result.is_success()) {
      raise ExternalCommandError(
        "Failed to build JS target: " + build_result.stderr,
      )
    }

    if ctx.verbose {
      println("  JS build successful (ready for npm publish)")
    }
  }
}

///|
/// release command: create tag and release
pub async fn run_release(
  ctx : ReleaseContext,
  github : @github.GitHubClient,
) -> Unit raise WorkflowError {
  if ctx.verbose {
    println("Running release workflow...")
  }

  // Pre-build JS target if npm_publish is enabled (before any tag/release creation)
  // This ensures build failures happen early, preventing partial releases
  pre_build_js(ctx)

  // Generate tag name and release title from templates
  let tag_name = ctx.config.git_tag_name.replace(
    old="{{ version }}",
    new=ctx.new_version.to_string(),
  )
  let release_title = ctx.config.git_release_name.replace(
    old="{{ version }}",
    new=ctx.new_version.to_string(),
  )

  // Determine release mode via ADT
  let release_mode = ctx.config.git_release_mode()

  // Validate tag name (when tag creation is enabled)
  match release_mode {
    GitHubRelease(..) | TagOnly =>
      match validate_git_ref_name(tag_name) {
        Some(reason) =>
          raise InputValidationError(
            "Invalid tag name '\{tag_name}': \{reason}",
          )
        None => ()
      }
    NoGitRelease => ()
  }

  if ctx.dry_run {
    // Dry-run: tag/release info
    match release_mode {
      GitHubRelease(..) => {
        println("[dry-run] Would create tag: " + tag_name)
        println("[dry-run] Would create GitHub release: " + release_title)
      }
      TagOnly => println("[dry-run] Would create tag: " + tag_name)
      NoGitRelease => ()
    }
    // Dry-run: publish info
    if not(ctx.config.packages.is_empty()) {
      for pkg in ctx.config.packages {
        match pkg.publish_target() {
          MooncakesOnly =>
            println("[dry-run] Would publish " + pkg.name + " to mooncakes.io")
          NpmOnly(_) => println("[dry-run] Would npm publish " + pkg.name)
          Both(_) => {
            println("[dry-run] Would publish " + pkg.name + " to mooncakes.io")
            println("[dry-run] Would npm publish " + pkg.name)
          }
          NoPublish => ()
        }
      }
    } else {
      match ctx.config.publish_target() {
        MooncakesOnly => println("[dry-run] Would publish to mooncakes.io")
        NpmOnly(_) => println("[dry-run] Would publish to npm")
        Both(_) => {
          println("[dry-run] Would publish to mooncakes.io")
          println("[dry-run] Would publish to npm")
        }
        NoPublish => ()
      }
    }
    return
  }

  // Create tag (when tag creation is enabled)
  match release_mode {
    GitHubRelease(..) | TagOnly => {
      let tag_msg = release_title
      let tag_result = try
        @executor.run_git(ctx.repo, ["tag", "-a", "-m", tag_msg, "--", tag_name])
      catch {
        e => raise GitError("Failed to create tag: " + e.to_string())
      } noraise {
        r => r
      }
      if not(tag_result.is_success()) {
        raise GitError("Failed to create tag: " + tag_result.stderr)
      }

      let push_result = try
        @executor.run_git(ctx.repo, ["push", "origin", tag_name])
      catch {
        e => raise GitError("Failed to push tag: " + e.to_string())
      } noraise {
        r => r
      }
      if not(push_result.is_success()) {
        raise GitError("Failed to push tag: " + push_result.stderr)
      }

      println("Created and pushed tag: " + tag_name)
    }
    NoGitRelease => ()
  }

  // Create GitHub Release (only for GitHubRelease mode)
  match release_mode {
    GitHubRelease(draft~, latest~) => {
      let release_notes = match ctx.config.git_release_body {
        Some(template) =>
          template
          .replace(old="{{ version }}", new=ctx.new_version.to_string())
          .replace(
            old="{{ changelog }}",
            new=generate_release_notes(ctx.commits),
          )
        None => generate_release_notes(ctx.commits)
      }
      let release_cmd = github.create_release_command(
        tag_name,
        release_title,
        release_notes,
        draft~,
        latest~,
      )

      let gh_args : Array[String] = []
      for i = 1; i < release_cmd.length(); i = i + 1 {
        gh_args.push(release_cmd[i])
      }

      let mut release_caught_error = false
      let release_result = try @executor.run_gh(gh_args) catch {
        e => {
          println("Warning: Failed to create GitHub release: " + e.to_string())
          println(
            "Tag '" +
            tag_name +
            "' was already pushed. Create the release manually.",
          )
          release_caught_error = true
          @executor.CommandResult::failed("release creation failed")
        }
      } noraise {
        r => r
      }
      if not(release_result.is_success()) && not(release_caught_error) {
        println(
          "Warning: Failed to create GitHub release: " + release_result.stderr,
        )
        println(
          "Tag '" +
          tag_name +
          "' was already pushed. Create the release manually.",
        )
      } else if release_result.is_success() {
        println("Created GitHub release: " + tag_name)
      }
    }
    _ => ()
  }

  // Publish packages
  if not(ctx.config.packages.is_empty()) {
    run_publish_packages(ctx.config, ctx.dry_run, ctx.verbose)
    run_npm_publish_packages(ctx.config, ctx.dry_run, ctx.verbose)
  } else {
    match ctx.config.publish_target() {
      MooncakesOnly => run_publish(ctx)
      NpmOnly(_) => run_npm_publish(ctx)
      Both(_) => {
        run_publish(ctx)
        run_npm_publish(ctx)
      }
      NoPublish => ()
    }
  }
}

///|
/// publish command: publish to mooncakes.io
pub async fn run_publish(ctx : ReleaseContext) -> Unit raise WorkflowError {
  if ctx.verbose {
    println("Publishing to mooncakes.io...")
  }

  // Run API compatibility check if semver_check is enabled
  if ctx.config.semver_check {
    if ctx.verbose {
      println("Running API compatibility check...")
    }

    // Run semver check with try-catch-noraise pattern
    let check_result = try run_semver_check(ctx.repo, ctx.verbose) catch {
      e => {
        println("Warning: Semver check failed: " + e.to_string())
        println("Continuing with publish...")
        @semver_check.CheckResult::new(@semver_check.ApiDiff::empty())
      }
    } noraise {
      r => r
    }

    if check_result.diff.has_breaking() {
      println("")
      println("WARNING: Breaking API changes detected!")
      println(@semver_check.format_summary(check_result))
      println("")
      println("Consider:")
      println("  1. Bumping the major version")
      println("  2. Using BREAKING CHANGE: in your commit messages")
      println("")
    } else if ctx.verbose {
      println(
        "Semver check passed: " + @semver_check.format_summary(check_result),
      )
    }
  }

  // Build publish command
  let publish_cmd : Array[String] = if ctx.config.moon_publish_frozen {
    ["moon", "publish", "--frozen"]
  } else {
    ["moon", "publish"]
  }

  if ctx.dry_run {
    println("[dry-run] Would run: " + @executor.join_command_args(publish_cmd))
    return
  }

  // Use timeout from config (default 300 seconds = 5 minutes)
  let timeout = ctx.config.moon_publish_timeout
  if ctx.verbose {
    println("  Timeout: \{timeout} seconds")
  }

  // Run publish with try-catch-noraise pattern
  let publish_result = try
    @executor.run_command_with_timeout(publish_cmd, timeout)
  catch {
    e => raise PublishError("Failed to publish: " + e.to_string())
  } noraise {
    r => r
  }

  match publish_result {
    None => {
      // Timeout occurred
      println("Warning: Publish timed out after \{timeout} seconds")
      println("The publish process may still be running in the background.")
      println("You can manually publish with: moon publish")
      return
    }
    Some(result) =>
      if not(result.is_success()) {
        // publish failed - treat as warning since tag is already created
        println("Warning: Failed to publish to mooncakes.io: " + result.stderr)
        println("You can manually publish with: moon publish")
        return
      }
  }

  println("Published to mooncakes.io")
}

///|
/// npm publish command: publish to npm registry
/// Note: JS build is handled by pre_build_js() before tag creation
pub async fn run_npm_publish(ctx : ReleaseContext) -> Unit raise WorkflowError {
  if ctx.verbose {
    println("Publishing to npm...")
  }

  // Build npm publish command
  let publish_cmd = build_npm_publish_command(ctx.config.npm_publish_provenance)
  let publish_cmd_str = @executor.join_command_args(publish_cmd)

  if ctx.dry_run {
    println("[dry-run] Would run: " + publish_cmd_str)
    return
  }

  // Use timeout from config (default 300 seconds = 5 minutes)
  let timeout = ctx.config.npm_publish_timeout
  if ctx.verbose {
    println("  Timeout: \{timeout} seconds")
  }

  // Run npm publish with try-catch-noraise pattern
  let publish_result = try
    @executor.run_command_with_timeout(publish_cmd, timeout)
  catch {
    e => raise PublishError("Failed to publish to npm: " + e.to_string())
  } noraise {
    r => r
  }

  match publish_result {
    None => {
      // Timeout occurred
      println("Warning: npm publish timed out after \{timeout} seconds")
      println("The publish process may still be running in the background.")
      println("You can manually publish with: npm publish")
      return
    }
    Some(result) =>
      if not(result.is_success()) {
        // npm publish failed - provide helpful error message
        let hint = if result.stderr.contains("ENEEDAUTH") ||
          result.stderr.contains("need to be logged in") ||
          result.stderr.contains("authentication") ||
          result.stderr.contains("401") ||
          result.stderr.contains("403") {
          "\n\nHint: npm authentication failed. For Trusted Publishing, make sure:\n" +
          "  1. Configure Trusted Publishing on npmjs.com (Package Settings)\n" +
          "  2. Set 'id-token: write' permission in GitHub Actions workflow\n" +
          "  3. Run npm publish with --provenance flag\n" +
          "See: https://docs.npmjs.com/generating-provenance-statements"
        } else if result.stderr.contains("EPUBLISHCONFLICT") ||
          result.stderr.contains("already exists") {
          "\n\nHint: This version already exists in the registry."
        } else if result.stderr.contains("E402") ||
          result.stderr.contains("payment") {
          "\n\nHint: npm publish requires a paid account for private packages."
        } else if result.stderr.contains("provenance") {
          "\n\nHint: --provenance requires GitHub Actions with id-token: write permission.\n" +
          "  If running locally, use 'npm publish' without --provenance."
        } else {
          ""
        }
        raise PublishError("Failed to publish to npm: " + result.stderr + hint)
      }
  }

  println("Published to npm")
}

// ============================================================================
// Shared monorepo version resolution pipeline (Phase 3 DDD)
// ============================================================================

///|
/// Resolved version plan for a single package
/// Output of the shared 3-phase pipeline: collect → consolidate → apply
pub(all) struct PackageVersionPlan {
  name : String
  path : String
  old_version : @semver.Version
  new_version : @semver.Version
  bump_type : @semver.BumpType
  commits : Array[(@conventional.ConventionalCommit, String)]
}

///|
/// Shared 3-phase monorepo version resolution pipeline
/// Phase 1: Collect per-package info (version, commits, raw bump)
/// Phase 2: Consolidate bump types by version_group
/// Phase 3: Compute final versions with consolidated bumps
async fn resolve_version_plan(
  config : @config.Config,
  repo : @git.Repository,
  forced_bump : @semver.BumpType?,
  verbose : Bool,
  bump_all? : Bool = false,
) -> Array[PackageVersionPlan] raise WorkflowError {
  if config.packages.is_empty() {
    return []
  }

  // Pre-compute effective bump for bump_all mode
  let effective_bump = compute_effective_bump(
    config, repo, forced_bump, bump_all,
  )

  if bump_all && effective_bump is None {
    return []
  }

  // Phase 1: Collect per-package info
  let entries : Array[
    (
      String,
      String,
      @semver.Version,
      @semver.BumpType,
      Array[(@conventional.ConventionalCommit, String)],
      String?,
    ),
  ] = []

  for pkg in config.packages {
    if verbose {
      println("  Analyzing package: " + pkg.name)
    }

    if not(validate_path(pkg.path)) {
      if verbose {
        println("  Warning: Invalid path for " + pkg.name + ": " + pkg.path)
      }
      continue
    }

    let current_version = match get_package_current_version(pkg) {
      Some(v) => v
      None => {
        if verbose {
          println("  Warning: Could not determine version for " + pkg.name)
        }
        continue
      }
    }

    let commits = try get_package_commits(repo, pkg.path, pr_title=config.pr_title) catch {
      e => {
        if verbose {
          println(
            "  Warning: Could not get commits for " +
            pkg.name +
            ": " +
            e.to_string(),
          )
        }
        continue
      }
    } noraise {
      c => c
    }

    if commits.is_empty() && not(bump_all) {
      if verbose {
        println("    No changes in " + pkg.name)
      }
      continue
    }

    let bump_type = match effective_bump {
      Some(fb) => fb
      None =>
        match
          @semver.determine_bump_with_custom(
            commits.map(fn(c) { c.0 }),
            config.custom_major_increment_regex,
            config.custom_minor_increment_regex,
          ) {
          Some(t) => t
          None => {
            if verbose {
              println("    No releasable changes in " + pkg.name)
            }
            continue
          }
        }
    }

    entries.push(
      (
        pkg.name,
        pkg.path,
        current_version,
        bump_type,
        commits,
        pkg.version_group,
      ),
    )
  }

  // Phase 2: Consolidate bump types by version_group
  let group_bumps : @hashmap.HashMap[String, @semver.BumpType] = @hashmap.new()

  for entry in entries {
    let (_, _, _, bump_type, _, version_group) = entry
    match version_group {
      Some(group) => {
        let should_update = match group_bumps.get(group) {
          None => true
          Some(existing) => bump_priority(bump_type) > bump_priority(existing)
        }
        if should_update {
          group_bumps.set(group, bump_type)
        }
      }
      None => ()
    }
  }

  // Phase 3: Compute final versions
  let plans : Array[PackageVersionPlan] = []

  for entry in entries {
    let (name, path, old_version, bump_type, commits, version_group) = entry
    let final_bump = match version_group {
      Some(group) =>
        match group_bumps.get(group) {
          Some(group_bump) => group_bump
          None => bump_type
        }
      None => bump_type
    }

    let new_version = @semver.bump(old_version, final_bump)
    plans.push(PackageVersionPlan::{
      name,
      path,
      old_version,
      new_version,
      bump_type: final_bump,
      commits,
    })
  }

  plans
}

///|
/// Package release info (for PR body generation)
pub struct PackageReleaseInfo {
  name : String
  old_version : @semver.Version
  new_version : @semver.Version
  commits : Array[(@conventional.ConventionalCommit, String)]
}

///|
/// Collect package release info for monorepo PR body
/// Delegates to resolve_version_plan for the shared 3-phase pipeline
pub async fn collect_package_release_info(
  config : @config.Config,
  repo : @git.Repository,
  verbose : Bool,
  forced_bump? : @semver.BumpType? = None,
  bump_all? : Bool = false,
) -> Array[PackageReleaseInfo] raise WorkflowError {
  let plans = resolve_version_plan(
    config,
    repo,
    forced_bump,
    verbose,
    bump_all~,
  )

  plans.map(fn(plan) {
    PackageReleaseInfo::{
      name: plan.name,
      old_version: plan.old_version,
      new_version: plan.new_version,
      commits: plan.commits,
    }
  })
}

///|
/// Monorepo: update multiple packages
/// Delegates to resolve_version_plan for the shared 3-phase pipeline,
/// then applies file updates based on the resolved plan.
pub async fn run_update_packages(
  config : @config.Config,
  repo : @git.Repository,
  dry_run : Bool,
  verbose : Bool,
  forced_bump? : @semver.BumpType? = None,
  bump_all? : Bool = false,
) -> Unit raise WorkflowError {
  if config.packages.is_empty() {
    if verbose {
      println("No packages configured. Using single-package mode.")
    }
    return
  }

  if verbose {
    println("Updating \{config.packages.length()} packages...")
  }

  let plans = resolve_version_plan(
    config,
    repo,
    forced_bump,
    verbose,
    bump_all~,
  )

  if plans.is_empty() {
    if verbose {
      println("No releasable commits found across packages.")
    }
    return
  }

  // Find package config by name (for publish target and version_group info)
  fn find_pkg(name : String) -> @config.PackageConfig? {
    for pkg in config.packages {
      if pkg.name == name {
        return Some(pkg)
      }
    }
    None
  }

  // Apply updates based on plan
  for plan in plans {
    let pkg = match find_pkg(plan.name) {
      Some(p) => p
      None => continue
    }

    let pkg_path = package_path_prefix(plan.path)
    let group_info = match pkg.version_group {
      Some(g) => " (group: " + g + ")"
      None => ""
    }

    if dry_run {
      println(
        "  [dry-run] Would update \{plan.name}\{group_info}: \{plan.old_version.to_string()} -> \{plan.new_version.to_string()}",
      )
      match pkg.publish_target() {
        MooncakesOnly =>
          println("  [dry-run] Would update " + pkg_path + "moon.mod.json")
        NpmOnly(_) =>
          println("  [dry-run] Would update " + pkg_path + "package.json")
        Both(_) => {
          println("  [dry-run] Would update " + pkg_path + "moon.mod.json")
          println("  [dry-run] Would update " + pkg_path + "package.json")
        }
        NoPublish => ()
      }
      continue
    }

    // Update moon.mod.json if mooncakes publishing is enabled
    match pkg.publish_target() {
      MooncakesOnly | Both(_) => {
        let mmp = pkg_path + "moon.mod.json"
        let content = try @fs.read_file(mmp).text() catch {
          _ => {
            println("  Warning: Could not read " + mmp)
            ""
          }
        } noraise {
          c => c
        }

        if not(content.is_empty()) {
          let updated_content = try
            @moon_mod.update_version(content, plan.new_version)
          catch {
            e => {
              println(
                "  Warning: Could not update version in " +
                mmp +
                ": " +
                e.to_string(),
              )
              continue
            }
          } noraise {
            c => c
          }

          try @fs.write_file(mmp, updated_content, create=0o644) catch {
            _ => {
              println("  Warning: Could not write " + mmp)
              continue
            }
          } noraise {
            _ => ()
          }
        }
      }
      _ => ()
    }

    // Update package.json if npm publishing is enabled
    match pkg.publish_target() {
      NpmOnly(_) | Both(_) => {
        let pkg_json_path = pkg_path + "package.json"
        match
          update_package_json_version(plan.new_version, path=pkg_json_path) {
          Some(updated_pkg_json) => {
            try
              @fs.write_file(pkg_json_path, updated_pkg_json, create=0o644)
            catch {
              _ => println("  Warning: Could not write " + pkg_json_path)
            } noraise {
              _ => ()
            }
            println("  Updated " + pkg_json_path)
          }
          None =>
            println(
              "  Warning: npm_publish enabled for " +
              plan.name +
              " but " +
              pkg_json_path +
              " not found",
            )
        }
      }
      _ => ()
    }

    println(
      "  Updated \{plan.name}\{group_info}: \{plan.old_version.to_string()} -> \{plan.new_version.to_string()}",
    )
  }
}

///|
/// Get commits for a package (with path filter)
async fn get_package_commits(
  repo : @git.Repository,
  path : String,
  pr_title~ : String,
) -> Array[(@conventional.ConventionalCommit, String)] raise WorkflowError {
  // Get latest tag with try-catch-noraise (failure is expected if no tags exist yet)
  let tag_result = try
    @executor.run_git(repo, ["describe", "--tags", "--abbrev=0"])
  catch {
    e => @executor.CommandResult::failed("no tags found: " + e.to_string())
  } noraise {
    r => r
  }

  let tag = if tag_result.is_success() {
    tag_result.stdout_trimmed()
  } else {
    ""
  }

  // No tag found — search for the most recent release commit
  if tag.is_empty() {
    let pattern = pr_title.replace(old="{{ version }}", new="")
    let search_result = try
      @executor.run_git(repo, [
        "log", "--fixed-strings", "--grep=" + pattern, "--format=%H", "-1",
      ])
    catch {
      _ => @executor.CommandResult::failed("release commit search failed")
    } noraise {
      r => r
    }
    let release_hash = if search_result.is_success() {
      search_result.stdout_trimmed()
    } else {
      ""
    }
    if release_hash.is_empty() {
      raise GitError(
        "No previous release found (no git tag or release commit matching '" +
        pattern +
        "').\nHint: Use 'moon-release set-version <version>' to set the initial version, or create a git tag (e.g. 'git tag v0.1.0')",
      )
    }
    // Use get_commits_since_tag_command for ref validation, then append path filter
    let cmd = try repo.get_commits_since_tag_command(release_hash) catch {
      e =>
        raise ExternalCommandError(
          "Failed to build git log command: " + e.to_string(),
        )
    } noraise {
      r => r
    }
    cmd.push("--")
    cmd.push(path)
    let log_result = try @executor.run_command(cmd) catch {
      e => raise GitError("Failed to get commits: " + e.to_string())
    } noraise {
      r => r
    }
    let git_commits = @git.parse_commit_log(log_result.stdout)
    return @git.parse_conventional_commits(git_commits)
  }

  // Tag found — get commits since tag with path filter
  let log_cmd = [
    "log",
    "--pretty=format:%H%x1E%s%x1E%an%x1E%aI",
    tag + "..HEAD",
    "--",
    path,
  ]

  // Get log with try-catch-noraise pattern
  let log_result = try @executor.run_git(repo, log_cmd) catch {
    e => raise GitError("Failed to get commits: " + e.to_string())
  } noraise {
    r => r
  }

  let git_commits = @git.parse_commit_log(log_result.stdout)
  @git.parse_conventional_commits(git_commits)
}

///|
/// Monorepo: publish multiple packages
// Suppress: WorkflowError declared for API consistency. Errors are handled internally
// with warnings printed to stdout, allowing partial success in monorepo scenarios.
#warnings("-unused_error_type")
pub async fn run_publish_packages(
  config : @config.Config,
  dry_run : Bool,
  verbose : Bool,
) -> Unit raise WorkflowError {
  if config.packages.is_empty() {
    if verbose {
      println("No packages configured. Using single-package mode.")
    }
    return
  }

  for pkg in config.packages {
    if not(pkg.moon_publish) {
      if verbose {
        println("  Skipping " + pkg.name + " (moon_publish: false)")
      }
      continue
    }

    // Path validation (prevent directory traversal)
    if not(validate_path(pkg.path)) {
      println("  Warning: Invalid path for " + pkg.name + ": " + pkg.path)
      continue
    }

    if dry_run {
      println("[dry-run] Would publish " + pkg.name)
      continue
    }

    if verbose {
      println("Publishing " + pkg.name + "...")
    }

    // Publish with try-catch-noraise pattern
    let publish_cmd : Array[String] = if pkg.path == "." {
      ["moon", "publish"]
    } else {
      ["moon", "publish", "-C", pkg.path]
    }
    if config.moon_publish_frozen {
      publish_cmd.push("--frozen")
    }
    let timeout = config.moon_publish_timeout
    let publish_result = try
      @executor.run_command_with_timeout(publish_cmd, timeout)
    catch {
      e => {
        println(
          "  Warning: Failed to publish " + pkg.name + ": " + e.to_string(),
        )
        continue
      }
    } noraise {
      r => r
    }

    match publish_result {
      None => {
        println(
          "  Warning: Publish timed out for " +
          pkg.name +
          " after \{timeout} seconds",
        )
        continue
      }
      Some(result) =>
        if not(result.is_success()) {
          println(
            "  Warning: Failed to publish " + pkg.name + ": " + result.stderr,
          )
          continue
        }
    }

    println("  Published " + pkg.name)
  }
}

///|
/// Monorepo: npm publish for packages with npm_publish enabled
// Suppress: WorkflowError declared for API consistency. Errors are handled internally
// with warnings printed to stdout, allowing partial success in monorepo scenarios.
#warnings("-unused_error_type")
pub async fn run_npm_publish_packages(
  config : @config.Config,
  dry_run : Bool,
  verbose : Bool,
) -> Unit raise WorkflowError {
  if config.packages.is_empty() {
    return
  }

  let has_npm_packages = config.packages.iter().any(fn(p) { p.npm_publish })
  if not(has_npm_packages) {
    if verbose {
      println("No packages with npm_publish enabled.")
    }
    return
  }

  for pkg in config.packages {
    if not(pkg.npm_publish) {
      if verbose {
        println("  Skipping " + pkg.name + " (npm_publish: false)")
      }
      continue
    }

    // Path validation (prevent directory traversal)
    if not(validate_path(pkg.path)) {
      println("  Warning: Invalid path for " + pkg.name + ": " + pkg.path)
      continue
    }

    if dry_run {
      println("[dry-run] Would npm publish " + pkg.name)
      continue
    }

    // Note: JS build is already done by pre_build_js() before tag creation

    // Note: npm_publish_provenance is a root-level config setting applied to all packages.
    // Per-package provenance configuration is not currently supported.

    // npm publish (run in package directory)
    let publish_cmd = build_npm_publish_command(config.npm_publish_provenance)

    if verbose {
      println("Publishing " + pkg.name + " to npm...")
      println("  Command: " + @executor.join_command_args(publish_cmd))
      println("  Working directory: " + pkg.path)
    }

    // Use npm_publish_timeout from config, run in package directory
    let timeout = config.npm_publish_timeout
    let publish_result = try
      @executor.run_command_in_dir_with_timeout(publish_cmd, pkg.path, timeout)
    catch {
      e => {
        println(
          "  Warning: Failed to npm publish " + pkg.name + ": " + e.to_string(),
        )
        continue
      }
    } noraise {
      r => r
    }

    match publish_result {
      None => {
        println(
          "  Warning: npm publish timed out for " +
          pkg.name +
          " after \{timeout} seconds",
        )
        continue
      }
      Some(result) =>
        if not(result.is_success()) {
          println(
            "  Warning: Failed to npm publish " +
            pkg.name +
            ": " +
            result.stderr,
          )
          continue
        }
    }

    println("  Published " + pkg.name + " to npm")
  }
}

///|
/// Get version from registry
// Suppress: WorkflowError declared for API consistency with other workflow functions.
// Errors are caught internally and returned as None (package not found).
#warnings("-unused_error_type")
pub async fn get_registry_version(
  package_name : String,
) -> @semver.Version? raise WorkflowError {
  // Get package info with try? + unwrap_or pattern
  let result = (try? @executor.run_command(["moon", "info", package_name])).unwrap_or(
    @executor.CommandResult::failed("moon info command failed"),
  )

  if not(result.is_success()) {
    return None
  }

  // Extract version from output
  // Output format: "name: package_name\nversion: x.y.z\n..."
  let lines : Array[String] = result.stdout
    .split("\n")
    .map(fn(sv) { sv.to_string() })
    .collect()

  for line in lines {
    let trimmed = line.trim().to_string()
    if trimmed.has_prefix("version:") {
      let version_str = trimmed
        .split(":")
        .map(fn(sv) { sv.to_string() })
        .collect()
      if version_str.length() >= 2 {
        let ver = version_str[1].trim().to_string()
        // parse returns Option directly, no error handling needed
        return @semver.Version::parse(ver)
      }
    }
  }

  None
}

///|
/// Compare registry and local version to check if release is needed
pub async fn should_release(
  local_version : @semver.Version,
  package_name : String,
  verbose : Bool,
) -> Bool raise WorkflowError {
  let registry_version = get_registry_version(package_name)

  match registry_version {
    None => {
      if verbose {
        println("  Package not found in registry. Will publish as new package.")
      }
      true
    }
    Some(reg_ver) => {
      let cmp = local_version.compare(reg_ver)
      if cmp > 0 {
        if verbose {
          println(
            "  Local version (\{local_version.to_string()}) > registry version (\{reg_ver.to_string()})",
          )
        }
        true
      } else {
        if verbose {
          println(
            "  Local version (\{local_version.to_string()}) <= registry version (\{reg_ver.to_string()}). Skipping.",
          )
        }
        false
      }
    }
  }
}

///|
/// Run semver check
pub async fn run_semver_check(
  repo : @git.Repository,
  verbose : Bool,
) -> @semver_check.CheckResult raise WorkflowError {
  if verbose {
    println("Running semver check...")
  }

  // 1. Get latest tag
  // Get tag with try-catch-noraise pattern
  let tag_result = try
    @executor.run_git(repo, ["describe", "--tags", "--abbrev=0"])
  catch {
    _ =>
      raise GitError(
        "No tags found. Cannot perform semver check without a previous version.",
      )
  } noraise {
    r => r
  }

  if not(tag_result.is_success()) {
    raise GitError(
      "No tags found. Cannot perform semver check without a previous version.",
    )
  }

  let latest_tag = tag_result.stdout_trimmed()
  if verbose {
    println("  Comparing against tag: " + latest_tag)
  }

  // 2. Save current branch name with try-catch-noraise pattern
  let branch_result = try
    @executor.run_git(repo, ["rev-parse", "--abbrev-ref", "HEAD"])
  catch {
    e => raise GitError("Failed to get current branch: " + e.to_string())
  } noraise {
    r => r
  }
  if not(branch_result.is_success()) {
    raise GitError("Failed to get current branch: " + branch_result.stderr)
  }
  let current_branch = branch_result.stdout_trimmed()

  // 3. Run moon doc on current code
  if verbose {
    println("  Generating docs for current code...")
  }
  // Run moon doc with try-catch-noraise pattern
  let doc_result = try @executor.run_command(["moon", "doc"]) catch {
    e => raise ExternalCommandError("Failed to run moon doc: " + e.to_string())
  } noraise {
    r => r
  }
  if not(doc_result.is_success()) {
    raise ExternalCommandError("Failed to generate docs: " + doc_result.stderr)
  }

  // 4. Load current package_data.json with try-catch-noraise pattern
  let current_apis = try load_package_apis("_build/doc") catch {
    e => raise WorkflowError("Failed to load current API: " + e.to_string())
  } noraise {
    r => r
  }

  // 5. Checkout tag and get old API (ensure safe branch restoration)
  let old_apis = get_old_apis_with_safe_checkout(
    repo, latest_tag, current_branch, verbose,
  )

  // 6. Compare APIs
  if verbose {
    println("  Comparing APIs...")
  }
  let diff = @semver_check.diff_api(old_apis, current_apis)
  let result = @semver_check.CheckResult::new(diff)

  if verbose {
    println(result.format())
  }

  result
}

///|
/// Checkout tag and get old API, ensuring restoration to original branch
async fn get_old_apis_with_safe_checkout(
  repo : @git.Repository,
  tag : String,
  original_branch : String,
  verbose : Bool,
) -> @semver_check.PackageApi raise WorkflowError {
  // Checkout tag with try-catch-noraise pattern
  if verbose {
    println("  Checking out tag: " + tag)
  }
  let checkout_result = try @executor.run_git(repo, ["checkout", tag]) catch {
    e => raise GitError("Failed to checkout tag: " + e.to_string())
  } noraise {
    r => r
  }
  if not(checkout_result.is_success()) {
    raise GitError("Failed to checkout tag: " + checkout_result.stderr)
  }

  // From this point, we must return to the original branch

  // Run moon doc on tagged code with try-catch-noraise pattern
  if verbose {
    println("  Generating docs for previous version...")
  }
  let old_doc_result = try @executor.run_command(["moon", "doc"]) catch {
    e => {
      let _ = try? restore_branch(repo, original_branch, verbose)
      raise ExternalCommandError(
        "Failed to run moon doc on tag: " + e.to_string(),
      )
    }
  } noraise {
    r => r
  }

  // Load package_data.json with try-catch-noraise pattern
  let old_apis = if old_doc_result.is_success() {
    try load_package_apis("_build/doc") catch {
      e => {
        if verbose {
          println(
            "[WARN] Failed to load API from previous version: " + e.to_string(),
          )
          println("[WARN] Continuing with empty API baseline...")
        }
        @semver_check.PackageApi::empty()
      }
    } noraise {
      r => r
    }
  } else {
    if verbose {
      println(
        "[WARN] Failed to generate docs for previous version: " +
        old_doc_result.stderr,
      )
      println("[WARN] Continuing with empty API baseline...")
    }
    @semver_check.PackageApi::empty()
  }

  // Return to original branch
  let _ = try? restore_branch(repo, original_branch, verbose)

  old_apis
}

///|
/// Return to original branch (errors are handled as warnings)
async fn restore_branch(
  repo : @git.Repository,
  branch : String,
  verbose : Bool,
) -> Unit {
  if verbose {
    println("  Restoring original branch...")
  }
  // Checkout with try-catch-noraise pattern
  let result = try @executor.run_git(repo, ["checkout", branch]) catch {
    e => {
      println("Warning: Failed to restore branch: " + e.to_string())
      println("You may need to manually checkout: git checkout " + branch)
      return
    }
  } noraise {
    r => r
  }
  if not(result.is_success()) {
    println("Warning: Failed to restore branch: " + result.stderr)
    println("You may need to manually checkout: git checkout " + branch)
  }
}

///|
/// Load package_data.json from _build/doc
/// Uses @fs.walk for cross-platform compatibility (no external find command)
async fn load_package_apis(
  doc_dir : String,
) -> @semver_check.PackageApi raise WorkflowError {
  let all_apis : Array[@semver_check.PackageApi] = []

  // Walk directory tree to find all package_data.json files with try-catch-noraise pattern
  try
    @fs.walk(
      doc_dir,
      async fn(dir_path, files) {
        for file in files {
          if file == "package_data.json" {
            let file_path = dir_path + "/" + file
            // Read file with try-catch-noraise pattern
            let content = try @fs.read_file(file_path).text() catch {
              _ => continue
            } noraise {
              c => c
            }

            // Parse with try-catch-noraise pattern
            let api = try @semver_check.parse_package_data(content) catch {
              _ => continue
            } noraise {
              a => a
            }

            all_apis.push(api)
          }
        }
      },
      max_concurrency=1, // Sequential for deterministic results
    )
  catch {
    e =>
      raise ExternalCommandError(
        "Failed to scan for package_data.json files: " + e.to_string(),
      )
  } noraise {
    _ => ()
  }

  @semver_check.merge_package_apis(all_apis)
}
