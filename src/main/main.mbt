/// moon-release CLI
/// Automated release tool

///|
/// Version extracted from embedded moon.mod.json (generated at build time)
let version : String = extract_version(embedded_moon_mod_json)

///|
/// Maximum number of commits to display in verbose output
let max_verbose_commits : Int = 10

///|
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

///|
/// Exit with status code (wrapper to avoid MSVC C2371 conflict with stdlib exit)
extern "C" fn c_exit(status : Int) -> Unit = "moon_release_exit"

///|
/// Exit with error (non-zero status code)
/// Uses panic() to satisfy type checker since exit never returns
fn[T] exit_error() -> T {
  c_exit(1)
  panic()
}

// ============================================================================
// Output helpers for consistent error/warning formatting
// ============================================================================

///|
/// Output error message (supports JSON and text formats)
fn output_error(msg : String, json_output : Bool) -> Unit {
  if json_output {
    println("{\"error\": " + @util.json_string(msg) + "}")
  } else {
    println("Error: " + msg)
  }
}

///|
/// Output error message with hint (text mode only shows hint)
fn output_error_with_hint(
  msg : String,
  hint : String,
  json_output : Bool,
) -> Unit {
  if json_output {
    println("{\"error\": " + @util.json_string(msg) + "}")
  } else {
    println("Error: " + msg)
    println("Hint: " + hint)
  }
}

///|
/// Handle workflow error with automatic hint from error variant
fn handle_workflow_error(
  e : @workflow.WorkflowError,
  json_output : Bool,
  hint_override? : String = "",
) -> Unit {
  let hint = if hint_override.is_empty() { e.hint() } else { hint_override }
  if hint.is_empty() {
    output_error(e.to_string(), json_output)
  } else {
    output_error_with_hint(e.to_string(), hint, json_output)
  }
}

///|
/// Output warning message (suppressed in JSON mode)
fn output_warning(msg : String, json_output : Bool) -> Unit {
  if not(json_output) {
    println("Warning: " + msg)
  }
}

///|
/// Get dry-run flag from subcommand (combines global and subcommand flags)
fn get_dry_run_flag(subcmd : @clap.SimpleValue, global_dry_run : Bool) -> Bool {
  let subcmd_dry_run = match subcmd.get_flag("dry-run") {
    Some(v) => v
    None => false
  }
  global_dry_run || subcmd_dry_run
}

///|
/// Get output format from subcommand (returns true if JSON)
fn get_json_output(subcmd : @clap.SimpleValue) -> Bool {
  // Use try? + unwrap_or pattern for consistent error handling
  let output_format = (try? subcmd.get_one("output")).unwrap_or("text")
  output_format == "json"
}

///|
/// Print verbose header for command
fn print_verbose_header(
  cmd_name : String,
  config_path : String,
  dry_run : Bool,
  verbose : Bool,
  json_output : Bool,
) -> Unit {
  if verbose && not(json_output) {
    println("Running " + cmd_name + " command...")
    println("  Config: " + config_path)
    println("  Dry run: " + dry_run.to_string())
  }
}

///|
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
          "bump-all": @clap.Arg::flag(
            help="Force bump ALL packages including unchanged ones",
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
          "bump-all": @clap.Arg::flag(
            help="Force bump ALL packages including unchanged ones",
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
          "bump-all": @clap.Arg::flag(
            help="Force bump ALL packages including unchanged ones",
          ),
          "prerelease": @clap.Arg::named(
            short='p',
            nargs=@clap.AtMost(1),
            help="Create a prerelease with the given identifier (e.g., alpha, beta, rc)",
          ),
        },
      ),
      "init": @clap.SubCommand::new(help="Initialize release configuration", args={
        "force": @clap.Arg::flag(
          short='f',
          help="Overwrite existing configuration",
        ),
      }),
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

///|
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
  } noraise {
    r => r
  }

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

