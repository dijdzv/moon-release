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

/// Workflow error
pub(all) suberror WorkflowError {
  WorkflowError(String)
}

/// Convert WorkflowError to string
pub fn WorkflowError::to_string(self : WorkflowError) -> String {
  match self {
    WorkflowError(msg) => msg
  }
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
