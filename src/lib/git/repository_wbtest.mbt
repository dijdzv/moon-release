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

test "repository open" {
  let repo = Repository::open("/path/to/repo")
  assert_eq(repo.path, "/path/to/repo")
}

test "repository current" {
  let repo = Repository::current()
  assert_eq(repo.path, ".")
}

test "get tags command" {
  let repo = Repository::open("/repo")
  let cmd = repo.get_tags_command()
  assert_eq(cmd[0], "git")
  assert_eq(cmd[1], "-C")
  assert_eq(cmd[2], "/repo")
  assert_eq(cmd[3], "tag")
}

test "get commits since tag command" {
  let repo = Repository::open("/repo")
  let cmd = repo.get_commits_since_tag_command("v1.0.0")
  assert_true(cmd.iter().any(fn(s) { s.contains("v1.0.0..HEAD") }))
}

test "create tag command" {
  let repo = Repository::open("/repo")
  let cmd = repo.create_tag_command("v2.0.0", "Release 2.0.0")
  assert_true(cmd.iter().any(fn(s) { s == "v2.0.0" }))
  assert_true(cmd.iter().any(fn(s) { s == "Release 2.0.0" }))
}

test "push command with tags" {
  let repo = Repository::open("/repo")
  let cmd = repo.push_command(true)
  assert_true(cmd.iter().any(fn(s) { s == "--follow-tags" }))
}

test "push command without tags" {
  let repo = Repository::open("/repo")
  let cmd = repo.push_command(false)
  assert_false(cmd.iter().any(fn(s) { s == "--follow-tags" }))
}
