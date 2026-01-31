/// コマンド実行結果
pub struct CommandResult {
  pub exit_code : Int
  pub stdout : String
  pub stderr : String
} derive(Show)

/// Executor エラー
pub suberror ExecutorError {
  ExecutorError(String)
}

/// ExecutorError を文字列に変換
pub fn ExecutorError::to_string(self : ExecutorError) -> String {
  match self {
    ExecutorError(msg) => msg
  }
}

/// コマンドを実行し、stdout を収集する
pub async fn run_command(cmd : Array[String]) -> CommandResult raise ExecutorError {
  if cmd.is_empty() {
    raise ExecutorError("Command is empty")
  }

  let program = cmd[0]
  let args : Array[String] = []
  for i = 1; i < cmd.length(); i = i + 1 {
    args.push(cmd[i])
  }

  let (exit_code, stdout_data, stderr_data) = try {
    @process.collect_output(program, args[:])
  } catch {
    e => raise ExecutorError("Failed to run command: " + e.to_string())
  }

  let stdout_str = try {
    stdout_data.text()
  } catch {
    e => raise ExecutorError("Failed to decode stdout: " + e.to_string())
  }

  let stderr_str = try {
    stderr_data.text()
  } catch {
    e => raise ExecutorError("Failed to decode stderr: " + e.to_string())
  }

  CommandResult::{ exit_code, stdout: stdout_str, stderr: stderr_str }
}

/// コマンドを実行（出力を収集しない）
pub async fn run_command_simple(cmd : Array[String]) -> Int raise ExecutorError {
  if cmd.is_empty() {
    raise ExecutorError("Command is empty")
  }

  let program = cmd[0]
  let args : Array[String] = []
  for i = 1; i < cmd.length(); i = i + 1 {
    args.push(cmd[i])
  }

  try {
    @process.run(program, args[:])
  } catch {
    e => raise ExecutorError("Failed to run command: " + e.to_string())
  }
}

/// Git コマンドを実行
pub async fn run_git(
  repo : @git.Repository,
  args : Array[String]
) -> CommandResult raise ExecutorError {
  let cmd = repo_git_command(repo, args)
  run_command(cmd)
}

/// Git コマンドを構築
fn repo_git_command(repo : @git.Repository, args : Array[String]) -> Array[String] {
  let cmd : Array[String] = ["git", "-C", repo.path]
  for arg in args {
    cmd.push(arg)
  }
  cmd
}

/// gh CLI コマンドを実行
pub async fn run_gh(args : Array[String]) -> CommandResult raise ExecutorError {
  let cmd : Array[String] = ["gh"]
  for arg in args {
    cmd.push(arg)
  }
  run_command(cmd)
}

/// コマンドが成功したかチェック
pub fn CommandResult::is_success(self : CommandResult) -> Bool {
  self.exit_code == 0
}

/// 失敗した結果を作成
pub fn CommandResult::failed(stderr : String) -> CommandResult {
  CommandResult::{ exit_code: 1, stdout: "", stderr }
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
