/// moon-release CLI
/// Automated release tool

/// Version extracted from embedded moon.mod.json (generated at build time)
let version : String = extract_version(embedded_moon_mod_json)

/// Extract version from embedded moon.mod.json content
fn extract_version(json_str : String) -> String {
  // Use try? + to_option for consistent error handling
  match (try? @json.parse(json_str)).to_option() {
    Some(Object(obj)) =>
      match obj.get("version") {
        Some(String(v)) => v
        _ => "unknown"
      }
    _ => "unknown"
  }
}

/// Exit with status code (FFI to libc)
extern "C" fn c_exit(status : Int) -> Unit = "exit"

/// Exit with error (non-zero status code)
/// Uses panic() to satisfy type checker since exit never returns
fn[T] exit_error() -> T {
  c_exit(1)
  panic()
}

// ============================================================================
// Output helpers for consistent error/warning formatting
// ============================================================================

/// Output error message (supports JSON and text formats)
fn output_error(msg : String, json_output : Bool) -> Unit {
  if json_output {
    println("{\"error\": " + @util.json_string(msg) + "}")
  } else {
    println("Error: " + msg)
  }
}

/// Output error message with hint (text mode only shows hint)
fn output_error_with_hint(msg : String, hint : String, json_output : Bool) -> Unit {
  if json_output {
    println("{\"error\": " + @util.json_string(msg) + "}")
  } else {
    println("Error: " + msg)
    println("Hint: " + hint)
  }
}

/// Output warning message (suppressed in JSON mode)
fn output_warning(msg : String, json_output : Bool) -> Unit {
  if not(json_output) {
    println("Warning: " + msg)
  }
}

/// Get dry-run flag from subcommand (combines global and subcommand flags)
fn get_dry_run_flag(subcmd : @clap.SimpleValue, global_dry_run : Bool) -> Bool {
  let subcmd_dry_run = match subcmd.get_flag("dry-run") {
    Some(v) => v
    None => false
  }
  global_dry_run || subcmd_dry_run
}

/// Get output format from subcommand (returns true if JSON)
fn get_json_output(subcmd : @clap.SimpleValue) -> Bool {
  // Use try? + unwrap_or pattern for consistent error handling
  let output_format = (try? subcmd.get_one("output")).unwrap_or("text")
  output_format == "json"
}

/// Print verbose header for command
fn print_verbose_header(
  cmd_name : String,
  config_path : String,
  dry_run : Bool,
  verbose : Bool,
  json_output : Bool
) -> Unit {
  if verbose && not(json_output) {
    println("Running " + cmd_name + " command...")
    println("  Config: " + config_path)
    println("  Dry run: " + dry_run.to_string())
  }
}

/// Create CLI parser
fn create_parser() -> @clap.Parser {
  @clap.Parser::new(
    prog="moon-release",
    description="Automated release management tool for MoonBit",
    args={
      "dry-run": @clap.Arg::flag(
        short='n',
        global=true,
        help="Show what would be done without making changes",
      ),
      "verbose": @clap.Arg::flag(
        short='v',
        global=true,
        help="Enable verbose output",
      ),
      "config": @clap.Arg::named(
        short='c',
        nargs=@clap.One,
        defaults=["release.json"],
        global=true,
        help="Path to config file",
      ),
    },
    subcmds={
      "update": @clap.SubCommand::new(
        help="Update version locally (no commit/push)",
        args={
          "dry-run": @clap.Arg::flag(
            short='n',
            help="Show what would be done without making changes",
          ),
          "bump": @clap.Arg::named(
            short='b',
            nargs=@clap.AtMost(1),
            help="Force a specific version bump (major, minor, patch)",
          ),
          "packages": @clap.Arg::flag(
            short='p',
            help="Update all packages in monorepo mode",
          ),
          "output": @clap.Arg::named(
            short='o',
            nargs=@clap.One,
            defaults=["text"],
            help="Output format (text, json)",
          ),
        },
      ),
      "release-pr": @clap.SubCommand::new(
        help="Create a release pull request",
        args={
          "dry-run": @clap.Arg::flag(
            short='n',
            help="Show what would be done without making changes",
          ),
          "bump": @clap.Arg::named(
            short='b',
            nargs=@clap.AtMost(1),
            help="Force a specific version bump (major, minor, patch)",
          ),
        },
      ),
      "release": @clap.SubCommand::new(
        help="Create a release (tag and GitHub release)",
        args={
          "dry-run": @clap.Arg::flag(
            short='n',
            help="Show what would be done without making changes",
          ),
          "bump": @clap.Arg::named(
            short='b',
            nargs=@clap.AtMost(1),
            help="Force a specific version bump (major, minor, patch)",
          ),
          "prerelease": @clap.Arg::named(
            short='p',
            nargs=@clap.AtMost(1),
            help="Create a prerelease with the given identifier (e.g., alpha, beta, rc)",
          ),
        },
      ),
      "init": @clap.SubCommand::new(
        help="Initialize release configuration",
        args={
          "force": @clap.Arg::flag(
            short='f',
            help="Overwrite existing configuration",
          ),
        },
      ),
      "version": @clap.SubCommand::new(help="Show version information"),
      "check": @clap.SubCommand::new(
        help="Check the current state without making changes",
        args={
          "output": @clap.Arg::named(
            short='o',
            nargs=@clap.One,
            defaults=["text"],
            help="Output format (text, json)",
          ),
        },
      ),
      "set-version": @clap.SubCommand::new(
        help="Set the package version manually",
        args={
          "dry-run": @clap.Arg::flag(
            short='n',
            help="Show what would be done without making changes",
          ),
          "version": @clap.Arg::positional(
            nargs=@clap.One,
            help="The version to set (e.g., 1.2.3)",
          ),
        },
      ),
      "generate-completions": @clap.SubCommand::new(
        help="Generate shell completion script",
        args={
          "shell": @clap.Arg::positional(
            nargs=@clap.One,
            help="Shell to generate completions for (bash, zsh, fish)",
          ),
        },
      ),
      "generate-schema": @clap.SubCommand::new(
        help="Generate JSON Schema for release.json configuration",
      ),
    },
  )
}

