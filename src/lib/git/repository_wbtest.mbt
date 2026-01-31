test "parse commit log" {
  let output =
    "abc123|feat: add feature|John Doe|2024-01-15T10:00:00Z\ndef456|fix: correct bug|Jane Doe|2024-01-14T09:00:00Z"
  let commits = parse_commit_log(output)
  assert_eq(commits.length(), 2)
  assert_eq(commits[0].hash, "abc123")
  assert_eq(commits[0].message, "feat: add feature")
  assert_eq(commits[0].author, "John Doe")
  assert_eq(commits[1].hash, "def456")
  assert_eq(commits[1].message, "fix: correct bug")
}

test "parse commit log empty" {
  let output = ""
  let commits = parse_commit_log(output)
  assert_eq(commits.length(), 0)
}

test "parse conventional commits" {
  let output =
    "abc123|feat: add feature|John Doe|2024-01-15\ndef456|fix: correct bug|Jane Doe|2024-01-14\nghi789|not conventional|Bob|2024-01-13"
  let git_commits = parse_commit_log(output)
  let conventional = parse_conventional_commits(git_commits)
  // Only 2 are conventional (feat, fix)
  assert_eq(conventional.length(), 2)
}

test "repository open - valid path" {
  let repo = try { Repository::open("/path/to/repo") } catch { _ => fail("unexpected error") }
  assert_eq(repo.path, "/path/to/repo")
}

test "repository open - empty path normalizes to dot" {
  let repo = try { Repository::open("") } catch { _ => fail("unexpected error") }
  assert_eq(repo.path, ".")
}

test "repository open - rejects directory traversal" {
  try {
    let _ = Repository::open("../etc/passwd")
    fail("expected error")
  } catch {
    GitError(msg) => assert_true(msg.contains("directory traversal"))
    _ => fail("wrong error type")
  }
}

test "repository open - rejects traversal in middle of path" {
  try {
    let _ = Repository::open("/safe/path/../etc")
    fail("expected error")
  } catch {
    GitError(msg) => assert_true(msg.contains("directory traversal"))
    _ => fail("wrong error type")
  }
}

test "repository open_unchecked - allows any path" {
  let repo = Repository::open_unchecked("../dangerous/path")
  assert_eq(repo.path, "../dangerous/path")
}

test "repository current" {
  let repo = Repository::current()
  assert_eq(repo.path, ".")
}

test "get tags command" {
  let repo = Repository::open_unchecked("/repo")
  let cmd = repo.get_tags_command()
  assert_eq(cmd[0], "git")
  assert_eq(cmd[1], "-C")
  assert_eq(cmd[2], "/repo")
  assert_eq(cmd[3], "tag")
}

test "get commits since tag command" {
  let repo = Repository::open_unchecked("/repo")
  let cmd = repo.get_commits_since_tag_command("v1.0.0")
  assert_true(cmd.iter().any(fn(s) { s.contains("v1.0.0..HEAD") }))
}

test "create tag command" {
  let repo = Repository::open_unchecked("/repo")
  let cmd = repo.create_tag_command("v2.0.0", "Release 2.0.0")
  assert_true(cmd.iter().any(fn(s) { s == "v2.0.0" }))
  assert_true(cmd.iter().any(fn(s) { s == "Release 2.0.0" }))
}

test "push command with tags" {
  let repo = Repository::open_unchecked("/repo")
  let cmd = repo.push_command(true)
  assert_true(cmd.iter().any(fn(s) { s == "--follow-tags" }))
}

test "push command without tags" {
  let repo = Repository::open_unchecked("/repo")
  let cmd = repo.push_command(false)
  assert_false(cmd.iter().any(fn(s) { s == "--follow-tags" }))
}
