/// Get mooncakes credentials file path
async fn get_mooncakes_credentials_path() -> String {
  // ~/.moon/credentials.json
  let home = try @executor.run_command(["printenv", "HOME"]) catch {
    _ => @executor.CommandResult::failed("printenv failed")
  } noraise { r => r }

  if home.is_success() {
    home.stdout.trim().to_string() + "/.moon/credentials.json"
  } else {
    // Fallback for Windows or other systems
    ".moon/credentials.json"
  }
}

/// Validate publish configuration
/// Ensures required files exist for enabled publish targets
pub async fn validate_publish_config(
  config : @config.Config,
  verbose~ : Bool = false
) -> Unit raise WorkflowError {
  // Check moon.mod.json exists if moon_publish is enabled
  if config.moon_publish {
    let content = try @fs.read_file("moon.mod.json").text() catch {
      _ => raise WorkflowError("moon_publish is enabled but moon.mod.json not found")
    } noraise { c => c }
    // Validate it's parseable
    try @moon_mod.parse(content) catch {
      e => raise WorkflowError("moon_publish is enabled but moon.mod.json is invalid: " + e.to_string())
    } noraise { _ => () }

    // Check if mooncakes credentials exist (warning only, not error)
    let creds_path = try get_mooncakes_credentials_path() catch {
      _ => ".moon/credentials.json"
    } noraise { p => p }
    let creds_result = try @fs.read_file(creds_path).text() catch {
      _ => ""
    } noraise { c => c }

    // Parse JSON and check for "token" field
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
        println("  Or set MOONCAKES_TOKEN and MOONCAKES_USERNAME in CI environment")
      }
    }
  }

  // Check package.json exists if npm_publish is enabled
  if config.npm_publish {
    try @fs.read_file("package.json").text() catch {
      _ => raise WorkflowError("npm_publish is enabled but package.json not found")
    } noraise { _ => () }

    // Note: npm Trusted Publishing uses OIDC, no token check needed
    // Authentication is handled by GitHub Actions id-token permission
    if verbose {
      println("npm_publish enabled: using Trusted Publishing (OIDC)")
      println("  Make sure 'id-token: write' permission is set in workflow")
    }
  }
}

/// Get package name from moon.mod.json
async fn get_package_name() -> String {
  // Try to read package name from moon.mod.json
  let content = try @fs.read_file("moon.mod.json").text() catch {
    _ => return "this-package"
  } noraise { c => c }

  let moon_mod = try @moon_mod.parse(content) catch {
    _ => return "this-package"
  } noraise { m => m }

  moon_mod.name
}

/// Extract version from package.json content using JSON parser
fn parse_package_json_version(content : String) -> @semver.Version? raise WorkflowError {
  let json = try @json.parse(content) catch {
    e => raise WorkflowError("Failed to parse package.json: " + e.to_string())
  } noraise { j => j }

  match json {
    Object(map) =>
      match map.get("version") {
        Some(String(version_str)) => @semver.Version::parse(version_str)
        _ => None
      }
    _ => raise WorkflowError("package.json is not a valid JSON object")
  }
}

/// Read version from package.json file
pub async fn get_package_json_version() -> @semver.Version? raise WorkflowError {
  let content = try @fs.read_file("package.json").text() catch {
    _ => return None
  } noraise { c => c }

  parse_package_json_version(content)
}

/// Get current version from the appropriate source based on config
/// If both moon_publish and npm_publish are enabled, returns the higher version
pub async fn get_current_version(
  config : @config.Config
) -> @semver.Version raise WorkflowError {
  let mut moon_version : @semver.Version? = None
  let mut npm_version : @semver.Version? = None

  // Read from moon.mod.json if moon_publish is enabled
  if config.moon_publish {
    let content = try @fs.read_file("moon.mod.json").text() catch {
      e => raise WorkflowError("Failed to read moon.mod.json: " + e.to_string())
    } noraise { c => c }

    let moon_mod = try @moon_mod.parse(content) catch {
      e => raise WorkflowError("Failed to parse moon.mod.json: " + e.to_string())
    } noraise { m => m }

    match @semver.Version::parse(moon_mod.version) {
      Some(v) => moon_version = Some(v)
      None => raise WorkflowError("Invalid version in moon.mod.json: " + moon_mod.version)
    }
  }

  // Read from package.json if npm_publish is enabled
  if config.npm_publish {
    match get_package_json_version() {
      Some(v) => npm_version = Some(v)
      None => raise WorkflowError("Failed to read version from package.json")
    }
  }

  // Return the higher version if both are available
  match (moon_version, npm_version) {
    (Some(mv), Some(nv)) => {
      // Compare and return higher version
      if mv.compare(nv) >= 0 { mv } else { nv }
    }
    (Some(mv), None) => mv
    (None, Some(nv)) => nv
    (None, None) => raise WorkflowError("No publish target enabled. Enable moon_publish or npm_publish.")
  }
}