/// Main function (async)
async fn main {
  let parser = create_parser()
  let value = @clap.SimpleValue::new("moon-release")

  // Get command line arguments (skip program name)
  let all_args = @env.args()
  let args : Array[String] = []
  for i = 1; i < all_args.length(); i = i + 1 {
    args.push(all_args[i])
  }

  // Parse with try-catch-noraise pattern
  let help_message = try parser.parse(value, args[:]) catch {
    e => {
      println("Error: " + e.to_string())
      exit_error()
    }
  } noraise { r => r }

  // Display help message if returned and exit
  match help_message {
    Some(msg) => {
      println(msg)
      return
    }
    None => ()
  }

  // Global options
  let dry_run = match value.get_flag("dry-run") {
    Some(v) => v
    None => false
  }
  let verbose = match value.get_flag("verbose") {
    Some(v) => v
    None => false
  }
  // Use try? + unwrap_or pattern for consistent error handling
  let config_path = (try? value.get_one("config")).unwrap_or("release.json")

  // Process subcommand
  match value.subcmd {
    Some(subcmd) =>
      match subcmd.name {
        "update" => cmd_update(subcmd, dry_run, verbose, config_path)
        "release-pr" => cmd_release_pr(subcmd, dry_run, verbose, config_path)
        "release" => cmd_release(subcmd, dry_run, verbose, config_path)
        "init" => cmd_init(subcmd, dry_run, verbose)
        "version" => cmd_version()
        "check" => cmd_check(subcmd, dry_run, verbose, config_path)
        "set-version" => cmd_set_version(subcmd, dry_run, verbose)
        "generate-completions" => cmd_generate_completions(subcmd)
        "generate-schema" => cmd_generate_schema()
        _ => println("Unknown command: " + subcmd.name)
      }
    None => {
      println("moon-release v" + version)
      println("")
      println("Use --help for usage information")
    }
  }
}

/// update command
async fn cmd_update(
  subcmd : @clap.SimpleValue,
  global_dry_run : Bool,
  verbose : Bool,
  config_path : String
) -> Unit {
  let dry_run = get_dry_run_flag(subcmd, global_dry_run)
  let json_output = get_json_output(subcmd)

  print_verbose_header("update", config_path, dry_run, verbose, json_output)

  // Load config and repo
  let config = load_config(config_path, verbose~)
  let repo = @git.Repository::current()

  // Dirty check
  if should_abort_dirty(config, repo, verbose) {
    output_error("uncommitted changes in working directory", json_output)
    exit_error()
  }

  // Check if monorepo mode
  let packages_mode = match subcmd.get_flag("packages") {
    Some(v) => v
    None => false
  }

  // In monorepo mode, update each package separately with try-catch-noraise pattern
  if packages_mode || not(config.packages.is_empty()) {
    try @workflow.run_update_packages(config, repo, dry_run, verbose) catch {
      e => {
        output_error(e.to_string(), json_output)
        exit_error()
      }
    } noraise { _ => () }
    return
  }

  // Get current version with try-catch-noraise pattern
  let moon_mod = try load_moon_mod("moon.mod.json") catch {
    e => {
      output_error(e.to_string(), json_output)
      exit_error()
    }
  } noraise { r => r }

  let current_version = match @semver.Version::parse(moon_mod.version) {
    Some(v) => v
    None => {
      output_error_with_hint(
        "Invalid version in moon.mod.json: " + moon_mod.version,
        "Version should follow semver format (e.g., 1.2.3 or 1.2.3-alpha)",
        json_output,
      )
      exit_error()
    }
  }

  // Parse commits with try-catch-noraise pattern
  let commits = try get_commits_since_last_tag(repo, max_commits=config.max_analyze_commits) catch {
    e => {
      output_error_with_hint(
        "Error getting commits: " + e.to_string(),
        "Make sure you are in a git repository with at least one commit",
        json_output,
      )
      exit_error()
    }
  } noraise { r => r }

  if commits.is_empty() {
    output_error_with_hint(
      "No commits found since last tag. Nothing to release.",
      "Create new commits or use 'moon-release set-version' to set version manually",
      json_output,
    )
    exit_error()
  }

  // Determine bump type
  let forced_bump = get_bump_type(subcmd)
  let bump_type = match forced_bump {
    Some(t) => t
    None =>
      match @semver.determine_bump_with_custom(
        commits.map(fn(c) { c.0 }),
        config.custom_major_increment_regex,
        config.custom_minor_increment_regex,
      ) {
        Some(t) => t
        None => {
          output_error_with_hint(
            "No releasable commits found (no feat, fix, or breaking changes)",
            "Use Conventional Commits (feat:, fix:) or --bump to force a version bump",
            json_output,
          )
          exit_error()
        }
      }
  }

  // Calculate new version
  let new_version = @semver.bump(current_version, bump_type)

  // Registry check (if enabled) with try-catch-noraise pattern
  if config.registry_check {
    let should_rel = try @workflow.should_release(new_version, moon_mod.name, verbose) catch {
      e => {
        output_warning("Registry check failed: " + e.to_string(), json_output)
        true // Continue release on error
      }
    } noraise { r => r }

    if not(should_rel) {
      output_error(
        "Version " + new_version.to_string() + " is not newer than registry version. Nothing to update.",
        json_output,
      )
      exit_error()
    }
  }

  // Create context and run workflow
  let ctx = @workflow.ReleaseContext::new(
    config,
    repo,
    current_version,
    new_version,
    commits,
    dry_run~,
    verbose~,
  )

  // Run update with try-catch-noraise pattern
  try @workflow.run_update(ctx) catch {
    e => {
      output_error(e.to_string(), json_output)
      exit_error()
    }
  } noraise { _ =>
    if json_output {
      let bump_str = match bump_type {
        @semver.Major => "major"
        @semver.Minor => "minor"
        @semver.Patch => "patch"
      }
      let json_str = build_json_object([
        ("old_version", json_string(current_version.to_string())),
        ("new_version", json_string(new_version.to_string())),
        ("bump_type", json_string(bump_str)),
        ("commits_count", commits.length().to_string()),
        ("dry_run", dry_run.to_string()),
        ("updated_files", "[\"moon.mod.json\"]"),
      ])
      println(json_str)
    }
  }
}

