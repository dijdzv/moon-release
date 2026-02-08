/// Maximum timeout in seconds (~24 days) to prevent Int overflow when converting to milliseconds
/// 2147483 * 1000 = 2147483000 < Int.MAX (2147483647)
let max_timeout_seconds : UInt = 2147483U

/// C FFI: read environment variable into buffer (returns length, 0 if not found)
#borrow(name, buf)
extern "C" fn c_getenv(name : Bytes, buf : Bytes, buf_size : Int) -> Int = "moon_release_getenv"

/// Get environment variable value (portable, uses libc getenv)
/// Returns None if the variable is not set or empty.
/// TODO: Replace with moonbitlang/core/env API when getenv support is added upstream.
pub fn get_env_var(name : String) -> String? {
  // Encode name as null-terminated UTF-8 bytes
  let name_chars = name.to_array()
  let byte_arr : Array[Byte] = Array::new(capacity=name_chars.length() + 1)
  for c in name_chars {
    byte_arr.push(c.to_int().to_byte())
  }
  byte_arr.push(b'\x00')
  let name_bytes = Bytes::from_array(byte_arr[:])

  // Read value into buffer
  let buf = Bytes::new(4096)
  let len = c_getenv(name_bytes, buf, buf.length())
  if len == 0 {
    return None
  }

  // Decode UTF-8 bytes to string
  let sb = StringBuilder::new()
  let mut i = 0
  while i < len {
    let c = buf[i].to_int()
    if c == 0 {
      break
    } else if c < 0x80 {
      sb.write_char(c.unsafe_to_char())
      i += 1
    } else if c < 0xE0 {
      if i + 1 >= len { break }
      let c2 = ((c & 0x1F) << 6) | (buf[i + 1].to_int() & 0x3F)
      sb.write_char(c2.unsafe_to_char())
      i += 2
    } else if c < 0xF0 {
      if i + 2 >= len { break }
      let c2 = ((c & 0x0F) << 12) |
        ((buf[i + 1].to_int() & 0x3F) << 6) |
        (buf[i + 2].to_int() & 0x3F)
      sb.write_char(c2.unsafe_to_char())
      i += 3
    } else {
      if i + 3 >= len { break }
      let c2 = ((c & 0x07) << 18) |
        ((buf[i + 1].to_int() & 0x3F) << 12) |
        ((buf[i + 2].to_int() & 0x3F) << 6) |
        (buf[i + 3].to_int() & 0x3F)
      sb.write_char(c2.unsafe_to_char())
      i += 4
    }
  }
  let result = sb.to_string()
  if result.is_empty() { None } else { Some(result) }
}

/// Extract program and arguments from a command array
fn split_program_args(cmd : Array[String]) -> (String, Array[String]) {
  let program = cmd[0]
  let args : Array[String] = []
  for i = 1; i < cmd.length(); i = i + 1 {
    args.push(cmd[i])
  }
  (program, args)
}

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

  let (program, args) = split_program_args(cmd)
  let cmd_str = join_command_args(cmd)

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

  let (program, args) = split_program_args(cmd)
  let cmd_str = join_command_args(cmd)

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

/// Execute command in a specific directory and collect stdout
pub async fn run_command_in_dir(
  cmd : Array[String],
  cwd : String
) -> CommandResult raise ExecutorError {
  if cmd.is_empty() {
    raise ExecutorError("Cannot execute empty command")
  }

  let (program, args) = split_program_args(cmd)
  let cmd_str = join_command_args(cmd)

  // Execute command with cwd using try-catch-noraise pattern
  let (exit_code, stdout_data, stderr_data) = try @process.collect_output(
    program, args[:], cwd=cwd,
  ) catch {
    e => raise ExecutorError("Failed to execute '" + cmd_str + "' in '" + cwd + "': " + e.to_string())
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

/// Execute command in a specific directory with timeout (in seconds)
/// Returns None if timed out, Some(result) otherwise
pub async fn run_command_in_dir_with_timeout(
  cmd : Array[String],
  cwd : String,
  timeout_seconds : UInt
) -> CommandResult? raise ExecutorError {
  if cmd.is_empty() {
    raise ExecutorError("Cannot execute empty command")
  }

  let cmd_str = join_command_args(cmd)

  // Cap timeout to prevent Int overflow when converting to milliseconds
  let safe_timeout_seconds = if timeout_seconds > max_timeout_seconds {
    max_timeout_seconds
  } else {
    timeout_seconds
  }
  let timeout_ms = safe_timeout_seconds.reinterpret_as_int() * 1000

  // Execute with timeout using try-catch-noraise pattern
  try @async.with_timeout_opt(timeout_ms, async fn() { run_command_in_dir(cmd, cwd) }) catch {
    ExecutorError(_) as e => raise e
    e => raise ExecutorError("Failed to execute '" + cmd_str + "' in '" + cwd + "': " + e.to_string())
  } noraise { r => r }
}

/// Run command with timeout (in seconds)
/// Returns None if timed out, Some(result) otherwise
///
/// On timeout:
/// - Returns None immediately
/// - The child process receives a termination signal (SIGTERM on Unix)
/// - The process is cancelled via @async.with_timeout_opt which handles cleanup
///
/// Note: If the process ignores the termination signal, it may continue running
/// as an orphan process. For critical cleanup needs, consider using
/// @process.graceful_cancel or @process.hard_cancel directly.
pub async fn run_command_with_timeout(
  cmd : Array[String],
  timeout_seconds : UInt
) -> CommandResult? raise ExecutorError {
  if cmd.is_empty() {
    raise ExecutorError("Cannot execute empty command")
  }

  let cmd_str = join_command_args(cmd)

  // Cap timeout to prevent Int overflow when converting to milliseconds
  let safe_timeout_seconds = if timeout_seconds > max_timeout_seconds {
    max_timeout_seconds
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

