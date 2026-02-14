// ============================================================================
// ADT types for type-safe config access
// ============================================================================

///|
/// Publish target — represents which registries to publish to
pub enum PublishTarget {
  MooncakesOnly // Only mooncakes.io
  NpmOnly(NpmConfig) // Only npm
  Both(NpmConfig) // Both mooncakes.io and npm
  NoPublish // No publishing
} derive(Show, Eq)

///|
/// npm-specific configuration
pub(all) struct NpmConfig {
  build_command : String? // Custom build command (None = default "moon build --target js")
  provenance : Bool // Use --provenance flag for Trusted Publishing
  timeout : UInt // Publish timeout in seconds
} derive(Show, Eq)

///|
/// Git release mode — how releases are created
pub enum GitReleaseMode {
  GitHubRelease(draft~ : Bool, latest~ : Bool) // Full GitHub release
  TagOnly // Create tag only (no GitHub release)
  NoGitRelease // No tag, no release
} derive(Show, Eq)

// ============================================================================
// Config struct
// ============================================================================

///|
/// Configuration
pub struct Config {
  pr_title : String
  pr_draft : Bool
  pr_labels : Array[String]
  pr_body : String
  allow_prerelease : Bool
  git_tag_enable : Bool
  git_tag_name : String
  git_release_enable : Bool
  git_release_draft : Bool
  git_release_name : String
  git_release_body : String?
  git_release_latest : Bool
  moon_publish : Bool
  moon_publish_frozen : Bool
  npm_publish : Bool
  npm_build_command : String? // Command to build JS target before npm publish
  npm_publish_provenance : Bool // Use --provenance flag (requires GitHub Actions with id-token: write)
  semver_check : Bool
  pr_branch_prefix : String
  base_branch : String
  packages : Array[PackageConfig]
  registry_check : Bool
  allow_dirty : Bool
  // NOTE: Despite the name "regex", these fields use substring matching, not regular expressions.
  // The name is kept for backward compatibility with existing config files.
  custom_major_increment_regex : String? // Substring match (not regex). Matches if commit description contains this string.
  custom_minor_increment_regex : String? // Substring match (not regex). Matches if commit description contains this string.
  max_analyze_commits : UInt?
  moon_publish_timeout : UInt // In seconds
  npm_publish_timeout : UInt // In seconds
  bump_all_packages : Bool // Bump all packages uniformly (fixed versioning for monorepo)
  bootstrap_sha : String? // Starting commit SHA for initial release (skip earlier history)
} derive(Show, Eq)

///|
/// Package configuration (for monorepo)
pub struct PackageConfig {
  name : String
  path : String
  moon_publish : Bool
  npm_publish : Bool
  npm_build_command : String? // Command to build JS target before npm publish
  version_group : String?
} derive(Show, Eq)

///|
/// Configuration error
pub suberror ConfigError {
  ConfigError(String)
}

///|
/// Convert ConfigError to string
pub fn ConfigError::to_string(self : ConfigError) -> String {
  match self {
    ConfigError(msg) => msg
  }
}

///|
/// Default configuration
pub fn Config::default() -> Config {
  Config::{
    pr_title: "chore: release v{{ version }}",
    pr_draft: false,
    pr_labels: [],
    pr_body: "## Release v{{ version }}\n\n{{ changelog }}\n\n---\n*This PR was automatically created by moon-release.*",
    allow_prerelease: false,
    git_tag_enable: true,
    git_tag_name: "v{{ version }}",
    git_release_enable: true,
    git_release_draft: false,
    git_release_name: "Release v{{ version }}",
    git_release_body: None,
    git_release_latest: true,
    moon_publish: true,
    moon_publish_frozen: false,
    npm_publish: false, // Disabled by default
    npm_build_command: None, // Default: "moon build --target js" when npm_publish is true
    npm_publish_provenance: true, // Enabled by default (for Trusted Publishing)
    semver_check: false,
    pr_branch_prefix: "release/",
    base_branch: "main",
    packages: [],
    registry_check: false,
    allow_dirty: false,
    custom_major_increment_regex: None,
    custom_minor_increment_regex: None,
    max_analyze_commits: None,
    moon_publish_timeout: 300, // Default 5 minutes
    npm_publish_timeout: 300, // Default 5 minutes
    bump_all_packages: false,
    bootstrap_sha: None,
  }
}

///|
/// Default package configuration
pub fn PackageConfig::default(name : String, path : String) -> PackageConfig {
  PackageConfig::{
    name,
    path,
    moon_publish: true,
    npm_publish: false,
    npm_build_command: None,
    version_group: None,
  }
}