/// release-pr command
async fn cmd_release_pr(
  subcmd : @clap.SimpleValue,
  global_dry_run : Bool,
  verbose : Bool,
  config_path : String
) -> Unit {
  let dry_run = get_dry_run_flag(subcmd, global_dry_run)
  let json_output = false // release-pr doesn't support JSON output

  print_verbose_header("release-pr", config_path, dry_run, verbose, json_output)

  // Load config and repo
  let config = load_config(config_path, verbose~)
  let repo = @git.Repository::current()

  // Validate publish configuration
  try @workflow.validate_publish_config(config, verbose~) catch {
    e => {
      output_error(e.to_string(), json_output)
      exit_error()
    }
  } noraise { _ => () }

  // Dirty check
  if should_abort_dirty(config, repo, verbose) {
    exit_error()
  }

  // Get current version from appropriate source (moon.mod.json or package.json)
  let current_version = try @workflow.get_current_version(config) catch {
    e => {
      output_error_with_hint(
        e.to_string(),
        "Version should follow semver format (e.g., 1.2.3)",
        json_output,
      )
      exit_error()
    }
  } noraise { v => v }

  // Parse commits with try-catch-noraise pattern
  let commits = try get_commits_since_last_tag(repo, max_commits=config.max_analyze_commits) catch {
    e => {
      output_error_with_hint(
        "Error getting commits: " + e.to_string(),
        "Make sure you are in a git repository with at least one commit",
        json_output,
      )
      exit_error()
    }
  } noraise { r => r }

  if commits.is_empty() {
    output_error("No commits found since last tag. Nothing to release.", json_output)
    exit_error()
  }

  // Determine bump type
  let forced_bump = get_bump_type(subcmd)
  let bump_type = match forced_bump {
    Some(t) => t
    None =>
      match @semver.determine_bump_with_custom(
        commits.map(fn(c) { c.0 }),
        config.custom_major_increment_regex,
        config.custom_minor_increment_regex,
      ) {
        Some(t) => t
        None => {
          output_error_with_hint(
            "No releasable commits found",
            "Use Conventional Commits or --bump to force a version bump",
            json_output,
          )
          exit_error()
        }
      }
  }

  // Calculate new version
  let new_version = @semver.bump(current_version, bump_type)

  // Create context
  let ctx = @workflow.ReleaseContext::new(
    config,
    repo,
    current_version,
    new_version,
    commits,
    dry_run~,
    verbose~,
  )

  // Get GitHub client with try-catch-noraise pattern
  let github = try get_github_client() catch {
    e => {
      output_error_with_hint(
        e.to_string(),
        "Make sure gh CLI is installed and you're logged in (gh auth login)",
        json_output,
      )
      exit_error()
    }
  } noraise { r => r }

  // Run workflow with try-catch-noraise pattern
  try @workflow.run_release_pr(ctx, github) catch {
    e => {
      output_error(e.to_string(), json_output)
      exit_error()
    }
  } noraise { _ => () }
}