///|
/// update command
async fn cmd_update(
  subcmd : @clap.SimpleValue,
  global_dry_run : Bool,
  verbose : Bool,
  config_path : String,
) -> Unit {
  let dry_run = get_dry_run_flag(subcmd, global_dry_run)
  let json_output = get_json_output(subcmd)

  print_verbose_header("update", config_path, dry_run, verbose, json_output)

  // Load config and repo
  let config = load_config(config_path, verbose~, json_output~)
  let repo = @git.Repository::current()

  // Dirty check
  try @workflow.check_working_directory(config, repo, verbose~) catch {
    e => {
      if json_output {
        output_error("uncommitted changes in working directory", json_output)
      } else {
        output_error(e.to_string(), json_output)
      }
      exit_error()
    }
  } noraise {
    _ => ()
  }

  // Parse bump options before monorepo branching
  let forced_bump = get_bump_type(subcmd)
  let cli_bump_all = match subcmd.get_flag("bump-all") {
    Some(v) => v
    None => false
  }
  let bump_all = config.bump_all_packages || cli_bump_all

  // Check if monorepo mode
  let packages_mode = match subcmd.get_flag("packages") {
    Some(v) => v
    None => false
  }

  // In monorepo mode, update each package separately with try-catch-noraise pattern
  if packages_mode || not(config.packages.is_empty()) {
    // Hint: --bump only controls bump type, not scope
    if forced_bump is Some(_) && not(bump_all) && not(json_output) {
      println(
        "Note: --bump applies only to packages with changes. Use --bump-all to include all packages.",
      )
    }
    try
      @workflow.run_update_packages(
        config,
        repo,
        dry_run,
        verbose,
        forced_bump~,
        bump_all~,
      )
    catch {
      e => {
        handle_workflow_error(e, json_output)
        exit_error()
      }
    } noraise {
      _ => ()
    }
    return
  }

  // Analyze version bump
  let analysis = try
    @workflow.analyze_version_bump(
      config,
      repo,
      forced_bump~,
      max_commits=config.max_analyze_commits,
    )
  catch {
    e => {
      handle_workflow_error(
        e,
        json_output,
        hint_override="Use Conventional Commits (feat:, fix:) or --bump to force a version bump",
      )
      exit_error()
    }
  } noraise {
    r => r
  }

  let current_version = analysis.current_version
  let new_version = analysis.new_version
  let commits = analysis.commits
  let bump_type = analysis.bump_type

  // Registry check (if enabled) with try-catch-noraise pattern
  if config.registry_check {
    // Get package name: try moon.mod.json first, then package.json
    let pkg_name = match (try? load_moon_mod("moon.mod.json")).to_option() {
      Some(m) => m.name
      None =>
        match
          (try? load_package_json_name("package.json"))
          .to_option()
          .bind(fn(x) { x }) {
          Some(name) => name
          None => {
            output_warning(
              "Registry check skipped: could not determine package name from moon.mod.json or package.json",
              json_output,
            )
            ""
          }
        }
    }
    if not(pkg_name.is_empty()) {
      let should_rel = try
        @workflow.should_release(new_version, pkg_name, verbose)
      catch {
        e => {
          output_warning("Registry check failed: " + e.to_string(), json_output)
          true // Continue release on error
        }
      } noraise {
        r => r
      }

      if not(should_rel) {
        output_error(
          "Version " +
          new_version.to_string() +
          " is not newer than registry version. Nothing to update.",
          json_output,
        )
        exit_error()
      }
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

  // Run update
  try @workflow.run_update(ctx) catch {
    e => {
      handle_workflow_error(e, json_output)
      exit_error()
    }
  } noraise {
    _ =>
      if json_output {
        let bump_str = match bump_type {
          @semver.Major => "major"
          @semver.Minor => "minor"
          @semver.Patch => "patch"
        }
        let json_str = @util.build_json_object([
          ("old_version", @util.json_string(current_version.to_string())),
          ("new_version", @util.json_string(new_version.to_string())),
          ("bump_type", @util.json_string(bump_str)),
          ("commits_count", commits.length().to_string()),
          ("dry_run", dry_run.to_string()),
          (
            "updated_files",
            {
              let files : Array[String] = []
              if config.moon_publish {
                files.push("\"moon.mod.json\"")
              }
              if config.npm_publish {
                files.push("\"package.json\"")
              }
              "[" +
              files
              .iter()
              .fold(init="", fn(acc, s) {
                if acc.is_empty() {
                  s
                } else {
                  acc + "," + s
                }
              }) +
              "]"
            },
          ),
        ])
        println(json_str)
      }
  }
}

///|
/// Load config, validate publish settings, and check for dirty state.
/// Shared setup for release-pr and release commands.
async fn prepare_release_config(
  config_path : String,
  verbose : Bool,
  json_output : Bool,
) -> (@config.Config, @git.Repository) {
  let config = load_config(config_path, verbose~, json_output~)
  let repo = @git.Repository::current()

  try @workflow.validate_publish_config(config, verbose~) catch {
    e => {
      handle_workflow_error(e, json_output)
      exit_error()
    }
  } noraise {
    _ => ()
  }

  try @workflow.check_working_directory(config, repo, verbose~) catch {
    e => {
      handle_workflow_error(e, json_output)
      exit_error()
    }
  } noraise {
    _ => ()
  }

  (config, repo)
}

///|
/// Extract bump flags from subcmd (shared by release-pr and release commands).
fn get_bump_flags(
  subcmd : @clap.SimpleValue,
  config : @config.Config,
) -> (@semver.BumpType?, Bool) {
  let forced_bump = get_bump_type(subcmd)
  let cli_bump_all = match subcmd.get_flag("bump-all") {
    Some(v) => v
    None => false
  }
  let bump_all = config.bump_all_packages || cli_bump_all
  (forced_bump, bump_all)
}

///|
/// release-pr command
async fn cmd_release_pr(
  subcmd : @clap.SimpleValue,
  global_dry_run : Bool,
  verbose : Bool,
  config_path : String,
) -> Unit {
  let dry_run = get_dry_run_flag(subcmd, global_dry_run)
  let json_output = false // release-pr doesn't support JSON output

  print_verbose_header("release-pr", config_path, dry_run, verbose, json_output)

  let (config, repo) = prepare_release_config(config_path, verbose, json_output)
  let (forced_bump, bump_all) = get_bump_flags(subcmd, config)
  let is_monorepo = not(config.packages.is_empty())

  // Hint: --bump only controls bump type, not scope
  if is_monorepo && forced_bump is Some(_) && not(bump_all) {
    println(
      "Note: --bump applies only to packages with changes. Use --bump-all to include all packages.",
    )
  }

  // Get current version and new version
  let (current_version, new_version, commits) = if is_monorepo {
    // Monorepo: compute representative version from packages
    try
      @workflow.get_monorepo_representative_version(
        config,
        repo,
        forced_bump,
        verbose,
        bump_all~,
      )
    catch {
      e => {
        handle_workflow_error(e, json_output)
        exit_error()
      }
    } noraise {
      r => r
    }
  } else {
    // Single package: analyze version bump
    let analysis = try
      @workflow.analyze_version_bump(
        config,
        repo,
        forced_bump~,
        max_commits=config.max_analyze_commits,
      )
    catch {
      e => {
        handle_workflow_error(
          e,
          json_output,
          hint_override="Use Conventional Commits or --bump to force a version bump",
        )
        exit_error()
      }
    } noraise {
      r => r
    }
    (analysis.current_version, analysis.new_version, analysis.commits)
  }

  // Create context
  let ctx = @workflow.ReleaseContext::new(
    config,
    repo,
    current_version,
    new_version,
    commits,
    dry_run~,
    verbose~,
    forced_bump~,
    bump_all~,
  )

  // Get GitHub client
  let github = try @workflow.get_github_client() catch {
    e => {
      handle_workflow_error(e, json_output)
      exit_error()
    }
  } noraise {
    r => r
  }

  // Run workflow
  try @workflow.run_release_pr(ctx, github) catch {
    e => {
      handle_workflow_error(e, json_output)
      exit_error()
    }
  } noraise {
    _ => ()
  }
}

///|
/// release command
async fn cmd_release(
  subcmd : @clap.SimpleValue,
  global_dry_run : Bool,
  verbose : Bool,
  config_path : String,
) -> Unit {
  let dry_run = get_dry_run_flag(subcmd, global_dry_run)
  let json_output = false // release doesn't support JSON output

  print_verbose_header("release", config_path, dry_run, verbose, json_output)

  let (config, repo) = prepare_release_config(config_path, verbose, json_output)
  let (forced_bump, bump_all) = get_bump_flags(subcmd, config)
  let is_monorepo = not(config.packages.is_empty())

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
      "Prerelease is not allowed in configuration.", "Set 'allow_prerelease: true' in release.json to enable prereleases",
      json_output,
    )
    exit_error()
  }

  // Hint: --bump only controls bump type, not scope
  if is_monorepo && forced_bump is Some(_) && not(bump_all) {
    println(
      "Note: --bump applies only to packages with changes. Use --bump-all to include all packages.",
    )
  }

  // Get current version and new version
  let (current_version, new_version, commits) = if is_monorepo {
    // Monorepo: compute representative version from packages
    try
      @workflow.get_monorepo_representative_version(
        config,
        repo,
        forced_bump,
        verbose,
        bump_all~,
      )
    catch {
      e => {
        handle_workflow_error(e, json_output)
        exit_error()
      }
    } noraise {
      r => r
    }
  } else {
    // Single package: analyze version bump
    let analysis = try
      @workflow.analyze_version_bump(
        config,
        repo,
        forced_bump~,
        max_commits=config.max_analyze_commits,
        allow_empty_commits=true,
        default_bump=Some(@semver.Patch),
      )
    catch {
      e => {
        handle_workflow_error(
          e,
          json_output,
          hint_override="Create new commits or use --bump to force a version bump",
        )
        exit_error()
      }
    } noraise {
      r => r
    }
    (analysis.current_version, analysis.new_version, analysis.commits)
  }

  // Apply prerelease if specified
  let new_version = match prerelease {
    Some(pre_str) =>
      match new_version.with_prerelease(pre_str) {
        Some(v) => v
        None => {
          output_error_with_hint(
            "Invalid prerelease identifier: " + pre_str,
            "Prerelease must contain only ASCII alphanumerics and hyphens [0-9A-Za-z-]",
            json_output,
          )
          exit_error()
        }
      }
    None => new_version
  }

  // Create context
  let ctx = @workflow.ReleaseContext::new(
    config,
    repo,
    current_version,
    new_version,
    commits,
    dry_run~,
    verbose~,
    forced_bump~,
    bump_all~,
  )

  // Get GitHub client
  let github = try @workflow.get_github_client() catch {
    e => {
      handle_workflow_error(e, json_output)
      exit_error()
    }
  } noraise {
    r => r
  }

  // Run workflow
  try @workflow.run_release(ctx, github) catch {
    e => {
      handle_workflow_error(e, json_output)
      exit_error()
    }
  } noraise {
    _ => ()
  }
}