/// Update package.json version field
/// Uses line-based processing with nesting depth tracking to only replace the top-level "version"
/// Returns the updated content, or None if file doesn't exist
async fn update_package_json_version(
  new_version : @semver.Version
) -> String? raise WorkflowError {
  // Try to read package.json
  let content = try @fs.read_file("package.json").text() catch {
    _ => return None  // File doesn't exist, that's OK
  } noraise { c => c }

  // Verify package.json has a valid version field
  match parse_package_json_version(content) {
    Some(_) => ()
    None => raise WorkflowError("package.json does not contain a valid 'version' field")
  }

  // Replace only the top-level "version" field by tracking brace nesting depth
  let lines = content.split("\n")
  let updated_lines : Array[String] = []
  let mut depth = 0
  let mut found = false

  for line_view in lines {
    let line = line_view.to_string()

    if not(found) {
      // Count braces to track nesting depth (before checking this line)
      let chars = line.to_array()
      let mut line_depth_delta = 0
      let mut in_string = false
      for i = 0; i < chars.length(); i = i + 1 {
        let c = chars[i]
        if c == '"' && (i == 0 || chars[i - 1] != '\\') {
          in_string = not(in_string)
        } else if not(in_string) {
          if c == '{' {
            line_depth_delta = line_depth_delta + 1
          } else if c == '}' {
            line_depth_delta = line_depth_delta - 1
          }
        }
      }

      // Only match "version" at depth 1 (inside the top-level object)
      let trimmed = line.trim_start()
      if depth == 1 && trimmed.has_prefix("\"version\"") && trimmed.contains(":") {
        // Extract the version value and replace it, preserving everything else on the line
        let indent = get_line_indent(line)
        // Reconstruct: preserve trailing comma if present
        let has_trailing_comma = trimmed.has_suffix(",")
        let new_line = indent + "\"version\": \"" + new_version.to_string() + "\"" +
          (if has_trailing_comma { "," } else { "" })
        updated_lines.push(new_line)
        found = true
      } else {
        updated_lines.push(line)
      }

      depth = depth + line_depth_delta
    } else {
      updated_lines.push(line)
    }
  }

  if not(found) {
    raise WorkflowError("package.json does not contain a 'version' field at the top level")
  }

  Some(updated_lines.iter().fold(init="", fn(acc, line) {
    if acc.is_empty() { line } else { acc + "\n" + line }
  }))
}

/// Get the leading whitespace of a line
fn get_line_indent(line : String) -> String {
  let chars = line.to_array()
  let sb = StringBuilder::new()
  for c in chars {
    if c == ' ' || c == '\t' {
      sb.write_char(c)
    } else {
      break
    }
  }
  sb.to_string()
}

/// update command: local update only
pub async fn run_update(ctx : ReleaseContext) -> Unit raise WorkflowError {
  if ctx.verbose {
    println("Running update workflow...")
    println("  Current version: \{ctx.current_version.to_string()}")
    println("  New version: \{ctx.new_version.to_string()}")
    println("  Commits: \{ctx.commits.length()}")
  }

  if ctx.dry_run {
    if ctx.config.moon_publish {
      println("[dry-run] Would update moon.mod.json to version \{ctx.new_version.to_string()}")
    }
    if ctx.config.npm_publish {
      println("[dry-run] Would update package.json to version \{ctx.new_version.to_string()}")
    }
    return
  }

  // Update moon.mod.json if moon_publish is enabled
  if ctx.config.moon_publish {
    let moon_mod_content = try @fs.read_file("moon.mod.json").text() catch {
      e => raise WorkflowError("Failed to read moon.mod.json: " + e.to_string() + ". Make sure the file exists and is readable.")
    } noraise { c => c }

    let updated_content = try @moon_mod.update_version(moon_mod_content, ctx.new_version) catch {
      e => raise WorkflowError("Failed to update version in moon.mod.json: " + e.to_string())
    } noraise { c => c }

    try @fs.write_file("moon.mod.json", updated_content, create=0o644) catch {
      e => raise WorkflowError("Failed to write moon.mod.json: " + e.to_string() + ". Check file permissions.")
    } noraise { _ => () }

    println("Updated moon.mod.json to version \{ctx.new_version.to_string()}")
  }

  // Update package.json if npm_publish is enabled
  if ctx.config.npm_publish {
    match update_package_json_version(ctx.new_version) {
      Some(updated_pkg_json) => {
        try @fs.write_file("package.json", updated_pkg_json, create=0o644) catch {
          e => raise WorkflowError("Failed to write package.json: " + e.to_string())
        } noraise { _ => () }
        println("Updated package.json to version \{ctx.new_version.to_string()}")
      }
      None =>
        // This shouldn't happen because validate_publish_config already checked
        raise WorkflowError("npm_publish is enabled but package.json not found")
    }
  }
}