/// release command
async fn cmd_release(
  subcmd : @clap.SimpleValue,
  global_dry_run : Bool,
  verbose : Bool,
  config_path : String
) -> Unit {
  let dry_run = get_dry_run_flag(subcmd, global_dry_run)
  let json_output = false // release doesn't support JSON output

  print_verbose_header("release", config_path, dry_run, verbose, json_output)

  // Load config and repo
  let config = load_config(config_path, verbose~)
  let repo = @git.Repository::current()

  // Validate publish configuration
  try @workflow.validate_publish_config(config, verbose~) catch {
    e => {
      output_error(e.to_string(), json_output)
      exit_error()
    }
  } noraise { _ => () }

  // Dirty check
  if should_abort_dirty(config, repo, verbose) {
    exit_error()
  }

  // Get current version from appropriate source (moon.mod.json or package.json)
  let current_version = try @workflow.get_current_version(config) catch {
    e => {
      output_error_with_hint(
        e.to_string(),
        "Version should follow semver format (e.g., 1.2.3)",
        json_output,
      )
      exit_error()
    }
  } noraise { v => v }

  // Parse commits with try-catch-noraise pattern
  let commits = try get_commits_since_last_tag(repo, max_commits=config.max_analyze_commits) catch {
    e => {
      output_error_with_hint(
        "Error getting commits: " + e.to_string(),
        "Make sure you are in a git repository",
        json_output,
      )
      exit_error()
    }
  } noraise { r => r }

  // Check for empty commits (no forced bump and no commits)
  if commits.is_empty() && get_bump_type(subcmd) is None {
    output_error_with_hint(
      "No commits found since last tag. Nothing to release.",
      "Create new commits or use --bump to force a version bump",
      json_output,
    )
    exit_error()
  }

  // Determine bump type
  let forced_bump = get_bump_type(subcmd)
  let bump_type = match forced_bump {
    Some(t) => t
    None =>
      match @semver.determine_bump_with_custom(
        commits.map(fn(c) { c.0 }),
        config.custom_major_increment_regex,
        config.custom_minor_increment_regex,
      ) {
        Some(t) => t
        None => @semver.Patch // default to patch for non-conventional commits
      }
  }

  // Get prerelease identifier with try? + to_option pattern
  let prerelease = (try? subcmd.get_one("prerelease")).to_option()

  // Validate prerelease identifier format
  match prerelease {
    Some(id) =>
      match @workflow.validate_prerelease_identifier(id) {
        Some(reason) => {
          output_error_with_hint(
            "Invalid prerelease identifier '" + id + "': " + reason,
            "Use alphanumeric characters, hyphens, and dots (e.g., alpha, beta.1, rc-1)",
            json_output,
          )
          exit_error()
        }
        None => ()
      }
    None => ()
  }

  // Check if prerelease is allowed in config
  if prerelease is Some(_) && not(config.allow_prerelease) {
    output_error_with_hint(
      "Prerelease is not allowed in configuration.",
      "Set 'allow_prerelease: true' in release.json to enable prereleases",
      json_output,
    )
    exit_error()
  }

  // Calculate new version
  let new_version = @semver.bump_with_prerelease(current_version, bump_type, prerelease)

  // Create context
  let ctx = @workflow.ReleaseContext::new(
    config,
    repo,
    current_version,
    new_version,
    commits,
    dry_run~,
    verbose~,
  )

  // Get GitHub client with try-catch-noraise pattern
  let github = try get_github_client() catch {
    e => {
      output_error_with_hint(
        e.to_string(),
        "Make sure gh CLI is installed and you're logged in (gh auth login)",
        json_output,
      )
      exit_error()
    }
  } noraise { r => r }

  // Run workflow with try-catch-noraise pattern
  try @workflow.run_release(ctx, github) catch {
    e => {
      output_error(e.to_string(), json_output)
      exit_error()
    }
  } noraise { _ => () }
}

/// init command
async fn cmd_init(
  subcmd : @clap.SimpleValue,
  dry_run : Bool,
  _verbose : Bool
) -> Unit {
  let force = match subcmd.get_flag("force") {
    Some(v) => v
    None => false
  }

  println("Initializing release configuration...")

  // Check if file already exists
  let file_exists = (try? @fs.read_file("release.json")) is Ok(_)

  if file_exists && not(force) {
    println("release.json already exists. Use --force to overwrite.")
    exit_error()
  }

  if dry_run {
    println("Would create: release.json")
    return
  }

  // Write default config as JSON with try-catch-noraise pattern
  let config_json = generate_default_config_json()

  try @fs.write_file("release.json", config_json, create=0o644) catch {
    e => {
      println("Error: Failed to write release.json: " + e.to_string())
      exit_error()
    }
  } noraise { _ => () }

  let config = @config.Config::default()
  println("Created release.json with defaults:")
  println("  pr_title: " + config.pr_title)
  println("  allow_prerelease: " + config.allow_prerelease.to_string())
  println("  git_tag_enable: " + config.git_tag_enable.to_string())
  println("  git_release_enable: " + config.git_release_enable.to_string())
  println("  moon_publish: " + config.moon_publish.to_string())
  println("  moon_publish_frozen: " + config.moon_publish_frozen.to_string())
  println("  npm_publish: " + config.npm_publish.to_string())
  println("  semver_check: " + config.semver_check.to_string())
  println("  pr_branch_prefix: " + config.pr_branch_prefix)
  println("  base_branch: " + config.base_branch)
}

/// Generate default config JSON
fn generate_default_config_json() -> String {
  let json =
    #|{
    #|  "pr_title": "chore: release v{{ version }}",
    #|  "pr_draft": false,
    #|  "pr_labels": [],
    #|  "pr_body": "## Release v{{ version }}\n\n{{ changelog }}\n\n---\n*This PR was automatically created by moon-release.*",
    #|  "pr_branch_prefix": "release/",
    #|  "base_branch": "main",
    #|  "allow_prerelease": false,
    #|  "git_tag_enable": true,
    #|  "git_tag_name": "v{{ version }}",
    #|  "git_release_enable": true,
    #|  "git_release_draft": false,
    #|  "git_release_name": "Release v{{ version }}",
    #|  "git_release_body": null,
    #|  "git_release_latest": true,
    #|  "moon_publish": true,
    #|  "moon_publish_frozen": false,
    #|  "moon_publish_timeout": 300,
    #|  "npm_publish": false,
    #|  "npm_publish_provenance": true,
    #|  "npm_publish_timeout": 300,
    #|  "semver_check": false,
    #|  "registry_check": false,
    #|  "allow_dirty": false,
    #|  "packages": []
    #|}
  json
}