///|
/// Parse configuration from JSON (merge with defaults)
/// Warnings about unknown keys are collected into the `warnings` array instead of printing.
/// Callers can display them as appropriate (e.g., suppress in JSON output mode).
pub fn Config::parse(
  content : String,
  warnings? : Array[String] = [],
) -> Config raise ConfigError {
  let d = Config::default()

  if content.trim().is_empty() {
    return d
  }

  // Parse JSON with try-catch-noraise pattern
  let json = try @json.parse(content) catch {
    e => raise ConfigError("Invalid JSON in config file: " + e.to_string())
  } noraise {
    r => r
  }

  let obj = match json {
    Object(o) => o
    _ =>
      raise ConfigError(
        "Config file must contain a JSON object at the root level",
      )
  }

  // Check for unknown keys and warn
  let known_keys : Array[String] = [
    "pr_title", "pr_draft", "pr_labels", "pr_body", "allow_prerelease", "git_tag_enable",
    "git_tag_name", "git_release_enable", "git_release_draft", "git_release_name",
    "git_release_body", "git_release_latest", "moon_publish", "moon_publish_frozen",
    "npm_publish", "npm_build_command", "npm_publish_provenance", "semver_check",
    "pr_branch_prefix", "base_branch", "packages", "registry_check", "allow_dirty",
    "custom_major_increment_regex", "custom_minor_increment_regex", "max_analyze_commits",
    "moon_publish_timeout", "npm_publish_timeout", "bump_all_packages",
    "bootstrap_sha",
  ]
  let known_set : @hashset.HashSet[String] = @hashset.new()
  for k in known_keys {
    known_set.add(k)
  }
  for key, _ in obj {
    if not(known_set.contains(key)) {
      warnings.push("unknown config key '\{key}' in release.json")
    }
  }

  // packages needs special handling
  let packages = match obj.get("packages") {
    Some(Array(arr)) => parse_packages(arr)
    Some(_) =>
      raise ConfigError("'packages' must be an array of package objects")
    None => d.packages
  }

  let config = Config::{
    pr_title: parse_string(obj, "pr_title", d.pr_title),
    pr_draft: parse_bool(obj, "pr_draft", d.pr_draft),
    pr_labels: parse_string_array(obj, "pr_labels", d.pr_labels),
    pr_body: parse_string(obj, "pr_body", d.pr_body),
    allow_prerelease: parse_bool(obj, "allow_prerelease", d.allow_prerelease),
    git_tag_enable: parse_bool(obj, "git_tag_enable", d.git_tag_enable),
    git_tag_name: parse_string(obj, "git_tag_name", d.git_tag_name),
    git_release_enable: parse_bool(
      obj,
      "git_release_enable",
      d.git_release_enable,
    ),
    git_release_draft: parse_bool(obj, "git_release_draft", d.git_release_draft),
    git_release_name: parse_string(obj, "git_release_name", d.git_release_name),
    git_release_body: parse_optional_string(
      obj,
      "git_release_body",
      d.git_release_body,
    ),
    git_release_latest: parse_bool(
      obj,
      "git_release_latest",
      d.git_release_latest,
    ),
    moon_publish: parse_bool(obj, "moon_publish", d.moon_publish),
    moon_publish_frozen: parse_bool(
      obj,
      "moon_publish_frozen",
      d.moon_publish_frozen,
    ),
    npm_publish: parse_bool(obj, "npm_publish", d.npm_publish),
    npm_build_command: validate_optional_command(
      parse_optional_string(obj, "npm_build_command", d.npm_build_command),
      "npm_build_command",
    ),
    npm_publish_provenance: parse_bool(
      obj,
      "npm_publish_provenance",
      d.npm_publish_provenance,
    ),
    semver_check: parse_bool(obj, "semver_check", d.semver_check),
    pr_branch_prefix: parse_string(obj, "pr_branch_prefix", d.pr_branch_prefix),
    base_branch: parse_string(obj, "base_branch", d.base_branch),
    packages,
    registry_check: parse_bool(obj, "registry_check", d.registry_check),
    allow_dirty: parse_bool(obj, "allow_dirty", d.allow_dirty),
    custom_major_increment_regex: validate_pattern(
      parse_optional_string(
        obj,
        "custom_major_increment_regex",
        d.custom_major_increment_regex,
      ),
      "custom_major_increment_regex",
    ),
    custom_minor_increment_regex: validate_pattern(
      parse_optional_string(
        obj,
        "custom_minor_increment_regex",
        d.custom_minor_increment_regex,
      ),
      "custom_minor_increment_regex",
    ),
    max_analyze_commits: parse_optional_uint(
      obj,
      "max_analyze_commits",
      d.max_analyze_commits,
    ),
    moon_publish_timeout: parse_uint(
      obj,
      "moon_publish_timeout",
      d.moon_publish_timeout,
    ),
    npm_publish_timeout: parse_uint(
      obj,
      "npm_publish_timeout",
      d.npm_publish_timeout,
    ),
    bump_all_packages: parse_bool(obj, "bump_all_packages", d.bump_all_packages),
    bootstrap_sha: parse_optional_string(
      obj,
      "bootstrap_sha",
      d.bootstrap_sha,
    ),
  }

  // Validate: git_release_enable requires git_tag_enable
  if config.git_release_enable && not(config.git_tag_enable) {
    raise ConfigError(
      "'git_release_enable' requires 'git_tag_enable' to be true (cannot create a GitHub release without a tag)",
    )
  }

  config
}