/// release-pr command: create or update PR
pub async fn run_release_pr(
  ctx : ReleaseContext,
  github : @github.GitHubClient
) -> Unit raise WorkflowError {
  if ctx.verbose {
    println("Running release-pr workflow...")
  }

  let branch_name = ctx.config.pr_branch_prefix + "v\{ctx.new_version.to_string()}"
  let base_branch = ctx.config.base_branch

  // Validate branch name
  match validate_git_ref_name(branch_name) {
    Some(reason) =>
      raise WorkflowError("Invalid branch name '\{branch_name}': \{reason}")
    None => ()
  }

  // Find existing release PR (errors are suppressed to None)
  let existing_pr = try find_existing_release_pr(github, ctx.config.pr_branch_prefix) catch {
    _ => None
  } noraise { r => r }

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

  // Check if branch exists on remote with try? + unwrap_or pattern
  let remote_branch_exists = (try? check_remote_branch_exists(ctx.repo, branch_name))
    .unwrap_or(false)

  // Use checkout -B for atomic create-or-reset (avoids race condition)
  let checkout_result = try @executor.run_git(ctx.repo, ["checkout", "-B", branch_name]) catch {
    e => raise WorkflowError("Failed to create/checkout branch '" + branch_name + "': " + e.to_string())
  } noraise { r => r }
  if not(checkout_result.is_success()) {
    raise WorkflowError("Failed to create/checkout branch '" + branch_name + "': " + checkout_result.stderr)
  }

  // Pull from remote if branch exists there
  if remote_branch_exists {
    // Use try? + unwrap_or pattern for default value
    let pull_result = (try? @executor.run_git(ctx.repo, ["pull", "origin", branch_name]))
      .unwrap_or(@executor.CommandResult::failed("pull command failed"))
    if not(pull_result.is_success()) && ctx.verbose {
      println("[WARN] Failed to pull from remote: " + pull_result.stderr)
      println("[WARN] Continuing with local branch state...")
    }
  }

  // Run update (file updates)
  run_update(ctx)

  // Stage changes - add relevant files based on publish configuration
  // Note: get_current_version() ensures at least one of moon_publish/npm_publish is enabled
  let files_to_stage : Array[String] = ["add"]
  if ctx.config.moon_publish {
    files_to_stage.push("moon.mod.json")
  }
  if ctx.config.npm_publish {
    files_to_stage.push("package.json")
  }
  let stage_result = try @executor.run_git(ctx.repo, files_to_stage) catch {
    e => raise WorkflowError("Failed to stage files: " + e.to_string())
  } noraise { r => r }
  if not(stage_result.is_success()) {
    raise WorkflowError("Failed to stage files: " + stage_result.stderr)
  }

  // Check if there are changes with try-catch-noraise pattern
  let diff_result = try @executor.run_git(ctx.repo, ["diff", "--cached", "--quiet"]) catch {
    e => {
      if ctx.verbose {
        println("[WARN] Failed to check staged changes: " + e.to_string())
      }
      @executor.CommandResult::failed("diff check failed: " + e.to_string())
    }
  } noraise { r => r }

  if diff_result.is_success() {
    println("No changes to commit. Release PR is up to date.")
    // Return to original branch with try-catch-noraise pattern
    let checkout_back_result = try @executor.run_git(ctx.repo, ["checkout", base_branch]) catch {
      e => {
        if ctx.verbose {
          println("[WARN] Failed to return to base branch: " + e.to_string())
        }
        @executor.CommandResult::failed("checkout failed: " + e.to_string())
      }
    } noraise { r => r }
    if not(checkout_back_result.is_success()) && ctx.verbose {
      println("[WARN] Could not checkout " + base_branch + ": " + checkout_back_result.stderr)
      println("[WARN] You may need to manually checkout: git checkout " + base_branch)
    }
    return
  }

  // Commit with try-catch-noraise pattern
  let commit_msg = ctx.config.apply_version_template(ctx.new_version.to_string())
  let commit_result = try @executor.run_git(ctx.repo, ["commit", "-m", commit_msg]) catch {
    e => raise WorkflowError("Failed to commit: " + e.to_string())
  } noraise { r => r }
  if not(commit_result.is_success()) {
    raise WorkflowError("Failed to commit: " + commit_result.stderr)
  }

  // Push (force push to update)
  // Using --force-with-lease instead of --force for safety:
  // it will fail if someone else pushed to the branch since our last fetch
  if ctx.verbose {
    println("Pushing with --force-with-lease (safe force push)...")
  }
  let push_result = try @executor.run_git(ctx.repo, ["push", "-u", "--force-with-lease", "origin", branch_name]) catch {
    e => raise WorkflowError("Failed to push branch '" + branch_name + "' to origin: " + e.to_string())
  } noraise { r => r }
  if not(push_result.is_success()) {
    let hint = if push_result.stderr.contains("permission") || push_result.stderr.contains("denied") {
      " Check your GitHub permissions for this repository."
    } else if push_result.stderr.contains("force-with-lease") {
      " The remote branch has been updated since last fetch. Pull and resolve conflicts first."
    } else {
      ""
    }
    raise WorkflowError("Failed to push branch '" + branch_name + "' to origin: " + push_result.stderr + hint)
  }

  // Return to original branch with try-catch-noraise pattern
  let return_result = try @executor.run_git(ctx.repo, ["checkout", base_branch]) catch {
    e => {
      if ctx.verbose {
        println("[WARN] Failed to return to base branch: " + e.to_string())
      }
      @executor.CommandResult::failed("checkout failed: " + e.to_string())
    }
  } noraise { r => r }
  if not(return_result.is_success()) && ctx.verbose {
    println("[WARN] Could not checkout " + base_branch + ": " + return_result.stderr)
    println("[WARN] You may need to manually checkout: git checkout " + base_branch)
  }

  // Get package name for single-package mode (with error fallback)
  let pkg_name = try get_package_name() catch {
    _ => "this-package"
  } noraise { n => n }

  // Generate PR body (unified release-plz style format)
  let pr_body = if not(ctx.config.packages.is_empty()) {
    // Monorepo mode: collect info for each package
    if ctx.verbose {
      println("Generating PR body for monorepo...")
    }
    let pkg_info = collect_package_release_info(ctx.config, ctx.repo, ctx.verbose)
    if pkg_info.is_empty() {
      // Fallback: create single package info from context
      let single_pkg = [
        PackageReleaseInfo::{
          name: pkg_name,
          old_version: ctx.current_version,
          new_version: ctx.new_version,
          commits: ctx.commits,
        },
      ]
      build_pr_body_unified(single_pkg)
    } else {
      build_pr_body_unified(pkg_info)
    }
  } else {
    // Single-package mode: create PackageReleaseInfo from context
    if ctx.verbose {
      println("Generating PR body for single package...")
    }
    let single_pkg = [
      PackageReleaseInfo::{
        name: pkg_name,
        old_version: ctx.current_version,
        new_version: ctx.new_version,
        commits: ctx.commits,
      },
    ]
    build_pr_body_unified(single_pkg)
  }

  match existing_pr {
    Some((pr_num, _)) => {
      // Update existing PR with try-catch-noraise pattern
      let update_result = try @executor.run_gh(["pr", "edit", pr_num.to_string(), "--body", pr_body]) catch {
        e => raise WorkflowError("Failed to update PR: " + e.to_string())
      } noraise { r => r }
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
        e => raise WorkflowError("Failed to create pull request: " + e.to_string())
      } noraise { r => r }
      if not(pr_result.is_success()) {
        let hint = if pr_result.stderr.contains("already exists") {
          " A pull request for this branch may already exist."
        } else if pr_result.stderr.contains("permission") || pr_result.stderr.contains("denied") {
          " Check your GitHub permissions for this repository."
        } else if pr_result.stderr.contains("authentication") {
          " Run 'gh auth login' to authenticate with GitHub."
        } else {
          ""
        }
        raise WorkflowError("Failed to create pull request: " + pr_result.stderr + hint)
      }

      println("Created pull request: " + pr_result.stdout_trimmed())
    }
  }
}

