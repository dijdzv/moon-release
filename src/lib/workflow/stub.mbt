/// Stub for non-native targets
/// The workflow module requires native target

/// リリースコンテキスト
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

/// ワークフローエラー
pub suberror WorkflowError {
  WorkflowError(String)
}

/// ReleaseContext を作成
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

/// update コマンド (stub)
pub fn run_update(_ctx : ReleaseContext) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

/// release-pr コマンド (stub)
pub fn run_release_pr(
  _ctx : ReleaseContext,
  _github : @github.GitHubClient
) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

/// release コマンド (stub)
pub fn run_release(
  _ctx : ReleaseContext,
  _github : @github.GitHubClient
) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

/// publish コマンド (stub)
pub fn run_publish(_ctx : ReleaseContext) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

/// モノレポ用: 複数パッケージの更新 (stub)
pub fn run_update_packages(
  _config : @config.Config,
  _repo : @git.Repository,
  _dry_run : Bool,
  _verbose : Bool
) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}

/// モノレポ用: 複数パッケージの公開 (stub)
pub fn run_publish_packages(
  _config : @config.Config,
  _dry_run : Bool,
  _verbose : Bool
) -> Unit raise WorkflowError {
  raise WorkflowError("Workflow requires native target")
}
