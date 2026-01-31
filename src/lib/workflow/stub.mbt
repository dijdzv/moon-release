/// Stub for non-native targets
/// The workflow module requires native target

/// Release context
pub struct ReleaseContext {
  config : @config.Config
  repo : @git.Repository
  current_version : @semver.Version
  new_version : @semver.Version
  commits : Array[(@conventional.ConventionalCommit, String)]
  changelog_entry : String
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
  changelog_entry : String,
  dry_run~ : Bool = false,
  verbose~ : Bool = false
) -> ReleaseContext {
  ReleaseContext::{
    config,
    repo,
    current_version,
    new_version,
    commits,
    changelog_entry,
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