/// Find existing release PR
/// Note: Returns None on any error (error suppression for optional lookup)
/// Suppress: Error type is declared but all errors are caught and converted to None
#warnings("-unused_error_type")
async fn find_existing_release_pr(
  github : @github.GitHubClient,
  branch_prefix : String
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
  } noraise { r => r }

  if not(result.is_success()) {
    return None
  }

  // Parse PR list with try-catch-noraise pattern
  let prs = try @github.parse_pull_request_list_json(result.stdout) catch {
    _ => return None
  } noraise { p => p }

  // Find PR with branch starting with release/
  for pr in prs {
    if pr.head.has_prefix(branch_prefix) {
      return Some((pr.number, pr.head))
    }
  }

  None
}

/// Check if branch exists on remote
async fn check_remote_branch_exists(
  repo : @git.Repository,
  branch_name : String
) -> Bool {
  // try? converts to Result, unwrap_or provides default on error
  let result = (try? @executor.run_git(repo, ["ls-remote", "--heads", "origin", branch_name]))
    .unwrap_or(@executor.CommandResult::failed("git ls-remote failed"))
  result.is_success() && not(result.stdout.trim().is_empty())
}

/// Pre-build JS target for npm publish (called before tag creation)
/// This ensures build failures happen before any artifacts are created
pub async fn pre_build_js(ctx : ReleaseContext) -> Unit raise WorkflowError {
  if not(ctx.config.npm_publish) {
    return
  }

  let build_cmd = get_npm_build_command(ctx.config)
  let build_cmd_str = build_cmd.iter().fold(init="", fn(acc, s) {
    if acc.is_empty() { s } else { acc + " " + s }
  })

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
    e => raise WorkflowError("Failed to build JS target: " + e.to_string())
  } noraise { r => r }

  if not(build_result.is_success()) {
    raise WorkflowError("Failed to build JS target: " + build_result.stderr)
  }

  if ctx.verbose {
    println("  JS build successful (ready for npm publish)")
  }
}