///|
/// init command
async fn cmd_init(
  subcmd : @clap.SimpleValue,
  dry_run : Bool,
  _verbose : Bool,
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
  } noraise {
    _ => ()
  }

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

///|
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
    #|  "bump_all_packages": false,
    #|  "max_analyze_commits": null,
    #|  "custom_major_increment_regex": null,
    #|  "custom_minor_increment_regex": null,
    #|  "npm_build_command": null,
    #|  "packages": []
    #|}
  json
}

///|
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

///|
/// set-version command
async fn cmd_set_version(
  subcmd : @clap.SimpleValue,
  global_dry_run : Bool,
  verbose : Bool,
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
  } noraise {
    r => r
  }

  // Get current version with try-catch-noraise pattern
  let moon_mod = try @moon_mod.parse(moon_mod_content) catch {
    e => {
      println("Error: Failed to parse moon.mod.json: " + e.to_string())
      exit_error()
    }
  } noraise {
    r => r
  }

  if dry_run {
    println("[dry-run] Would update moon.mod.json:")
    println("  Current version: " + moon_mod.version)
    println("  New version: " + new_version.to_string())
    return
  }

  // Update version with try-catch-noraise pattern
  let updated_content = try
    @moon_mod.update_version(moon_mod_content, new_version)
  catch {
    e => {
      println("Error: Failed to update version: " + e.to_string())
      exit_error()
    }
  } noraise {
    r => r
  }

  // Write file with try-catch-noraise pattern
  try @fs.write_file("moon.mod.json", updated_content, create=0o644) catch {
    e => {
      println("Error: Failed to write moon.mod.json: " + e.to_string())
      exit_error()
    }
  } noraise {
    _ => ()
  }

  println("Updated moon.mod.json:")
  println("  " + moon_mod.version + " -> " + new_version.to_string())
}

