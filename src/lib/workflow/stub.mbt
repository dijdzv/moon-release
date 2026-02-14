/// Stub for non-native targets
/// The workflow module requires native target

///|
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

///|
/// Workflow error — structured variants for different failure categories
pub(all) suberror WorkflowError {
  GitError(String)
  ConfigValidationError(String)
  PublishError(String)
  InputValidationError(String)
  ExternalCommandError(String)
  NoReleasableCommits(String)
  WorkflowError(String)
}

///|
/// Get a default hint for the error category (stub)
pub fn WorkflowError::hint(self : WorkflowError) -> String {
  match self {
    GitError(_) =>
      "Make sure you are in a git repository with at least one commit"
    ConfigValidationError(_) => "Check your release.json configuration"
    PublishError(_) => "Check publish credentials and network connection"
    InputValidationError(_) => "Check the input values and command arguments"
    ExternalCommandError(_) =>
      "Make sure required tools (git, gh, moon, npm) are installed"
    NoReleasableCommits(_) =>
      "Use Conventional Commits or --bump to force a version bump"
    WorkflowError(_) => ""
  }
}

///|
/// Version analysis result (stub)
pub struct VersionAnalysis {
  current_version : @semver.Version
  new_version : @semver.Version
  commits : Array[(@conventional.ConventionalCommit, String)]
  bump_type : @semver.BumpType
}

///|
/// Create ReleaseContext
pub fn ReleaseContext::new(
  config : @config.Config,
  repo : @git.Repository,
  current_version : @semver.Version,
  new_version : @semver.Version,
  commits : Array[(@conventional.ConventionalCommit, String)],
  dry_run? : Bool = false,
  verbose? : Bool = false,
  forced_bump? : @semver.BumpType? = None,
  bump_all? : Bool = false,
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

///|
/// update command (stub)
pub fn run_update(_ctx : ReleaseContext) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

///|
/// release-pr command (stub)
pub fn run_release_pr(
  _ctx : ReleaseContext,
  _github : @github.GitHubClient,
) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

///|
/// release command (stub)
pub fn run_release(
  _ctx : ReleaseContext,
  _github : @github.GitHubClient,
) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

///|
/// publish command (stub)
pub fn run_publish(_ctx : ReleaseContext) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

///|
/// Monorepo: update multiple packages (stub)
pub fn run_update_packages(
  _config : @config.Config,
  _repo : @git.Repository,
  _dry_run : Bool,
  _verbose : Bool,
  forced_bump? : @semver.BumpType? = None,
  bump_all? : Bool = false,
) -> Unit raise WorkflowError {
  ignore(forced_bump)
  ignore(bump_all)
  raise WorkflowError("Workflow requires native target")
}

///|
/// Monorepo: npm publish multiple packages (stub)
pub fn run_npm_publish_packages(
  _config : @config.Config,
  _dry_run : Bool,
  _verbose : Bool,
) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

///|
/// Monorepo: publish multiple packages (stub)
pub fn run_publish_packages(
  _config : @config.Config,
  _dry_run : Bool,
  _verbose : Bool,
) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
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
/// Validate publish configuration (stub)
pub fn validate_publish_config(
  _config : @config.Config,
  verbose? : Bool = false,
) -> Unit raise WorkflowError {
  ignore(verbose)
  raise WorkflowError("Workflow requires native target")
}

///|
/// Read version from package.json (stub)
pub fn get_package_json_version() -> @semver.Version? raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

///|
/// Get current version (stub)
pub fn get_current_version(
  _config : @config.Config,
) -> @semver.Version raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

///|
/// Pre-build JS target (stub)
pub fn pre_build_js(_ctx : ReleaseContext) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

///|
/// npm publish (stub)
pub fn run_npm_publish(_ctx : ReleaseContext) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

///|
/// Collect package release info (stub)
pub fn collect_package_release_info(
  _config : @config.Config,
  _repo : @git.Repository,
  _verbose : Bool,
  forced_bump? : @semver.BumpType? = None,
  bump_all? : Bool = false,
) -> Array[PackageReleaseInfo] raise WorkflowError {
  ignore(forced_bump)
  ignore(bump_all)
  raise WorkflowError("Workflow requires native target")
}

///|
/// Get registry version (stub)
pub fn get_registry_version(
  _package_name : String,
) -> @semver.Version? raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

///|
/// Check if should release (stub)
pub fn should_release(
  _local_version : @semver.Version,
  _package_name : String,
  _verbose : Bool,
) -> Bool raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

///|
/// Run semver check (stub)
pub fn run_semver_check(
  _repo : @git.Repository,
  _verbose : Bool,
  pr_title~ : String = "chore: release {{ version }}",
) -> @semver_check.CheckResult raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

///|
/// Get latest tag (stub)
pub fn get_latest_tag(_repo : @git.Repository) -> String? raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

///|
/// Get commits since last tag (stub)
pub fn get_commits_since_last_tag(
  _repo : @git.Repository,
  pr_title~ : String = "",
  max_commits? : UInt? = None,
) -> Array[(@conventional.ConventionalCommit, String)] raise WorkflowError {
  ignore(pr_title)
  ignore(max_commits)
  raise WorkflowError("Workflow requires native target")
}

///|
/// Check working directory (stub)
pub fn check_working_directory(
  _config : @config.Config,
  _repo : @git.Repository,
  verbose? : Bool = false,
) -> Unit raise WorkflowError {
  ignore(verbose)
  raise WorkflowError("Workflow requires native target")
}

///|
/// Get GitHub client (stub)
pub fn get_github_client() -> @github.GitHubClient raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

///|
/// Analyze version bump (stub)
pub fn analyze_version_bump(
  _config : @config.Config,
  _repo : @git.Repository,
  forced_bump? : @semver.BumpType? = None,
  max_commits? : UInt? = None,
  allow_empty_commits? : Bool = false,
  default_bump? : @semver.BumpType? = None,
) -> VersionAnalysis raise WorkflowError {
  ignore(forced_bump)
  ignore(max_commits)
  ignore(allow_empty_commits)
  ignore(default_bump)
  raise WorkflowError("Workflow requires native target")
}