/// release command: create tag and release
pub async fn run_release(
  ctx : ReleaseContext,
  github : @github.GitHubClient
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

  // Validate tag name
  if ctx.config.git_tag_enable {
    match validate_git_ref_name(tag_name) {
      Some(reason) =>
        raise WorkflowError("Invalid tag name '\{tag_name}': \{reason}")
      None => ()
    }
  }

  if ctx.dry_run {
    if ctx.config.git_tag_enable {
      println("[dry-run] Would create tag: " + tag_name)
    }
    if ctx.config.git_release_enable {
      println("[dry-run] Would create GitHub release: " + release_title)
    }
    if ctx.config.moon_publish {
      println("[dry-run] Would publish to mooncakes.io")
    }
    if ctx.config.npm_publish {
      println("[dry-run] Would publish to npm")
    }
    return
  }

  // Create tag (only if git_tag_enable is true)
  if ctx.config.git_tag_enable {
    let tag_msg = release_title
    // Create tag with try-catch-noraise pattern
    let tag_result = try @executor.run_git(ctx.repo, ["tag", "-a", tag_name, "-m", tag_msg]) catch {
      e => raise WorkflowError("Failed to create tag: " + e.to_string())
    } noraise { r => r }
    if not(tag_result.is_success()) {
      raise WorkflowError("Failed to create tag: " + tag_result.stderr)
    }

    // Push tag with try-catch-noraise pattern
    let push_result = try @executor.run_git(ctx.repo, ["push", "origin", tag_name]) catch {
      e => raise WorkflowError("Failed to push tag: " + e.to_string())
    } noraise { r => r }
    if not(push_result.is_success()) {
      raise WorkflowError("Failed to push tag: " + push_result.stderr)
    }

    println("Created and pushed tag: " + tag_name)
  }

  // Create GitHub Release
  if ctx.config.git_release_enable {
    // Release notes: use custom template if available, otherwise auto-generate
    let release_notes = match ctx.config.git_release_body {
      Some(template) =>
        template
        .replace(old="{{ version }}", new=ctx.new_version.to_string())
        .replace(old="{{ changelog }}", new=generate_release_notes(ctx.commits))
      None => generate_release_notes(ctx.commits)
    }
    let release_cmd = github.create_release_command(
      tag_name,
      release_title,
      release_notes,
      draft=ctx.config.git_release_draft,
      latest=ctx.config.git_release_latest,
    )

    // Extract gh command arguments
    let gh_args : Array[String] = []
    for i = 1; i < release_cmd.length(); i = i + 1 {
      gh_args.push(release_cmd[i])
    }

    // Create release with try-catch-noraise pattern
    let release_result = try @executor.run_gh(gh_args) catch {
      e => raise WorkflowError("Failed to create release: " + e.to_string())
    } noraise { r => r }
    if not(release_result.is_success()) {
      raise WorkflowError(
        "Failed to create release: " + release_result.stderr,
      )
    }

    println("Created GitHub release: " + tag_name)
  }

  // Publish to mooncakes.io
  if ctx.config.moon_publish {
    run_publish(ctx)
  }

  // Publish to npm
  if ctx.config.npm_publish {
    run_npm_publish(ctx)
  }
}

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
    } noraise { r => r }

    if check_result.diff.has_breaking {
      println("")
      println("WARNING: Breaking API changes detected!")
      println(@semver_check.format_summary(check_result))
      println("")
      println("Consider:")
      println("  1. Bumping the major version")
      println("  2. Using BREAKING CHANGE: in your commit messages")
      println("")
    } else if ctx.verbose {
      println("Semver check passed: " + @semver_check.format_summary(check_result))
    }
  }

  // Build publish command
  let publish_cmd : Array[String] = if ctx.config.moon_publish_frozen {
    ["moon", "publish", "--frozen"]
  } else {
    ["moon", "publish"]
  }

  if ctx.dry_run {
    println("[dry-run] Would run: " + publish_cmd.iter().fold(init="", fn(acc, s) {
      if acc.is_empty() { s } else { acc + " " + s }
    }))
    return
  }

  // Use timeout from config (default 300 seconds = 5 minutes)
  let timeout = ctx.config.moon_publish_timeout
  if ctx.verbose {
    println("  Timeout: \{timeout} seconds")
  }

  // Run publish with try-catch-noraise pattern
  let publish_result = try @executor.run_command_with_timeout(publish_cmd, timeout) catch {
    e => raise WorkflowError("Failed to publish: " + e.to_string())
  } noraise { r => r }

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

/// Get the npm build command (from config or default)
pub fn get_npm_build_command(config : @config.Config) -> Array[String] {
  match config.npm_build_command {
    Some(cmd) => cmd.split(" ").map(fn(s) { s.to_string() }).collect()
    None => ["moon", "build", "--target", "js"]
  }
}

/// npm publish command: publish to npm registry
/// Note: JS build is handled by pre_build_js() before tag creation
pub async fn run_npm_publish(ctx : ReleaseContext) -> Unit raise WorkflowError {
  if ctx.verbose {
    println("Publishing to npm...")
  }

  // Build npm publish command
  let publish_cmd : Array[String] = ["npm", "publish"]
  if ctx.config.npm_publish_provenance {
    publish_cmd.push("--provenance")
  }
  publish_cmd.push("--access")
  publish_cmd.push("public")

  let publish_cmd_str = publish_cmd.iter().fold(init="", fn(acc, s) {
    if acc.is_empty() { s } else { acc + " " + s }
  })

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
  let publish_result = try @executor.run_command_with_timeout(publish_cmd, timeout) catch {
    e => raise WorkflowError("Failed to publish to npm: " + e.to_string())
  } noraise { r => r }

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
        raise WorkflowError("Failed to publish to npm: " + result.stderr + hint)
      }
  }

  println("Published to npm")
}

