/// Command execution result
pub struct CommandResult {
  exit_code : Int
  stdout : String
  stderr : String
} derive(Show)

/// Executor error
pub suberror ExecutorError {
  ExecutorError(String)
}

/// Convert ExecutorError to string
pub fn ExecutorError::to_string(self : ExecutorError) -> String {
  match self {
    ExecutorError(msg) => msg
  }
}

/// Execute command and collect stdout
pub async fn run_command(cmd : Array[String]) -> CommandResult raise ExecutorError {
  if cmd.is_empty() {
    raise ExecutorError("Cannot execute empty command")
  }

  let program = cmd[0]
  let args : Array[String] = []
  for i = 1; i < cmd.length(); i = i + 1 {
    args.push(cmd[i])
  }

  let cmd_str = cmd.iter().fold(init="", fn(acc, s) {
    if acc.is_empty() { s } else { acc + " " + s }
  })

  // Execute command with try-catch-noraise pattern
  let (exit_code, stdout_data, stderr_data) = try @process.collect_output(program, args[:]) catch {
    e => raise ExecutorError("Failed to execute '" + cmd_str + "': " + e.to_string())
  } noraise { r => r }

  // Decode stdout with try-catch-noraise pattern
  let stdout_str = try stdout_data.text() catch {
    e => raise ExecutorError("Failed to decode stdout from '" + program + "': " + e.to_string())
  } noraise { r => r }

  // Decode stderr with try-catch-noraise pattern
  let stderr_str = try stderr_data.text() catch {
    e => raise ExecutorError("Failed to decode stderr from '" + program + "': " + e.to_string())
  } noraise { r => r }

  CommandResult::{ exit_code, stdout: stdout_str, stderr: stderr_str }
}

/// Execute command without collecting output
pub async fn run_command_simple(cmd : Array[String]) -> Int raise ExecutorError {
  if cmd.is_empty() {
    raise ExecutorError("Cannot execute empty command")
  }

  let program = cmd[0]
  let args : Array[String] = []
  for i = 1; i < cmd.length(); i = i + 1 {
    args.push(cmd[i])
  }

  let cmd_str = cmd.iter().fold(init="", fn(acc, s) {
    if acc.is_empty() { s } else { acc + " " + s }
  })

  // Execute command with try-catch-noraise pattern
  try @process.run(program, args[:]) catch {
    e => raise ExecutorError("Failed to execute '" + cmd_str + "': " + e.to_string())
  } noraise { r => r }
}

/// Execute git command
pub async fn run_git(
  repo : @git.Repository,
  args : Array[String]
) -> CommandResult raise ExecutorError {
  let cmd = repo_git_command(repo, args)
  run_command(cmd)
}

/// Build git command array
fn repo_git_command(repo : @git.Repository, args : Array[String]) -> Array[String] {
  let cmd : Array[String] = ["git", "-C", repo.path]
  for arg in args {
    cmd.push(arg)
  }
  cmd
}

/// Execute gh CLI command
pub async fn run_gh(args : Array[String]) -> CommandResult raise ExecutorError {
  let cmd : Array[String] = ["gh"]
  for arg in args {
    cmd.push(arg)
  }
  run_command(cmd)
}

/// Check if command succeeded
pub fn CommandResult::is_success(self : CommandResult) -> Bool {
  self.exit_code == 0
}

/// Create a failed result
pub fn CommandResult::failed(stderr : String) -> CommandResult {
  CommandResult::{ exit_code: 1, stdout: "", stderr }
}

/// Return trimmed stdout
pub fn CommandResult::stdout_trimmed(self : CommandResult) -> String {
  self.stdout.trim().to_string()
}

/// Validate result and raise ExecutorError on failure
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

/// Run command with timeout (in seconds)
/// Returns None if timed out, Some(result) otherwise
pub async fn run_command_with_timeout(
  cmd : Array[String],
  timeout_seconds : UInt
) -> CommandResult? raise ExecutorError {
  if cmd.is_empty() {
    raise ExecutorError("Cannot execute empty command")
  }

  let cmd_str = cmd.iter().fold(init="", fn(acc, s) {
    if acc.is_empty() { s } else { acc + " " + s }
  })

  // Cap timeout at ~24 days (2147483 seconds) to prevent Int overflow when converting to ms
  let safe_timeout_seconds = if timeout_seconds > 2147483U {
    2147483U
  } else {
    timeout_seconds
  }
  let timeout_ms = safe_timeout_seconds.reinterpret_as_int() * 1000

  // Execute with timeout using try-catch-noraise pattern
  try @async.with_timeout_opt(timeout_ms, async fn() { run_command(cmd) }) catch {
    ExecutorError(_) as e => raise e
    e => raise ExecutorError("Failed to execute '" + cmd_str + "': " + e.to_string())
  } noraise { r => r }
}