/// version command
fn cmd_version() -> Unit {
  println("moon-release v" + version)
  println("")
  println("A release automation tool for MoonBit projects.")
  println("Similar to release-plz, but designed for MoonBit.")
  println("")
  println("Features:")
  println("  - Conventional Commits parsing")
  println("  - Semantic Versioning")
  println("  - moon.mod.json version management")
  println("  - Git tag creation")
  println("  - GitHub release creation")
  println("  - mooncakes.io publishing")
}

/// set-version command
async fn cmd_set_version(
  subcmd : @clap.SimpleValue,
  global_dry_run : Bool,
  verbose : Bool
) -> Unit {
  // Check subcommand flags as well
  let subcmd_dry_run = match subcmd.get_flag("dry-run") {
    Some(v) => v
    None => false
  }
  let dry_run = global_dry_run || subcmd_dry_run

  // Get version argument (positional argument)
  let version_str : String = if subcmd.positional_args.length() > 0 {
    subcmd.positional_args[0]
  } else {
    println("Error: Version argument is required")
    println("Usage: moon-release set-version <version>")
    exit_error()
  }

  // Parse version
  let new_version = match @semver.Version::parse(version_str) {
    Some(v) => v
    None => {
      println("Error: Invalid version format: " + version_str)
      println("Expected format: major.minor.patch (e.g., 1.2.3)")
      exit_error()
    }
  }

  if verbose {
    println("Setting version to: " + new_version.to_string())
  }

  // Read current moon.mod.json with try-catch-noraise pattern
  let moon_mod_content = try @fs.read_file("moon.mod.json").text() catch {
    e => {
      println("Error: Failed to read moon.mod.json: " + e.to_string())
      exit_error()
    }
  } noraise { r => r }

  // Get current version with try-catch-noraise pattern
  let moon_mod = try @moon_mod.parse(moon_mod_content) catch {
    e => {
      println("Error: Failed to parse moon.mod.json: " + e.to_string())
      exit_error()
    }
  } noraise { r => r }

  if dry_run {
    println("[dry-run] Would update moon.mod.json:")
    println("  Current version: " + moon_mod.version)
    println("  New version: " + new_version.to_string())
    return
  }

  // Update version with try-catch-noraise pattern
  let updated_content = try @moon_mod.update_version(moon_mod_content, new_version) catch {
    e => {
      println("Error: Failed to update version: " + e.to_string())
      exit_error()
    }
  } noraise { r => r }

  // Write file with try-catch-noraise pattern
  try @fs.write_file("moon.mod.json", updated_content, create=0o644) catch {
    e => {
      println("Error: Failed to write moon.mod.json: " + e.to_string())
      exit_error()
    }
  } noraise { _ => () }

  println("Updated moon.mod.json:")
  println("  " + moon_mod.version + " -> " + new_version.to_string())
}