/// Package update info
priv struct PackageUpdateInfo {
  pkg : @config.PackageConfig
  moon_mod_path : String
  moon_mod_content : String
  current_version : @semver.Version
  bump_type : @semver.BumpType
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

/// Build PR body for monorepo (release-plz style) - alias for build_pr_body_unified
pub fn build_pr_body_monorepo(
  packages : Array[PackageReleaseInfo]
) -> String {
  build_pr_body_unified(packages)
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

/// Collect package release info for monorepo PR body
// Suppress: WorkflowError declared for API consistency with other workflow functions
#warnings("-unused_error_type")
pub async fn collect_package_release_info(
  config : @config.Config,
  repo : @git.Repository,
  verbose : Bool
) -> Array[PackageReleaseInfo] raise WorkflowError {
  let packages : Array[PackageReleaseInfo] = []

  if config.packages.is_empty() {
    return packages
  }

  // Phase 1: Collect information for each package
  let updates : Array[(String, @semver.Version, @semver.BumpType, Array[(@conventional.ConventionalCommit, String)])] = []

  for pkg in config.packages {
    if verbose {
      println("  Analyzing package: " + pkg.name)
    }

    // Path validation (prevent directory traversal)
    if not(validate_path(pkg.path)) {
      if verbose {
        println("  Warning: Invalid path for " + pkg.name + ": " + pkg.path)
      }
      continue
    }

    let pkg_path = if pkg.path == "." { "" } else { pkg.path + "/" }
    let moon_mod_path = pkg_path + "moon.mod.json"

    // Read moon.mod.json with try-catch-noraise pattern
    let moon_mod_content = try @fs.read_file(moon_mod_path).text() catch {
      _ => {
        if verbose {
          println("  Warning: Could not read " + moon_mod_path)
        }
        continue
      }
    } noraise { c => c }

    // Parse with try-catch-noraise pattern
    let moon_mod = try @moon_mod.parse(moon_mod_content) catch {
      e => {
        if verbose {
          println("  Warning: Could not parse " + moon_mod_path + ": " + e.to_string())
        }
        continue
      }
    } noraise { m => m }

    let current_version = match @semver.Version::parse(moon_mod.version) {
      Some(v) => v
      None => {
        if verbose {
          println("  Warning: Invalid version in " + moon_mod_path)
        }
        continue
      }
    }

    // Get commits with try-catch-noraise pattern
    let commits = try get_package_commits(repo, pkg.path) catch {
      e => {
        if verbose {
          println("  Warning: Could not get commits for " + pkg.name + ": " + e.to_string())
        }
        continue
      }
    } noraise { c => c }

    if commits.is_empty() {
      if verbose {
        println("    No changes in " + pkg.name)
      }
      continue
    }

    // Determine bump type
    let bump_type = match @semver.determine_bump(commits.map(fn(c) { c.0 })) {
      Some(t) => t
      None => {
        if verbose {
          println("    No releasable changes in " + pkg.name)
        }
        continue
      }
    }

    updates.push((pkg.name, current_version, bump_type, commits))
  }

  // Phase 2: Consolidate bump types by version_group (simplified - use max bump)
  let group_bumps : @hashmap.HashMap[String, @semver.BumpType] = @hashmap.new()

  for i = 0; i < updates.length(); i = i + 1 {
    let (name, _, bump_type, _) = updates[i]
    // Find the package config to get version_group
    for pkg in config.packages {
      if pkg.name == name {
        match pkg.version_group {
          Some(group) => {
            let current_group_bump = group_bumps.get(group)
            let should_update = match current_group_bump {
              None => true
              Some(existing) => bump_priority(bump_type) > bump_priority(existing)
            }
            if should_update {
              group_bumps.set(group, bump_type)
            }
          }
          None => ()
        }
        break
      }
    }
  }

  // Phase 3: Build PackageReleaseInfo with consolidated versions
  for i = 0; i < updates.length(); i = i + 1 {
    let (name, current_version, bump_type, commits) = updates[i]

    // Find version_group for this package
    let mut final_bump = bump_type
    for pkg in config.packages {
      if pkg.name == name {
        match pkg.version_group {
          Some(group) =>
            match group_bumps.get(group) {
              Some(group_bump) => final_bump = group_bump
              None => ()
            }
          None => ()
        }
        break
      }
    }

    let new_version = @semver.bump(current_version, final_bump)
    packages.push(
      PackageReleaseInfo::{
        name,
        old_version: current_version,
        new_version,
        commits,
      },
    )
  }

  packages
}

/// Monorepo: update multiple packages
// Suppress: WorkflowError declared for API consistency. Errors are handled internally
// with warnings printed to stdout, allowing partial success in monorepo scenarios.
#warnings("-unused_error_type")
pub async fn run_update_packages(
  config : @config.Config,
  repo : @git.Repository,
  dry_run : Bool,
  verbose : Bool
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

  // Phase 1: Collect information for each package
  let updates : Array[PackageUpdateInfo] = []

  for pkg in config.packages {
    if verbose {
      println("  Analyzing package: " + pkg.name)
    }

    // Path validation (prevent directory traversal)
    if not(validate_path(pkg.path)) {
      println("  Warning: Invalid path for " + pkg.name + ": " + pkg.path)
      continue
    }

    let pkg_path = if pkg.path == "." { "" } else { pkg.path + "/" }
    let moon_mod_path = pkg_path + "moon.mod.json"

    // Read moon.mod.json with try-catch-noraise pattern
    let moon_mod_content = try @fs.read_file(moon_mod_path).text() catch {
      _ => {
        println("  Warning: Could not read " + moon_mod_path)
        continue
      }
    } noraise { c => c }

    // Parse with try-catch-noraise pattern
    let moon_mod = try @moon_mod.parse(moon_mod_content) catch {
      e => {
        println("  Warning: Could not parse " + moon_mod_path + ": " + e.to_string())
        continue
      }
    } noraise { m => m }

    let current_version = match @semver.Version::parse(moon_mod.version) {
      Some(v) => v
      None => {
        println("  Warning: Invalid version in " + moon_mod_path)
        continue
      }
    }

    // Get commits with try-catch-noraise pattern
    let commits = try get_package_commits(repo, pkg.path) catch {
      e => {
        println("  Warning: Could not get commits for " + pkg.name + ": " + e.to_string())
        continue
      }
    } noraise { c => c }

    if commits.is_empty() {
      if verbose {
        println("    No changes in " + pkg.name)
      }
      continue
    }

    // Determine bump type
    let bump_type = match @semver.determine_bump(commits.map(fn(c) { c.0 })) {
      Some(t) => t
      None => {
        if verbose {
          println("    No releasable changes in " + pkg.name)
        }
        continue
      }
    }

    updates.push(
      PackageUpdateInfo::{
        pkg,
        moon_mod_path,
        moon_mod_content,
        current_version,
        bump_type,
      },
    )
  }

  // Phase 2: Consolidate bump types by version_group
  let group_bumps : @hashmap.HashMap[String, @semver.BumpType] = @hashmap.new()

  for update in updates {
    match update.pkg.version_group {
      Some(group) => {
        let current_group_bump = group_bumps.get(group)
        let should_update = match current_group_bump {
          None => true
          Some(existing) => bump_priority(update.bump_type) > bump_priority(existing)
        }
        if should_update {
          group_bumps.set(group, update.bump_type)
        }
      }
      None => ()
    }
  }

  // Phase 3: Execute updates
  for update in updates {
    // Use group bump type if version_group is specified
    let final_bump_type = match update.pkg.version_group {
      Some(group) =>
        match group_bumps.get(group) {
          Some(group_bump) => group_bump
          None => update.bump_type
        }
      None => update.bump_type
    }

    let new_version = @semver.bump(update.current_version, final_bump_type)

    if dry_run {
      let group_info = match update.pkg.version_group {
        Some(g) => " (group: " + g + ")"
        None => ""
      }
      println("  [dry-run] Would update \{update.pkg.name}\{group_info}: \{update.current_version.to_string()} -> \{new_version.to_string()}")
      continue
    }

    // Update version
    // Update version with try-catch-noraise pattern
    let updated_content = try @moon_mod.update_version(update.moon_mod_content, new_version) catch {
      e => {
        println("  Warning: Could not update version: " + e.to_string())
        continue
      }
    } noraise { c => c }

    // Write file with try-catch-noraise pattern
    try @fs.write_file(update.moon_mod_path, updated_content, create=0o644) catch {
      _ => {
        println("  Warning: Could not write " + update.moon_mod_path)
        continue
      }
    } noraise { _ => () }

    let group_info = match update.pkg.version_group {
      Some(g) => " (group: " + g + ")"
      None => ""
    }
    println("  Updated \{update.pkg.name}\{group_info}: \{update.current_version.to_string()} -> \{new_version.to_string()}")
  }
}

/// Get commits for a package (with path filter)
async fn get_package_commits(
  repo : @git.Repository,
  path : String
) -> Array[(@conventional.ConventionalCommit, String)] raise WorkflowError {
  // Get latest tag with try-catch-noraise (failure is expected if no tags exist yet)
  let tag_result = try @executor.run_git(repo, ["describe", "--tags", "--abbrev=0"]) catch {
    e => @executor.CommandResult::failed("no tags found: " + e.to_string())
  } noraise { r => r }

  let log_cmd = if tag_result.is_success() {
    let tag = tag_result.stdout_trimmed()
    ["log", "--pretty=format:%H|%s|%an|%aI", tag + "..HEAD", "--", path]
  } else {
    ["log", "--pretty=format:%H|%s|%an|%aI", "--", path]
  }

  // Get log with try-catch-noraise pattern
  let log_result = try @executor.run_git(repo, log_cmd) catch {
    e => raise WorkflowError("Failed to get commits: " + e.to_string())
  } noraise { r => r }

  let git_commits = @git.parse_commit_log(log_result.stdout)
  @git.parse_conventional_commits(git_commits)
}

/// Monorepo: publish multiple packages
// Suppress: WorkflowError declared for API consistency. Errors are handled internally
// with warnings printed to stdout, allowing partial success in monorepo scenarios.
#warnings("-unused_error_type")
pub async fn run_publish_packages(
  config : @config.Config,
  dry_run : Bool,
  verbose : Bool
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
    let publish_result = if pkg.path == "." {
      try @executor.run_command(["moon", "publish"]) catch {
        e => {
          println("  Warning: Failed to publish " + pkg.name + ": " + e.to_string())
          continue
        }
      } noraise { r => r }
    } else {
      try @executor.run_command(["moon", "publish", "-C", pkg.path]) catch {
        e => {
          println("  Warning: Failed to publish " + pkg.name + ": " + e.to_string())
          continue
        }
      } noraise { r => r }
    }

    if not(publish_result.is_success()) {
      println("  Warning: Failed to publish " + pkg.name + ": " + publish_result.stderr)
      continue
    }

    println("  Published " + pkg.name)
  }
}

/// Get version from registry
// Suppress: WorkflowError declared for API consistency with other workflow functions.
// Errors are caught internally and returned as None (package not found).
#warnings("-unused_error_type")
pub async fn get_registry_version(
  package_name : String
) -> @semver.Version? raise WorkflowError {
  // Get package info with try? + unwrap_or pattern
  let result = (try? @executor.run_command(["moon", "info", package_name]))
    .unwrap_or(@executor.CommandResult::failed("moon info command failed"))

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

/// Compare registry and local version to check if release is needed
pub async fn should_release(
  local_version : @semver.Version,
  package_name : String,
  verbose : Bool
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
          println("  Local version (\{local_version.to_string()}) > registry version (\{reg_ver.to_string()})")
        }
        true
      } else {
        if verbose {
          println("  Local version (\{local_version.to_string()}) <= registry version (\{reg_ver.to_string()}). Skipping.")
        }
        false
      }
    }
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

