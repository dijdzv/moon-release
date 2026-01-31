/// Stub for non-native targets
/// The executor module requires native target

/// コマンド実行結果
pub struct CommandResult {
  exit_code : Int
  stdout : String
  stderr : String
} derive(Show)

/// Executor エラー
pub suberror ExecutorError {
  ExecutorError(String)
}

/// コマンドを実行し、stdout を収集する (stub)
pub fn run_command(_cmd : Array[String]) -> CommandResult raise ExecutorError {
  raise ExecutorError("Executor requires native target")
}

/// コマンドを実行（出力を収集しない）(stub)
pub fn run_command_simple(_cmd : Array[String]) -> Int raise ExecutorError {
  raise ExecutorError("Executor requires native target")
}

/// Git コマンドを実行 (stub)
pub fn run_git(
  _repo : @git.Repository,
  _args : Array[String]
) -> CommandResult raise ExecutorError {
  raise ExecutorError("Executor requires native target")
}

/// gh CLI コマンドを実行 (stub)
pub fn run_gh(_args : Array[String]) -> CommandResult raise ExecutorError {
  raise ExecutorError("Executor requires native target")
}

/// コマンドが成功したかチェック
pub fn CommandResult::is_success(self : CommandResult) -> Bool {
  self.exit_code == 0
}

/// stdout をトリムして返す
pub fn CommandResult::stdout_trimmed(self : CommandResult) -> String {
  self.stdout.trim().to_string()
}

/// 結果を検証し、失敗なら ExecutorError を発生させる
pub fn CommandResult::check(
  self : CommandResult,
  context : String
) -> Unit raise ExecutorError {
  if not(self.is_success()) {
    let msg = if self.stderr.is_empty() {
      "\{context}: exit code \{self.exit_code}"
    } else {
      "\{context}: \{self.stderr}"
    }
    raise ExecutorError(msg)
  }
}
