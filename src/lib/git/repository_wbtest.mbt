///|
test "parse commit log" {
  let output = "abc123\u001efeat: add feature\u001eJohn Doe\u001e2024-01-15T10:00:00Z\ndef456\u001efix: correct bug\u001eJane Doe\u001e2024-01-14T09:00:00Z"
  let commits = parse_commit_log(output)
  assert_eq(commits.length(), 2)
  assert_eq(commits[0].hash, "abc123")
  assert_eq(commits[0].message, "feat: add feature")
  assert_eq(commits[0].author, "John Doe")
  assert_eq(commits[1].hash, "def456")
  assert_eq(commits[1].message, "fix: correct bug")
}

///|
test "parse commit log empty" {
  let output = ""
  let commits = parse_commit_log(output)
  assert_eq(commits.length(), 0)
}

///|
test "parse commit log with pipe in message" {
  // Subject contains | character which should be preserved (using \x1E as separator)
  let output = "abc123\u001efeat: handle foo | bar | baz\u001eJohn Doe\u001e2024-01-15T10:00:00Z"
  let commits = parse_commit_log(output)
  assert_eq(commits.length(), 1)
  assert_eq(commits[0].hash, "abc123")
  assert_eq(commits[0].message, "feat: handle foo | bar | baz")
  assert_eq(commits[0].author, "John Doe")
  assert_eq(commits[0].date, "2024-01-15T10:00:00Z")
}

///|
test "parse conventional commits" {
  let output = "abc123\u001efeat: add feature\u001eJohn Doe\u001e2024-01-15\ndef456\u001efix: correct bug\u001eJane Doe\u001e2024-01-14\nghi789\u001enot conventional\u001eBob\u001e2024-01-13"
  let git_commits = parse_commit_log(output)
  let conventional = parse_conventional_commits(git_commits)
  // Only 2 are conventional (feat, fix)
  assert_eq(conventional.length(), 2)
}

///|
test "repository open - valid path" {
  let repo = Repository::open("/path/to/repo") catch {
    _ => fail("unexpected error")
  }
  assert_eq(repo.path, "/path/to/repo")
}

///|
test "repository open - empty path normalizes to dot" {
  let repo = Repository::open("") catch { _ => fail("unexpected error") }
  assert_eq(repo.path, ".")
}

///|
test "repository open - rejects directory traversal" {
  try {
    let _ = Repository::open("../etc/passwd")
    fail("expected error")
  } catch {
    GitError(msg) => assert_true(msg.contains("directory traversal"))
    _ => fail("wrong error type")
  }
}

///|
test "repository open - rejects traversal in middle of path" {
  try {
    let _ = Repository::open("/safe/path/../etc")
    fail("expected error")
  } catch {
    GitError(msg) => assert_true(msg.contains("directory traversal"))
    _ => fail("wrong error type")
  }
}

///|
test "repository open_unchecked - allows any path" {
  let repo = Repository::open_unchecked("../dangerous/path")
  assert_eq(repo.path, "../dangerous/path")
}

///|
test "repository current" {
  let repo = Repository::current()
  assert_eq(repo.path, ".")
}

///|
test "get tags command" {
  let repo = Repository::open_unchecked("/repo")
  let cmd = repo.get_tags_command()
  assert_eq(cmd[0], "git")
  assert_eq(cmd[1], "-C")
  assert_eq(cmd[2], "/repo")
  assert_eq(cmd[3], "tag")
}

///|
test "get commits since tag command" {
  let repo = Repository::open_unchecked("/repo")
  let cmd = repo.get_commits_since_tag_command("v1.0.0") catch {
    _ => fail("unexpected error")
  }
  assert_true(cmd.iter().any(fn(s) { s.contains("v1.0.0..HEAD") }))
}

///|
test "get commits since tag command - rejects empty tag" {
  let repo = Repository::open_unchecked("/repo")
  try {
    let _ = repo.get_commits_since_tag_command("")
    fail("expected error")
  } catch {
    GitError(msg) => assert_true(msg.contains("Invalid git ref"))
    _ => fail("wrong error type")
  }
}

///|
test "get commits since tag command - rejects shell metacharacters" {
  let repo = Repository::open_unchecked("/repo")
  try {
    let _ = repo.get_commits_since_tag_command("v1.0.0; rm -rf /")
    fail("expected error")
  } catch {
    GitError(msg) => assert_true(msg.contains("Invalid git ref"))
    _ => fail("wrong error type")
  }
}