///|
/// check command
async fn cmd_check(
  subcmd : @clap.SimpleValue,
  _dry_run : Bool,
  verbose : Bool,
  config_path : String,
) -> Unit {
  // Use try? + unwrap_or pattern for consistent error handling
  let output_format = (try? subcmd.get_one("output")).unwrap_or("text")
  let json_output = output_format == "json"

  if not(json_output) {
    println("Checking current state...")
    println("")
    println("Analyzing commits since last tag...")
  }

  // Load config for custom bump rules
  let config = load_config(config_path, verbose~, json_output~)

  // Get Git repository
  let repo = @git.Repository::current()

  // Get latest tag
  let latest_tag = try @workflow.get_latest_tag(repo) catch {
    _ => None
  } noraise {
    r => r
  }

  if not(json_output) {
    match latest_tag {
      Some(tag) => println("Latest tag: " + tag)
      None => println("No tags found")
    }
  }

  // Get commits
  let commits = try
    @workflow.get_commits_since_last_tag(
      repo,
      max_commits=config.max_analyze_commits,
    )
  catch {
    e => {
      if json_output {
        println("{\"error\": " + @util.json_string(e.to_string()) + "}")
      } else {
        println("Error getting commits: " + e.to_string())
      }
      exit_error()
    }
  } noraise {
    r => r
  }

  // Determine bump type (uses custom bump rules from config if configured)
  let bump_type = if commits.length() > 0 {
    @semver.determine_bump_with_custom(
      commits.map(fn(c) { c.0 }),
      config.custom_major_increment_regex,
      config.custom_minor_increment_regex,
    )
  } else {
    None
  }

  // JSON output
  if json_output {
    // latest_tag
    let latest_tag_json = match latest_tag {
      Some(tag) => @util.json_string(tag)
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
        Some(s) => @util.json_string(s)
        None => "null"
      }
      let commit_json = @util.build_json_object([
        ("hash", @util.json_string(hash)),
        ("type", @util.json_string(commit_type_to_string(cc.typ))),
        ("scope", scope_json),
        ("description", @util.json_string(cc.description)),
        ("breaking", cc.breaking.to_string()),
      ])
      commits_json_arr.push(commit_json)
    }
    let commits_json = "[" +
      commits_json_arr
      .iter()
      .fold(init="", fn(acc, s) {
        if acc.is_empty() {
          s
        } else {
          acc + "," + s
        }
      }) +
      "]"

    let json_str = @util.build_json_object([
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
    for i = 0; i < commits.length() && i < max_verbose_commits; i = i + 1 {
      let (cc, hash) = commits[i]
      let typ_str = commit_type_to_string(cc.typ)
      let scope_str = match cc.scope {
        Some(s) => "(" + s + ")"
        None => ""
      }
      let breaking_str = if cc.breaking { "!" } else { "" }
      let short_hash = @workflow.short_hash(hash)
      println(
        "  \{short_hash} \{typ_str}\{scope_str}\{breaking_str}: \{cc.description}",
      )
    }
    if commits.length() > max_verbose_commits {
      println("  ... and \{commits.length() - max_verbose_commits} more")
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

///|
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

// ======== Helper functions ========

///|
/// Load configuration with try-catch-noraise pattern
async fn load_config(
  path : String,
  verbose? : Bool = false,
  json_output? : Bool = false,
) -> @config.Config {
  // Check if file exists with try-catch-noraise pattern
  let content = try @fs.read_file(path).text() catch {
    e => {
      if verbose {
        output_warning(
          "Config file not found or unreadable (" +
          path +
          "): " +
          e.to_string() +
          ". Using default configuration.",
          json_output,
        )
      }
      return @config.Config::default()
    }
  } noraise {
    r => r
  }

  // Parse config - fail if file exists but is invalid
  let warnings : Array[String] = []
  let config = try @config.Config::parse(content, warnings~) catch {
    e => {
      output_error(
        "Failed to parse config file (" +
        path +
        "): " +
        e.to_string() +
        ". Fix the configuration file or delete it to use defaults.",
        json_output,
      )
      exit_error()
    }
  } noraise {
    r => r
  }

  // Display warnings (suppressed in JSON mode)
  for w in warnings {
    output_warning(w, json_output)
  }

  config
}

///|
/// Load moon.mod.json
async fn load_moon_mod(path : String) -> @moon_mod.MoonMod {
  let content = @fs.read_file(path).text()
  @moon_mod.parse(content)
}

///|
/// Read package name from package.json (best effort)
async fn load_package_json_name(path : String) -> String? {
  let content = @fs.read_file(path).text()
  let json = @json.parse(content)
  match json {
    Object(map) =>
      match map.get("name") {
        Some(String(name)) => Some(name)
        _ => None
      }
    _ => None
  }
}

///|
/// Get bump type
fn get_bump_type(subcmd : @clap.SimpleValue) -> @semver.BumpType? {
  match subcmd.args.get("bump") {
    Some(arr) if arr.length() > 0 =>
      match arr[0] {
        "major" => Some(@semver.Major)
        "minor" => Some(@semver.Minor)
        "patch" => Some(@semver.Patch)
        bump_value => {
          println(
            "Error: Invalid bump value '\{bump_value}'. Expected 'major', 'minor', or 'patch'.",
          )
          exit_error()
        }
      }
    _ => None
  }
}

///|
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
    #|      "default": "## Release v{{ version }}\n\n{{ changelog }}\n\n---\n*This PR was automatically created by moon-release.*"
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
    #|    },
    #|    "bump_all_packages": {
    #|      "type": "boolean",
    #|      "description": "Bump all packages uniformly using the highest bump type from changed packages (fixed versioning for monorepo)",
    #|      "default": false
    #|    }
    #|  },
    #|  "additionalProperties": false
    #|}
  println(schema)
}
