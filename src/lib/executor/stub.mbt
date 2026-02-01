/// Stub for non-native targets
/// The executor module requires native target

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

/// Execute command and collect stdout (stub)
pub fn run_command(_cmd : Array[String]) -> CommandResult raise ExecutorError {
  raise ExecutorError("Executor requires native target")
}

/// Execute command without collecting output (stub)
pub fn run_command_simple(_cmd : Array[String]) -> Int raise ExecutorError {
  raise ExecutorError("Executor requires native target")
}

/// Execute git command (stub)
pub fn run_git(
  _repo : @git.Repository,
  _args : Array[String]
) -> CommandResult raise ExecutorError {
  raise ExecutorError("Executor requires native target")
}

/// Execute gh CLI command (stub)
pub fn run_gh(_args : Array[String]) -> CommandResult raise ExecutorError {
  raise ExecutorError("Executor requires native target")
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