///|
test "get commits since tag command - rejects option-like arguments" {
  let repo = Repository::open_unchecked("/repo")
  try {
    let _ = repo.get_commits_since_tag_command("--exec=malicious")
    fail("expected error")
  } catch {
    GitError(msg) => assert_true(msg.contains("Invalid git ref"))
    _ => fail("wrong error type")
  }
}

///|
test "get commits command - rejects invalid refs" {
  let repo = Repository::open_unchecked("/repo")
  try {
    let _ = repo.get_commits_command("valid", "bad|ref")
    fail("expected error")
  } catch {
    GitError(msg) => assert_true(msg.contains("Invalid git ref"))
    _ => fail("wrong error type")
  }
}

///|
test "create tag command" {
  let repo = Repository::open_unchecked("/repo")
  let cmd = repo.create_tag_command("v2.0.0", "Release 2.0.0")
  assert_true(cmd.iter().any(fn(s) { s == "v2.0.0" }))
  assert_true(cmd.iter().any(fn(s) { s == "Release 2.0.0" }))
}

///|
test "push command with tags" {
  let repo = Repository::open_unchecked("/repo")
  let cmd = repo.push_command(true)
  assert_true(cmd.iter().any(fn(s) { s == "--follow-tags" }))
}

///|
test "push command without tags" {
  let repo = Repository::open_unchecked("/repo")
  let cmd = repo.push_command(false)
  assert_false(cmd.iter().any(fn(s) { s == "--follow-tags" }))
}

// parse_commit_log edge case tests

///|
test "parse_commit_log - empty subject (4 parts)" {
  let output = "abc123\u001e\u001eJohn Doe\u001e2024-01-15T10:00:00Z"
  let commits = parse_commit_log(output)
  assert_eq(commits.length(), 1)
  assert_eq(commits[0].hash, "abc123")
  assert_eq(commits[0].message, "")
  assert_eq(commits[0].author, "John Doe")
}

// 3 parts: parts[0]=hash, parts[1]=author, parts[2]=date, message is empty string
// This matches the edge case in parse_commit_log where subject is empty

///|
test "parse_commit_log - 3 parts maps to (hash, empty_msg, author, date)" {
  let output = "abc123\u001efeat: add feature\u001eJohn Doe"
  let commits = parse_commit_log(output)
  assert_eq(commits.length(), 1)
  assert_eq(commits[0].hash, "abc123")
  assert_eq(commits[0].message, "")
  assert_eq(commits[0].author, "feat: add feature")
  assert_eq(commits[0].date, "John Doe")
}

///|
test "parse_commit_log - fewer than 3 parts skipped" {
  let output = "abc123\u001eonly-two-parts"
  let commits = parse_commit_log(output)
  assert_eq(commits.length(), 0)
}

///|
test "parse_commit_log - multibyte characters in message" {
  let output = "abc123\u001e日本語のコミットメッセージ\u001e太郎\u001e2024-01-15T10:00:00Z"
  let commits = parse_commit_log(output)
  assert_eq(commits.length(), 1)
  assert_eq(commits[0].message, "日本語のコミットメッセージ")
  assert_eq(commits[0].author, "太郎")
}

///|
test "parse_commit_log - mixed valid and invalid lines" {
  let output = "abc123\u001efeat: valid\u001eAuthor\u001e2024-01-15T10:00:00Z\nbad-line\nghi789\u001efix: another\u001eAuthor2\u001e2024-01-16T10:00:00Z"
  let commits = parse_commit_log(output)
  assert_eq(commits.length(), 2)
  assert_eq(commits[0].message, "feat: valid")
  assert_eq(commits[1].message, "fix: another")
}

// validate_ref_param boundary tests (via get_commits_since_tag_command)

///|
test "get_commits_since_tag_command - rejects newline in tag" {
  let repo = Repository::open_unchecked("/repo")
  try {
    let _ = repo.get_commits_since_tag_command("v1.0.0\ninjection")
    fail("expected error")
  } catch {
    GitError(msg) => assert_true(msg.contains("Invalid git ref"))
    _ => fail("wrong error type")
  }
}

///|
test "get_commits_since_tag_command - rejects double dots" {
  let repo = Repository::open_unchecked("/repo")
  try {
    let _ = repo.get_commits_since_tag_command("v1.0.0..v2.0.0")
    fail("expected error")
  } catch {
    GitError(msg) => assert_true(msg.contains("Invalid git ref"))
    _ => fail("wrong error type")
  }
}

// create_tag_command security separator

///|
test "create_tag_command - includes -- separator" {
  let repo = Repository::open_unchecked("/repo")
  let cmd = repo.create_tag_command("v2.0.0", "Release 2.0.0")
  assert_true(cmd.iter().any(fn(s) { s == "--" }))
}
