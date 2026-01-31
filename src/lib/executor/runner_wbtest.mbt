// CommandResult tests

test "CommandResult::is_success - exit code 0" {
  let result = CommandResult::{ exit_code: 0, stdout: "output", stderr: "" }
  assert_true(result.is_success())
}

test "CommandResult::is_success - exit code 1" {
  let result = CommandResult::{ exit_code: 1, stdout: "", stderr: "error" }
  assert_false(result.is_success())
}

test "CommandResult::is_success - exit code 127" {
  let result = CommandResult::{ exit_code: 127, stdout: "", stderr: "command not found" }
  assert_false(result.is_success())
}

test "CommandResult::failed - creates failed result" {
  let result = CommandResult::failed("some error")
  assert_eq(result.exit_code, 1)
  assert_eq(result.stdout, "")
  assert_eq(result.stderr, "some error")
  assert_false(result.is_success())
}

test "CommandResult::failed - empty stderr" {
  let result = CommandResult::failed("")
  assert_eq(result.exit_code, 1)
  assert_eq(result.stderr, "")
}

test "CommandResult::stdout_trimmed - trims whitespace" {
  let result = CommandResult::{ exit_code: 0, stdout: "  hello world  \n", stderr: "" }
  assert_eq(result.stdout_trimmed(), "hello world")
}

test "CommandResult::stdout_trimmed - empty stdout" {
  let result = CommandResult::{ exit_code: 0, stdout: "", stderr: "" }
  assert_eq(result.stdout_trimmed(), "")
}

test "CommandResult::stdout_trimmed - only whitespace" {
  let result = CommandResult::{ exit_code: 0, stdout: "   \n\t  ", stderr: "" }
  assert_eq(result.stdout_trimmed(), "")
}

test "CommandResult::check - success does not raise" {
  let result = CommandResult::{ exit_code: 0, stdout: "ok", stderr: "" }
  // Should not raise
  result.check("test context")
}

test "CommandResult::check - failure raises with stderr" {
  let result = CommandResult::{ exit_code: 1, stdout: "", stderr: "permission denied" }
  let raised = try {
    result.check("git push")
    false
  } catch {
    ExecutorError(msg) => msg.contains("permission denied") && msg.contains("git push")
  }
  assert_true(raised)
}

test "CommandResult::check - failure raises with exit code when no stderr" {
  let result = CommandResult::{ exit_code: 42, stdout: "", stderr: "" }
  let raised = try {
    result.check("some command")
    false
  } catch {
    ExecutorError(msg) => msg.contains("exit code 42") && msg.contains("some command")
  }
  assert_true(raised)
}

// repo_git_command tests (internal function)
test "repo_git_command - builds correct command" {
  let repo = @git.Repository::open("/path/to/repo")
  let cmd = repo_git_command(repo, ["status", "-s"])
  assert_eq(cmd.length(), 5)
  assert_eq(cmd[0], "git")
  assert_eq(cmd[1], "-C")
  assert_eq(cmd[2], "/path/to/repo")
  assert_eq(cmd[3], "status")
  assert_eq(cmd[4], "-s")
}

test "repo_git_command - empty args" {
  let repo = @git.Repository::current()
  let cmd = repo_git_command(repo, [])
  assert_eq(cmd.length(), 3)
  assert_eq(cmd[0], "git")
  assert_eq(cmd[1], "-C")
  assert_eq(cmd[2], ".")
}