///|
/// Parse package configuration
fn parse_packages(arr : Array[Json]) -> Array[PackageConfig] raise ConfigError {
  let result : Array[PackageConfig] = []
  for i = 0; i < arr.length(); i = i + 1 {
    match arr[i] {
      Object(pkg_obj) => {
        // Parse package fields with try-catch-noraise pattern
        let name = try parse_pkg_required_string(pkg_obj, "name") catch {
          e =>
            raise ConfigError(
              "packages[" + i.to_string() + "]: " + e.to_string(),
            )
        } noraise {
          r => r
        }
        let path = try parse_pkg_string(pkg_obj, "path", ".") catch {
          e =>
            raise ConfigError(
              "packages[" + i.to_string() + "] '" + name + "': " + e.to_string(),
            )
        } noraise {
          r => r
        }
        let moon_publish = try
          parse_pkg_bool(pkg_obj, "moon_publish", true)
        catch {
          e =>
            raise ConfigError(
              "packages[" + i.to_string() + "] '" + name + "': " + e.to_string(),
            )
        } noraise {
          r => r
        }
        let npm_publish = try
          parse_pkg_bool(pkg_obj, "npm_publish", false)
        catch {
          e =>
            raise ConfigError(
              "packages[" + i.to_string() + "] '" + name + "': " + e.to_string(),
            )
        } noraise {
          r => r
        }
        let npm_build_command_raw = try
          parse_pkg_optional_string(pkg_obj, "npm_build_command", None)
        catch {
          e =>
            raise ConfigError(
              "packages[" + i.to_string() + "] '" + name + "': " + e.to_string(),
            )
        } noraise {
          r => r
        }
        // Validate package path (prevent directory traversal and absolute paths)
        match
          @util.validate_path_full(path, allow_absolute=false).error_message() {
          Some(reason) =>
            raise ConfigError(
              "packages[" +
              i.to_string() +
              "] '" +
              name +
              "': invalid path '" +
              path +
              "': " +
              reason,
            )
          None => ()
        }
        let npm_build_command = try
          validate_optional_command(npm_build_command_raw, "npm_build_command")
        catch {
          e =>
            raise ConfigError(
              "packages[" + i.to_string() + "] '" + name + "': " + e.to_string(),
            )
        } noraise {
          r => r
        }
        let version_group = try
          parse_pkg_optional_string(pkg_obj, "version_group", None)
        catch {
          e =>
            raise ConfigError(
              "packages[" + i.to_string() + "] '" + name + "': " + e.to_string(),
            )
        } noraise {
          r => r
        }
        result.push(PackageConfig::{
          name,
          path,
          moon_publish,
          npm_publish,
          npm_build_command,
          version_group,
        })
      }
      _ =>
        raise ConfigError(
          "packages[" +
          i.to_string() +
          "]: must be an object, got " +
          arr[i].stringify(),
        )
    }
  }
  result
}

// ============================================================================
// JSON parse helper functions
// ============================================================================

///|
/// Validate that a command string does not contain shell control characters
/// that could be used for command injection.
/// Returns true if the command is safe, false if it contains dangerous characters.
fn validate_command(cmd : String) -> Bool {
  let chars = cmd.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    let c = chars[i]
    if c == ';' ||
      c == '|' ||
      c == '&' ||
      c == '`' ||
      c == '$' ||
      c == '\n' ||
      c == '\r' ||
      c == '\u0000' {
      return false
    }
  }
  true
}