/// check command
async fn cmd_check(
  subcmd : @clap.SimpleValue,
  _dry_run : Bool,
  verbose : Bool,
  _config_path : String
) -> Unit {
  let from_tag : String? = match subcmd.args.get("from") {
    Some(arr) if arr.length() > 0 => Some(arr[0])
    _ => None
  }
  // Use try? + unwrap_or pattern for consistent error handling
  let output_format = (try? subcmd.get_one("output")).unwrap_or("text")
  let json_output = output_format == "json"

  if not(json_output) {
    println("Checking current state...")
    println("")
    match from_tag {
      Some(tag) => println("Analyzing commits since: " + tag)
      None => println("Analyzing commits since last tag...")
    }
  }

  // Get Git repository
  let repo = @git.Repository::current()

  // Get latest tag with try? + to_option + bind pattern
  let latest_tag = (try? get_latest_tag(repo)).to_option().bind(fn(x) { x })

  if not(json_output) {
    match latest_tag {
      Some(tag) => println("Latest tag: " + tag)
      None => println("No tags found")
    }
  }

  // Get commits with try-catch-noraise pattern
  let commits = try get_commits_since_last_tag(repo) catch {
    e => {
      if json_output {
        println("{\"error\": \"" + escape_json_string(e.to_string()) + "\"}")
      } else {
        println("Error getting commits: " + e.to_string())
      }
      exit_error()
    }
  } noraise { r => r }

  // Determine bump type
  let bump_type = if commits.length() > 0 {
    @semver.determine_bump(commits.map(fn(c) { c.0 }))
  } else {
    None
  }

  // JSON output
  if json_output {
    // latest_tag
    let latest_tag_json = match latest_tag {
      Some(tag) => json_string(tag)
      None => "null"
    }
    // suggested_bump
    let bump_json = match bump_type {
      Some(@semver.Major) => "\"major\""
      Some(@semver.Minor) => "\"minor\""
      Some(@semver.Patch) => "\"patch\""
      None => "null"
    }
    // commits array
    let commits_json_arr : Array[String] = []
    for i = 0; i < commits.length(); i = i + 1 {
      let (cc, hash) = commits[i]
      let scope_json = match cc.scope {
        Some(s) => json_string(s)
        None => "null"
      }
      let commit_json = build_json_object([
        ("hash", json_string(hash)),
        ("type", json_string(commit_type_to_string(cc.typ))),
        ("scope", scope_json),
        ("description", json_string(cc.description)),
        ("breaking", cc.breaking.to_string()),
      ])
      commits_json_arr.push(commit_json)
    }
    let commits_json = "[" + commits_json_arr.iter().fold(init="", fn(acc, s) {
      if acc.is_empty() { s } else { acc + "," + s }
    }) + "]"

    let json_str = build_json_object([
      ("latest_tag", latest_tag_json),
      ("commits_count", commits.length().to_string()),
      ("suggested_bump", bump_json),
      ("commits", commits_json),
    ])
    println(json_str)
    return
  }

  // Text output
  println("Commits since last tag: \{commits.length()}")

  if verbose && commits.length() > 0 {
    println("")
    println("Commits:")
    for i = 0; i < commits.length() && i < 10; i = i + 1 {
      let (cc, hash) = commits[i]
      let typ_str = commit_type_to_string(cc.typ)
      let scope_str = match cc.scope {
        Some(s) => "(" + s + ")"
        None => ""
      }
      let breaking_str = if cc.breaking { "!" } else { "" }
      let short_hash = substr_hash(hash, 7)
      println("  \{short_hash} \{typ_str}\{scope_str}\{breaking_str}: \{cc.description}")
    }
    if commits.length() > 10 {
      println("  ... and \{commits.length() - 10} more")
    }
  }

  // Display bump type
  if commits.length() > 0 {
    println("")
    match bump_type {
      Some(@semver.Major) => println("Suggested bump: major (breaking changes)")
      Some(@semver.Minor) => println("Suggested bump: minor (new features)")
      Some(@semver.Patch) => println("Suggested bump: patch (bug fixes)")
      None => println("No releasable changes")
    }
  }

  println("")
  println("Status: Ready for release analysis")
  println("")
  println("To perform a release, run:")
  println("  moon-release update --dry-run  # Preview changes")
  println("  moon-release update            # Update files locally")
  println("  moon-release release-pr        # Create release PR")
  println("  moon-release release           # Create release")
}

/// Convert commit type to string
fn commit_type_to_string(typ : @conventional.CommitType) -> String {
  match typ {
    @conventional.Feat => "feat"
    @conventional.Fix => "fix"
    @conventional.Docs => "docs"
    @conventional.Style => "style"
    @conventional.Refactor => "refactor"
    @conventional.Perf => "perf"
    @conventional.Test => "test"
    @conventional.Build => "build"
    @conventional.Ci => "ci"
    @conventional.Chore => "chore"
    @conventional.Revert => "revert"
    @conventional.Custom(s) => s
  }
}

/// Escape JSON string (wrapper for util module)
fn escape_json_string(s : String) -> String {
  @util.escape_json_string(s)
}

/// Create JSON string literal (with quotes)
fn json_string(s : String) -> String {
  @util.json_string(s)
}

/// Build JSON object
fn build_json_object(pairs : Array[(String, String)]) -> String {
  @util.build_json_object(pairs)
}

// ======== Helper functions ========

/// Load configuration with try-catch-noraise pattern
async fn load_config(path : String, verbose~ : Bool = false) -> @config.Config {
  // Check if file exists with try-catch-noraise pattern
  let content = try @fs.read_file(path).text() catch {
    e => {
      if verbose {
        println("Note: Config file not found or unreadable (" + path + "): " + e.to_string())
        println("Using default configuration.")
      }
      return @config.Config::default()
    }
  } noraise { r => r }

  // Parse config - fail if file exists but is invalid
  try @config.Config::parse(content) catch {
    e => {
      println("Error: Failed to parse config file (" + path + "): " + e.to_string())
      println("Fix the configuration file or delete it to use defaults.")
      exit_error()
    }
  } noraise { r => r }
}

/// Load moon.mod.json
async fn load_moon_mod(path : String) -> @moon_mod.MoonMod raise {
  let content = @fs.read_file(path).text()
  @moon_mod.parse(content)
}

/// Get commits from latest tag to current
async fn get_commits_since_last_tag(
  repo : @git.Repository,
  max_commits~ : UInt? = None
) -> Array[(@conventional.ConventionalCommit, String)] raise {
  // Get latest tag with try? + to_option + bind pattern
  let latest_tag = (try? get_latest_tag(repo)).to_option().bind(fn(x) { x })

  // Get commit log
  let log_result = match latest_tag {
    Some(tag) => {
      let cmd = repo.get_commits_since_tag_command(tag)
      // Add max_commits if specified
      match max_commits {
        Some(n) => {
          cmd.push("-n")
          cmd.push(n.to_string())
        }
        None => ()
      }
      @executor.run_command(cmd)
    }
    None => {
      let cmd = repo.get_all_commits_command()
      // Add max_commits if specified
      match max_commits {
        Some(n) => {
          cmd.push("-n")
          cmd.push(n.to_string())
        }
        None => ()
      }
      @executor.run_command(cmd)
    }
  }

  // Parse
  let git_commits = @git.parse_commit_log(log_result.stdout)
  @git.parse_conventional_commits(git_commits)
}