/// Build PR body (apply template)
pub fn build_pr_body(ctx : ReleaseContext) -> String {
  ctx.config.pr_body
    .replace(old="{{ version }}", new=ctx.new_version.to_string())
    .replace(old="{{ changelog }}", new=generate_release_notes(ctx.commits))
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
      // Get first 7 characters
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

/// Run semver check
pub async fn run_semver_check(
  repo : @git.Repository,
  verbose : Bool
) -> @semver_check.CheckResult raise WorkflowError {
  if verbose {
    println("Running semver check...")
  }

  // 1. Get latest tag
  // Get tag with try-catch-noraise pattern
  let tag_result = try @executor.run_git(repo, ["describe", "--tags", "--abbrev=0"]) catch {
    _ =>
      raise WorkflowError(
        "No tags found. Cannot perform semver check without a previous version.",
      )
  } noraise { r => r }

  if not(tag_result.is_success()) {
    raise WorkflowError(
      "No tags found. Cannot perform semver check without a previous version.",
    )
  }

  let latest_tag = tag_result.stdout_trimmed()
  if verbose {
    println("  Comparing against tag: " + latest_tag)
  }

  // 2. Save current branch name with try-catch-noraise pattern
  let branch_result = try @executor.run_git(repo, ["rev-parse", "--abbrev-ref", "HEAD"]) catch {
    e => raise WorkflowError("Failed to get current branch: " + e.to_string())
  } noraise { r => r }
  let current_branch = branch_result.stdout_trimmed()

  // 3. Run moon doc on current code
  if verbose {
    println("  Generating docs for current code...")
  }
  // Run moon doc with try-catch-noraise pattern
  let doc_result = try @executor.run_command(["moon", "doc"]) catch {
    e => raise WorkflowError("Failed to run moon doc: " + e.to_string())
  } noraise { r => r }
  if not(doc_result.is_success()) {
    raise WorkflowError("Failed to generate docs: " + doc_result.stderr)
  }

  // 4. Load current package_data.json with try-catch-noraise pattern
  let current_apis = try load_package_apis("target/doc") catch {
    e => raise WorkflowError("Failed to load current API: " + e.to_string())
  } noraise { r => r }

  // 5. Checkout tag and get old API (ensure safe branch restoration)
  let old_apis = get_old_apis_with_safe_checkout(
    repo,
    latest_tag,
    current_branch,
    verbose,
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

/// Checkout tag and get old API, ensuring restoration to original branch
async fn get_old_apis_with_safe_checkout(
  repo : @git.Repository,
  tag : String,
  original_branch : String,
  verbose : Bool
) -> @semver_check.PackageApi raise WorkflowError {
  // Checkout tag with try-catch-noraise pattern
  if verbose {
    println("  Checking out tag: " + tag)
  }
  let checkout_result = try @executor.run_git(repo, ["checkout", tag]) catch {
    e => raise WorkflowError("Failed to checkout tag: " + e.to_string())
  } noraise { r => r }
  if not(checkout_result.is_success()) {
    raise WorkflowError("Failed to checkout tag: " + checkout_result.stderr)
  }

  // From this point, we must return to the original branch

  // Run moon doc on tagged code with try-catch-noraise pattern
  if verbose {
    println("  Generating docs for previous version...")
  }
  let old_doc_result = try @executor.run_command(["moon", "doc"]) catch {
    e => {
      let _ = try? restore_branch(repo, original_branch, verbose)
      raise WorkflowError("Failed to run moon doc on tag: " + e.to_string())
    }
  } noraise { r => r }

  // Load package_data.json with try-catch-noraise pattern
  let old_apis = if old_doc_result.is_success() {
    try load_package_apis("target/doc") catch {
      e => {
        if verbose {
          println("[WARN] Failed to load API from previous version: " + e.to_string())
          println("[WARN] Continuing with empty API baseline...")
        }
        @semver_check.PackageApi::empty()
      }
    } noraise { r => r }
  } else {
    if verbose {
      println("[WARN] Failed to generate docs for previous version: " + old_doc_result.stderr)
      println("[WARN] Continuing with empty API baseline...")
    }
    @semver_check.PackageApi::empty()
  }

  // Return to original branch
  let _ = try? restore_branch(repo, original_branch, verbose)

  old_apis
}

/// Return to original branch (errors are handled as warnings)
async fn restore_branch(
  repo : @git.Repository,
  branch : String,
  verbose : Bool
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
  } noraise { r => r }
  if not(result.is_success()) {
    println("Warning: Failed to restore branch: " + result.stderr)
    println("You may need to manually checkout: git checkout " + branch)
  }
}

/// Load package_data.json from target/doc
/// Uses @fs.walk for cross-platform compatibility (no external find command)
async fn load_package_apis(doc_dir : String) -> @semver_check.PackageApi raise WorkflowError {
  let all_apis : Array[@semver_check.PackageApi] = []

  // Walk directory tree to find all package_data.json files with try-catch-noraise pattern
  try @fs.walk(
    doc_dir,
    async fn(dir_path, files) {
      for file in files {
        if file == "package_data.json" {
          let file_path = dir_path + "/" + file
          // Read file with try-catch-noraise pattern
          let content = try @fs.read_file(file_path).text() catch {
            _ => continue
          } noraise { c => c }

          // Parse with try-catch-noraise pattern
          let api = try @semver_check.parse_package_data(content) catch {
            _ => continue
          } noraise { a => a }

          all_apis.push(api)
        }
      }
    },
    max_concurrency=1, // Sequential for deterministic results
  ) catch {
    e => raise WorkflowError("Failed to scan for package_data.json files: " + e.to_string())
  } noraise { _ => () }

  @semver_check.merge_package_apis(all_apis)
}
