/// Release context
pub struct ReleaseContext {
  config : @config.Config
  repo : @git.Repository
  current_version : @semver.Version
  new_version : @semver.Version
  commits : Array[(@conventional.ConventionalCommit, String)]
  dry_run : Bool
  verbose : Bool
  forced_bump : @semver.BumpType?
  bump_all : Bool
}

/// Workflow error — structured variants for different failure categories
pub(all) suberror WorkflowError {
  /// Git operation failure (tag, push, checkout, commit, etc.)
  GitError(String)
  /// Configuration validation error
  ConfigValidationError(String)
  /// Publish operation failure (mooncakes, npm)
  PublishError(String)
  /// Input validation error (branch name, tag name, path, etc.)
  InputValidationError(String)
  /// External command execution failure
  ExternalCommandError(String)
  /// Generic workflow error (fallback for uncategorized errors)
  WorkflowError(String)
}

/// Convert WorkflowError to string
pub fn WorkflowError::to_string(self : WorkflowError) -> String {
  match self {
    GitError(msg) => msg
    ConfigValidationError(msg) => msg
    PublishError(msg) => msg
    InputValidationError(msg) => msg
    ExternalCommandError(msg) => msg
    WorkflowError(msg) => msg
  }
}

/// Get a default hint for the error category
pub fn WorkflowError::hint(self : WorkflowError) -> String {
  match self {
    GitError(_) => "Make sure you are in a git repository with at least one commit"
    ConfigValidationError(_) => "Check your release.json configuration"
    PublishError(_) => "Check publish credentials and network connection"
    InputValidationError(_) => "Check the input values and command arguments"
    ExternalCommandError(_) => "Make sure required tools (git, gh, moon, npm) are installed"
    WorkflowError(_) => ""
  }
}

/// Version analysis result (output of analyze_version_bump)
pub struct VersionAnalysis {
  current_version : @semver.Version
  new_version : @semver.Version
  commits : Array[(@conventional.ConventionalCommit, String)]
  bump_type : @semver.BumpType
}

/// Create ReleaseContext
pub fn ReleaseContext::new(
  config : @config.Config,
  repo : @git.Repository,
  current_version : @semver.Version,
  new_version : @semver.Version,
  commits : Array[(@conventional.ConventionalCommit, String)],
  dry_run~ : Bool = false,
  verbose~ : Bool = false,
  forced_bump~ : @semver.BumpType? = None,
  bump_all~ : Bool = false
) -> ReleaseContext {
  ReleaseContext::{
    config,
    repo,
    current_version,
    new_version,
    commits,
    dry_run,
    verbose,
    forced_bump,
    bump_all,
  }
}
