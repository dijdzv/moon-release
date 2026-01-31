/// リリースコンテキスト
pub struct ReleaseContext {
  config : @config.Config
  repo : @git.Repository
  current_version : @semver.Version
  new_version : @semver.Version
  commits : Array[(@conventional.ConventionalCommit, String)]
  dry_run : Bool
  verbose : Bool
}

/// ワークフローエラー
pub(all) suberror WorkflowError {
  WorkflowError(String)
}

/// WorkflowError を文字列に変換
pub fn WorkflowError::to_string(self : WorkflowError) -> String {
  match self {
    WorkflowError(msg) => msg
  }
}

/// ReleaseContext を作成
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
