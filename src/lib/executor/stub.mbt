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

/// Execute command in a specific directory (stub)
pub fn run_command_in_dir(
  _cmd : Array[String],
  _cwd : String
) -> CommandResult raise ExecutorError {
  raise ExecutorError("Executor requires native target")
}

/// Execute command in a specific directory with timeout (stub)
pub fn run_command_in_dir_with_timeout(
  _cmd : Array[String],
  _cwd : String,
  _timeout_seconds : UInt
) -> CommandResult? raise ExecutorError {
  raise ExecutorError("Executor requires native target")
}

/// Execute command with timeout (stub)
pub fn run_command_with_timeout(
  _cmd : Array[String],
  _timeout_seconds : UInt
) -> CommandResult? raise ExecutorError {
  raise ExecutorError("Executor requires native target")
}

/// Get environment variable value (stub)
pub fn get_env_var(_name : String) -> String? {
  None
}