/// Get latest tag
async fn get_latest_tag(repo : @git.Repository) -> String? raise {
  let cmd = repo.get_latest_tag_command()
  let result = @executor.run_command(cmd)
  if result.is_success() {
    let tag = result.stdout_trimmed()
    if tag.is_empty() { None } else { Some(tag) }
  } else {
    None
  }
}

/// Get bump type
fn get_bump_type(subcmd : @clap.SimpleValue) -> @semver.BumpType? {
  match subcmd.args.get("bump") {
    Some(arr) if arr.length() > 0 =>
      match arr[0] {
        "major" => Some(@semver.Major)
        "minor" => Some(@semver.Minor)
        "patch" => Some(@semver.Patch)
        _ => None
      }
    _ => None
  }
}

/// Get GitHub client
async fn get_github_client() -> @github.GitHubClient raise {
  // Get owner/repo using gh repo view
  let result = @executor.run_command(
    ["gh", "repo", "view", "--json", "owner,name"],
  )
  if not(result.is_success()) {
    let hint = if result.stderr.contains("not a git repository") {
      "The current directory is not a git repository."
    } else if result.stderr.contains("gh auth login") || result.stderr.contains("authentication") {
      "Run 'gh auth login' to authenticate with GitHub."
    } else if result.stderr.contains("not found") || result.stderr.contains("command not found") {
      "The 'gh' CLI is not installed. Install it from https://cli.github.com/"
    } else {
      "Make sure you are in a GitHub repository and have 'gh' CLI installed and authenticated."
    }
    raise @workflow.WorkflowError(
      "Failed to get repository info: " + result.stderr.trim().to_string() + "\nHint: " + hint,
    )
  }

  // Parse JSON with try-catch-noraise pattern
  let json = try @json.parse(result.stdout) catch {
    e => raise @workflow.WorkflowError("Failed to parse repository info from 'gh' output: " + e.to_string())
  } noraise { r => r }

  match json {
    Object(obj) => {
      let owner = match obj.get("owner") {
        Some(Object(o)) =>
          match o.get("login") {
            Some(String(s)) => s
            _ => raise @workflow.WorkflowError("Invalid owner info: expected 'owner.login' to be a string in 'gh' output")
          }
        _ => raise @workflow.WorkflowError("Invalid owner info: expected 'owner' to be an object in 'gh' output")
      }
      let name = match obj.get("name") {
        Some(String(s)) => s
        _ => raise @workflow.WorkflowError("Invalid repo name: expected 'name' to be a string in 'gh' output")
      }
      @github.GitHubClient::new(owner, name)
    }
    _ => raise @workflow.WorkflowError("Invalid repository info: expected JSON object from 'gh' output")
  }
}

/// Shorten hash
fn substr_hash(hash : String, len : Int) -> String {
  if hash.length() <= len {
    return hash
  }
  let chars : Array[Char] = hash.to_array()
  let result = StringBuilder::new()
  for i = 0; i < len; i = i + 1 {
    if i < chars.length() {
      result.write_char(chars[i])
    }
  }
  result.to_string()
}

/// Check for uncommitted changes
/// Returns (is_dirty, error_occurred)
async fn check_dirty(repo : @git.Repository, verbose : Bool) -> (Bool, Bool) {
  // Check git status with try-catch-noraise pattern
  let result = try @executor.run_git(repo, ["status", "--porcelain"]) catch {
    e => {
      if verbose {
        println("Warning: Failed to check git status: " + e.to_string())
        println("Assuming working directory is clean.")
      }
      return (false, true)
    }
  } noraise { r => r }
  (not(result.stdout.trim().is_empty()), false)
}

/// Check allow_dirty (returns true if dirty and allow_dirty=false)
async fn should_abort_dirty(
  config : @config.Config,
  repo : @git.Repository,
  verbose : Bool
) -> Bool {
  if config.allow_dirty {
    return false
  }

  let (is_dirty, _error_occurred) = check_dirty(repo, verbose)
  if is_dirty {
    println("Error: Working directory has uncommitted changes.")
    println("Commit or stash your changes, or set 'allow_dirty: true' in config.")
    if verbose {
      // Get status with try-catch-noraise pattern
      let result = try @executor.run_git(repo, ["status", "--short"]) catch {
        e => {
          println("Warning: Failed to get file list: " + e.to_string())
          return true
        }
      } noraise { r => r }
      println("")
      println("Changed files:")
      println(result.stdout)
    }
    return true
  }
  false
}

