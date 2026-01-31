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

/// パスがディレクトリトラバーサルを含まないか検証
pub fn validate_path(path : String) -> Bool {
  // 空文字列と "." は許可
  if path.is_empty() || path == "." {
    return true
  }

  // ".." を含むパスは拒否
  if path.contains("..") {
    return false
  }

  // 絶対パス（/ で始まる）は拒否
  let chars = path.to_array()
  if chars.length() > 0 && chars[0] == '/' {
    return false
  }

  true
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