///|
/// Validate an optional command string, raising ConfigError if it contains
/// shell control characters.
fn validate_optional_command(
  cmd : String?,
  field_name : String,
) -> String? raise ConfigError {
  match cmd {
    Some(c) =>
      if validate_command(c) {
        Some(c)
      } else {
        raise ConfigError(
          "'\{field_name}' contains shell control characters (;|&`$) which are not allowed",
        )
      }
    None => None
  }
}

///|
/// Validate custom pattern (used for increment patterns)
/// Note: These patterns use substring matching (contains), not regex
fn validate_pattern(
  pattern : String?,
  field_name : String,
) -> String? raise ConfigError {
  match pattern {
    Some(p) => {
      // Empty patterns are not useful
      if p.is_empty() {
        raise ConfigError(
          "'\{field_name}' cannot be empty (use null to disable)",
        )
      }
      // Warn about regex metacharacters that won't work as expected
      // Since we use substring matching, not actual regex
      let chars = p.to_array()
      for i = 0; i < chars.length(); i = i + 1 {
        let c = chars[i]
        // Check for common regex metacharacters
        if c == '^' ||
          c == '$' ||
          c == '*' ||
          c == '+' ||
          c == '?' ||
          c == '|' ||
          c == '(' ||
          c == ')' ||
          c == '[' ||
          c == ']' ||
          c == '{' ||
          c == '}' ||
          c == '\\' {
          raise ConfigError(
            "'\{field_name}' contains regex metacharacter '\{c}'. Note: This field uses simple substring matching, not regex. The pattern '\{p}' will be matched literally.",
          )
        }
      }
      Some(p)
    }
    None => None
  }
}

///|
/// Parse string field with configurable error prefix
fn parse_string_with_prefix(
  obj : Map[String, Json],
  key : String,
  default : String,
  prefix : String,
) -> String raise ConfigError {
  match obj.get(key) {
    Some(String(s)) => s
    Some(_) => raise ConfigError(prefix + "'" + key + "' must be a string")
    None => default
  }
}

///|
fn parse_string(
  obj : Map[String, Json],
  key : String,
  default : String,
) -> String raise ConfigError {
  parse_string_with_prefix(obj, key, default, "")
}

///|
fn parse_pkg_string(
  obj : Map[String, Json],
  key : String,
  default : String,
) -> String raise ConfigError {
  parse_string_with_prefix(obj, key, default, "package ")
}

///|
fn parse_pkg_required_string(
  obj : Map[String, Json],
  key : String,
) -> String raise ConfigError {
  match obj.get(key) {
    Some(String(s)) => s
    Some(_) => raise ConfigError("package '" + key + "' must be a string")
    None => raise ConfigError("package '" + key + "' is required")
  }
}

///|
/// Parse optional string field with configurable error prefix
fn parse_optional_string_with_prefix(
  obj : Map[String, Json],
  key : String,
  default : String?,
  prefix : String,
) -> String? raise ConfigError {
  match obj.get(key) {
    Some(String(s)) => Some(s)
    Some(Null) => None
    Some(_) => raise ConfigError(prefix + "'" + key + "' must be a string")
    None => default
  }
}

///|
fn parse_optional_string(
  obj : Map[String, Json],
  key : String,
  default : String?,
) -> String? raise ConfigError {
  parse_optional_string_with_prefix(obj, key, default, "")
}

///|
fn parse_pkg_optional_string(
  obj : Map[String, Json],
  key : String,
  default : String?,
) -> String? raise ConfigError {
  parse_optional_string_with_prefix(obj, key, default, "package ")
}

///|
/// Parse boolean field with configurable error prefix
fn parse_bool_with_prefix(
  obj : Map[String, Json],
  key : String,
  default : Bool,
  prefix : String,
) -> Bool raise ConfigError {
  match obj.get(key) {
    Some(True) => true
    Some(False) => false
    Some(_) => raise ConfigError(prefix + "'" + key + "' must be a boolean")
    None => default
  }
}

///|
fn parse_bool(
  obj : Map[String, Json],
  key : String,
  default : Bool,
) -> Bool raise ConfigError {
  parse_bool_with_prefix(obj, key, default, "")
}