/// generate-schema command
fn cmd_generate_schema() -> Unit {
  let schema =
    #|{
    #|  "$schema": "http://json-schema.org/draft-07/schema#",
    #|  "title": "moon-release configuration",
    #|  "description": "Configuration file for moon-release, a release automation tool for MoonBit projects",
    #|  "type": "object",
    #|  "properties": {
    #|    "pr_title": {
    #|      "type": "string",
    #|      "description": "Title template for release PR. Use {{ version }} placeholder.",
    #|      "default": "chore: release v{{ version }}"
    #|    },
    #|    "pr_draft": {
    #|      "type": "boolean",
    #|      "description": "Create PR as draft",
    #|      "default": false
    #|    },
    #|    "pr_labels": {
    #|      "type": "array",
    #|      "items": { "type": "string" },
    #|      "description": "Labels to add to release PR",
    #|      "default": []
    #|    },
    #|    "pr_body": {
    #|      "type": "string",
    #|      "description": "Body template for release PR. Use {{ version }} placeholder.",
    #|      "default": "## Release v{{ version }}\n\n---\n*This PR was automatically created by moon-release.*"
    #|    },
    #|    "allow_prerelease": {
    #|      "type": "boolean",
    #|      "description": "Allow prerelease versions",
    #|      "default": false
    #|    },
    #|    "git_tag_enable": {
    #|      "type": "boolean",
    #|      "description": "Create git tag on release",
    #|      "default": true
    #|    },
    #|    "git_tag_name": {
    #|      "type": "string",
    #|      "description": "Tag name template. Use {{ version }} placeholder.",
    #|      "default": "v{{ version }}"
    #|    },
    #|    "git_release_enable": {
    #|      "type": "boolean",
    #|      "description": "Create GitHub release",
    #|      "default": true
    #|    },
    #|    "git_release_draft": {
    #|      "type": "boolean",
    #|      "description": "Create GitHub release as draft",
    #|      "default": false
    #|    },
    #|    "git_release_name": {
    #|      "type": "string",
    #|      "description": "Release name template. Use {{ version }} placeholder.",
    #|      "default": "Release v{{ version }}"
    #|    },
    #|    "git_release_body": {
    #|      "type": ["string", "null"],
    #|      "description": "Release body template. Use {{ version }} and {{ changelog }} placeholders. If null, uses auto-generated changelog.",
    #|      "default": null
    #|    },
    #|    "git_release_latest": {
    #|      "type": "boolean",
    #|      "description": "Mark the GitHub release as latest",
    #|      "default": true
    #|    },
    #|    "moon_publish": {
    #|      "type": "boolean",
    #|      "description": "Publish to mooncakes.io registry",
    #|      "default": true
    #|    },
    #|    "moon_publish_frozen": {
    #|      "type": "boolean",
    #|      "description": "Use --frozen flag when publishing to mooncakes.io",
    #|      "default": false
    #|    },
    #|    "moon_publish_timeout": {
    #|      "type": "integer",
    #|      "minimum": 0,
    #|      "description": "Timeout in seconds for moon publish command",
    #|      "default": 300
    #|    },
    #|    "npm_publish": {
    #|      "type": "boolean",
    #|      "description": "Publish to npm registry (uses Trusted Publishing)",
    #|      "default": false
    #|    },
    #|    "npm_build_command": {
    #|      "type": ["string", "null"],
    #|      "description": "Command to build JS target before npm publish. Default: moon build --target js",
    #|      "default": null
    #|    },
    #|    "npm_publish_provenance": {
    #|      "type": "boolean",
    #|      "description": "Use --provenance flag for npm publish (requires GitHub Actions with id-token: write). Set to false for local or non-GitHub CI publishing.",
    #|      "default": true
    #|    },
    #|    "npm_publish_timeout": {
    #|      "type": "integer",
    #|      "minimum": 0,
    #|      "description": "Timeout in seconds for npm publish command",
    #|      "default": 300
    #|    },
    #|    "semver_check": {
    #|      "type": "boolean",
    #|      "description": "Check semver compatibility before release",
    #|      "default": false
    #|    },
    #|    "pr_branch_prefix": {
    #|      "type": "string",
    #|      "description": "Prefix for release branch names",
    #|      "default": "release/"
    #|    },
    #|    "base_branch": {
    #|      "type": "string",
    #|      "description": "Base branch for release PRs",
    #|      "default": "main"
    #|    },
    #|    "packages": {
    #|      "type": "array",
    #|      "description": "Package configurations for monorepo mode",
    #|      "items": {
    #|        "type": "object",
    #|        "properties": {
    #|          "name": {
    #|            "type": "string",
    #|            "description": "Package name"
    #|          },
    #|          "path": {
    #|            "type": "string",
    #|            "description": "Path to package directory",
    #|            "default": "."
    #|          },
    #|          "moon_publish": {
    #|            "type": "boolean",
    #|            "description": "Publish this package to mooncakes.io",
    #|            "default": true
    #|          },
    #|          "npm_publish": {
    #|            "type": "boolean",
    #|            "description": "Publish this package to npm",
    #|            "default": false
    #|          },
    #|          "npm_build_command": {
    #|            "type": ["string", "null"],
    #|            "description": "Command to build JS target for this package",
    #|            "default": null
    #|          },
    #|          "version_group": {
    #|            "type": ["string", "null"],
    #|            "description": "Version group for synchronized versioning",
    #|            "default": null
    #|          }
    #|        },
    #|        "required": ["name"]
    #|      },
    #|      "default": []
    #|    },
    #|    "registry_check": {
    #|      "type": "boolean",
    #|      "description": "Check if version already exists in registry before release",
    #|      "default": false
    #|    },
    #|    "allow_dirty": {
    #|      "type": "boolean",
    #|      "description": "Allow release with uncommitted changes",
    #|      "default": false
    #|    },
    #|    "custom_major_increment_regex": {
    #|      "type": ["string", "null"],
    #|      "description": "Custom regex pattern for major version increment commits",
    #|      "default": null
    #|    },
    #|    "custom_minor_increment_regex": {
    #|      "type": ["string", "null"],
    #|      "description": "Custom regex pattern for minor version increment commits",
    #|      "default": null
    #|    },
    #|    "max_analyze_commits": {
    #|      "type": ["integer", "null"],
    #|      "minimum": 1,
    #|      "description": "Maximum number of commits to analyze for version determination",
    #|      "default": null
    #|    }
    #|  },
    #|  "additionalProperties": false
    #|}
  println(schema)
}
