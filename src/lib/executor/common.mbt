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

/// Join command array into a display string for error messages
pub fn join_command_args(cmd : Array[String]) -> String {
  cmd.iter().fold(init="", fn(acc, s) {
    if acc.is_empty() { s } else { acc + " " + s }
  })
}