///|
/// Parse optional number field with overflow protection
fn parse_optional_uint(
  obj : Map[String, Json],
  key : String,
  default : UInt?,
) -> UInt? raise ConfigError {
  match obj.get(key) {
    Some(Number(n, ..)) =>
      if n >= 0.0 && n <= @util.uint_max_as_double && n % 1.0 == 0.0 {
        Some(n.to_uint())
      } else if n > @util.uint_max_as_double {
        raise ConfigError("'" + key + "' value is too large (max: 4294967295)")
      } else {
        raise ConfigError("'" + key + "' must be a positive integer")
      }
    Some(Null) => None
    Some(_) => raise ConfigError("'" + key + "' must be a number")
    None => default
  }
}

///|
/// Parse number field with overflow protection
fn parse_uint(
  obj : Map[String, Json],
  key : String,
  default : UInt,
) -> UInt raise ConfigError {
  match obj.get(key) {
    Some(Number(n, ..)) =>
      if n >= 0.0 && n <= @util.uint_max_as_double && n % 1.0 == 0.0 {
        n.to_uint()
      } else if n > @util.uint_max_as_double {
        raise ConfigError("'" + key + "' value is too large (max: 4294967295)")
      } else {
        raise ConfigError("'" + key + "' must be a positive integer")
      }
    Some(_) => raise ConfigError("'" + key + "' must be a number")
    None => default
  }
}

///|
fn parse_pkg_bool(
  obj : Map[String, Json],
  key : String,
  default : Bool,
) -> Bool raise ConfigError {
  parse_bool_with_prefix(obj, key, default, "package ")
}

///|
/// Parse string array field
fn parse_string_array(
  obj : Map[String, Json],
  key : String,
  default : Array[String],
) -> Array[String] raise ConfigError {
  match obj.get(key) {
    Some(Array(arr)) => {
      let result : Array[String] = []
      for i = 0; i < arr.length(); i = i + 1 {
        match arr[i] {
          String(s) => result.push(s)
          _ => raise ConfigError("'" + key + "' must be an array of strings")
        }
      }
      result
    }
    Some(_) => raise ConfigError("'" + key + "' must be an array")
    None => default
  }
}

///|
/// Apply version to PR title template
pub fn Config::apply_pr_title_template(
  self : Config,
  version : String,
) -> String {
  self.pr_title.replace(old="{{ version }}", new=version)
}

// ============================================================================
// ADT accessor methods — derive typed values from flat config fields
// ============================================================================

///|
/// Get the publish target as a typed ADT
pub fn Config::publish_target(self : Config) -> PublishTarget {
  let npm_config = NpmConfig::{
    build_command: self.npm_build_command,
    provenance: self.npm_publish_provenance,
    timeout: self.npm_publish_timeout,
  }
  match (self.moon_publish, self.npm_publish) {
    (true, true) => Both(npm_config)
    (true, false) => MooncakesOnly
    (false, true) => NpmOnly(npm_config)
    (false, false) => NoPublish
  }
}

///|
/// Get the git release mode as a typed ADT
pub fn Config::git_release_mode(self : Config) -> GitReleaseMode {
  match (self.git_tag_enable, self.git_release_enable) {
    (true, true) =>
      GitHubRelease(
        draft=self.git_release_draft,
        latest=self.git_release_latest,
      )
    (true, false) => TagOnly
    // (false, true) is rejected by Config::parse validation
    (false, _) => NoGitRelease
  }
}

///|
/// Get package-level publish target
/// TODO: provenance and timeout are hardcoded defaults; they should reflect
/// Config.npm_publish_provenance / Config.npm_publish_timeout when callers
/// start using the NpmConfig values inside the returned PublishTarget.
/// Currently callers only match on the variant (MooncakesOnly, NpmOnly, etc.)
/// and use Config-level settings directly for actual publish operations.
pub fn PackageConfig::publish_target(self : PackageConfig) -> PublishTarget {
  let npm_config = NpmConfig::{
    build_command: self.npm_build_command,
    provenance: true,
    timeout: 300,
  }
  match (self.moon_publish, self.npm_publish) {
    (true, true) => Both(npm_config)
    (true, false) => MooncakesOnly
    (false, true) => NpmOnly(npm_config)
    (false, false) => NoPublish
  }
}

///|
/// Get the npm build command as an argument array.
/// NOTE: Splits on spaces only. Quoted arguments with spaces (e.g. "npm run 'my script'")
/// are not supported — each space-separated token becomes a separate argument.
pub fn NpmConfig::build_args(self : NpmConfig) -> Array[String] {
  match self.build_command {
    Some(c) => c.split(" ").map(fn(s) { s.to_string() }).collect()
    None => ["moon", "build", "--target", "js", "--release"]
  }
}
