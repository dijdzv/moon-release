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

/// Package release info (for PR body generation)
pub struct PackageReleaseInfo {
  name : String
  old_version : @semver.Version
  new_version : @semver.Version
  commits : Array[(@conventional.ConventionalCommit, String)]
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
