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

/// Execute command without collecting output
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
    raise ExecutorError("Command is empty")
  }

  let timeout_ms = timeout_seconds.reinterpret_as_int() * 1000

  try {
    @async.with_timeout_opt(timeout_ms, async fn() { run_command(cmd) })
  } catch {
    ExecutorError(_) as e => raise e
    e => raise ExecutorError("Command failed: " + e.to_string())
  }
}
