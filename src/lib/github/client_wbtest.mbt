test "client new" {
  let client = GitHubClient::new("owner", "repo")
  assert_eq(client.owner, "owner")
  assert_eq(client.repo, "repo")
}

test "repo string" {
  let client = GitHubClient::new("moonbitlang", "core")
  assert_eq(client.repo_string(), "moonbitlang/core")
}

test "create release command" {
  let client = GitHubClient::new("owner", "repo")
  let cmd = client.create_release_command("v1.0.0", "Release 1.0.0", "Notes here")
  assert_true(cmd.iter().any(fn(s) { s == "gh" }))
  assert_true(cmd.iter().any(fn(s) { s == "release" }))
  assert_true(cmd.iter().any(fn(s) { s == "create" }))
  assert_true(cmd.iter().any(fn(s) { s == "v1.0.0" }))
  assert_true(cmd.iter().any(fn(s) { s == "owner/repo" }))
}

test "create release command with draft" {
  let client = GitHubClient::new("owner", "repo")
  let cmd = client.create_release_command(
    "v1.0.0",
    "Release 1.0.0",
    "Notes",
    draft=true,
  )
  assert_true(cmd.iter().any(fn(s) { s == "--draft" }))
}

test "create release command with prerelease" {
  let client = GitHubClient::new("owner", "repo")
  let cmd = client.create_release_command(
    "v1.0.0-beta",
    "Beta",
    "Notes",
    prerelease=true,
  )
  assert_true(cmd.iter().any(fn(s) { s == "--prerelease" }))
}

test "create release command with latest true" {
  let client = GitHubClient::new("owner", "repo")
  let cmd = client.create_release_command(
    "v1.0.0",
    "Release",
    "Notes",
    latest=true,
  )
  assert_true(cmd.iter().any(fn(s) { s == "--latest" }))
  assert_false(cmd.iter().any(fn(s) { s == "--latest=false" }))
}

test "create release command with latest false" {
  let client = GitHubClient::new("owner", "repo")
  let cmd = client.create_release_command(
    "v1.0.0",
    "Release",
    "Notes",
    latest=false,
  )
  assert_true(cmd.iter().any(fn(s) { s == "--latest=false" }))
}

test "get release command" {
  let client = GitHubClient::new("owner", "repo")
  let cmd = client.get_release_command("v1.0.0")
  assert_true(cmd.iter().any(fn(s) { s == "view" }))
  assert_true(cmd.iter().any(fn(s) { s == "v1.0.0" }))
  assert_true(cmd.iter().any(fn(s) { s == "--json" }))
}

test "get latest release command" {
  let client = GitHubClient::new("owner", "repo")
  let cmd = client.get_latest_release_command()
  assert_true(cmd.iter().any(fn(s) { s == "list" }))
  assert_true(cmd.iter().any(fn(s) { s == "--limit" }))
  assert_true(cmd.iter().any(fn(s) { s == "1" }))
}

test "create pull request command" {
  let client = GitHubClient::new("owner", "repo")
  let cmd = client.create_pull_request_command(
    "Fix bug",
    "Description",
    "feature-branch",
    "main",
  )
  assert_true(cmd.iter().any(fn(s) { s == "pr" }))
  assert_true(cmd.iter().any(fn(s) { s == "create" }))
  assert_true(cmd.iter().any(fn(s) { s == "Fix bug" }))
  assert_true(cmd.iter().any(fn(s) { s == "feature-branch" }))
  assert_true(cmd.iter().any(fn(s) { s == "main" }))
}

test "create pull request command with draft" {
  let client = GitHubClient::new("owner", "repo")
  let cmd = client.create_pull_request_command(
    "WIP",
    "Work in progress",
    "wip-branch",
    "main",
    draft=true,
  )
  assert_true(cmd.iter().any(fn(s) { s == "--draft" }))
}

test "get pull request command" {
  let client = GitHubClient::new("owner", "repo")
  let cmd = client.get_pull_request_command(123U)
  assert_true(cmd.iter().any(fn(s) { s == "view" }))
  assert_true(cmd.iter().any(fn(s) { s == "123" }))
}

test "list pull requests command" {
  let client = GitHubClient::new("owner", "repo")
  let cmd = client.list_pull_requests_command()
  assert_true(cmd.iter().any(fn(s) { s == "list" }))
  assert_true(cmd.iter().any(fn(s) { s == "--state" }))
  assert_true(cmd.iter().any(fn(s) { s == "open" }))
}

test "parse release json" {
  let json =
    #|{
    #|  "tagName": "v1.0.0",
    #|  "name": "Release 1.0.0",
    #|  "body": "Release notes",
    #|  "isDraft": false,
    #|  "isPrerelease": false
    #|}
  let release = try {
    parse_release_json(json)
  } catch {
    _ => fail("Unexpected error")
  }
  assert_eq(release.tag_name, "v1.0.0")
  assert_eq(release.name, "Release 1.0.0")
  assert_eq(release.body, "Release notes")
  assert_eq(release.draft, false)
  assert_eq(release.prerelease, false)
}

test "parse release json with draft" {
  let json =
    #|{
    #|  "tagName": "v2.0.0",
    #|  "name": "Draft release",
    #|  "body": "",
    #|  "isDraft": true,
    #|  "isPrerelease": false
    #|}
  let release = try {
    parse_release_json(json)
  } catch {
    _ => fail("Unexpected error")
  }
  assert_eq(release.draft, true)
}

test "parse release list json" {
  let json =
    #|[
    #|  {"tagName": "v2.0.0", "name": "Release 2", "isDraft": false, "isPrerelease": false},
    #|  {"tagName": "v1.0.0", "name": "Release 1", "isDraft": false, "isPrerelease": true}
    #|]
  let releases = try {
    parse_release_list_json(json)
  } catch {
    _ => fail("Unexpected error")
  }
  assert_eq(releases.length(), 2)
  assert_eq(releases[0].tag_name, "v2.0.0")
  assert_eq(releases[1].tag_name, "v1.0.0")
  assert_eq(releases[1].prerelease, true)
}

test "parse pull request json" {
  let json =
    #|{
    #|  "number": 42,
    #|  "title": "Add feature",
    #|  "body": "This PR adds a feature",
    #|  "headRefName": "feature-branch",
    #|  "baseRefName": "main"
    #|}
  let pr = try {
    parse_pull_request_json(json)
  } catch {
    _ => fail("Unexpected error")
  }
  assert_eq(pr.number, 42U)
  assert_eq(pr.title, "Add feature")
  assert_eq(pr.body, "This PR adds a feature")
  assert_eq(pr.head, "feature-branch")
  assert_eq(pr.base, "main")
}

test "parse pull request list json" {
  let json =
    #|[
    #|  {"number": 10, "title": "PR 10", "headRefName": "branch-10", "baseRefName": "main"},
    #|  {"number": 9, "title": "PR 9", "headRefName": "branch-9", "baseRefName": "develop"}
    #|]
  let prs = try {
    parse_pull_request_list_json(json)
  } catch {
    _ => fail("Unexpected error")
  }
  assert_eq(prs.length(), 2)
  assert_eq(prs[0].number, 10U)
  assert_eq(prs[1].number, 9U)
  assert_eq(prs[1].base, "develop")
}

test "parse invalid release json" {
  let json = "not json"
  try {
    let _ = parse_release_json(json)
    fail("Expected error")
  } catch {
    GitHubError(_) => ()
    _ => fail("Wrong error type")
  }
}

test "parse invalid pr json" {
  let json = "[]"
  try {
    let _ = parse_pull_request_json(json)
    fail("Expected error")
  } catch {
    GitHubError(_) => ()
    _ => fail("Wrong error type")
  }
}

test "client new - rejects empty owner" {
  try {
    let _ = GitHubClient::new("", "repo")
    fail("expected error")
  } catch {
    GitHubError(msg) => assert_true(msg.contains("Invalid GitHub owner"))
    _ => fail("wrong error type")
  }
}

test "client new - rejects empty repo" {
  try {
    let _ = GitHubClient::new("owner", "")
    fail("expected error")
  } catch {
    GitHubError(msg) => assert_true(msg.contains("Invalid GitHub repo"))
    _ => fail("wrong error type")
  }
}

test "client new - rejects owner with slash" {
  try {
    let _ = GitHubClient::new("owner/evil", "repo")
    fail("expected error")
  } catch {
    GitHubError(msg) => assert_true(msg.contains("Invalid GitHub owner"))
    _ => fail("wrong error type")
  }
}

test "client new - rejects repo with space" {
  try {
    let _ = GitHubClient::new("owner", "my repo")
    fail("expected error")
  } catch {
    GitHubError(msg) => assert_true(msg.contains("Invalid GitHub repo"))
    _ => fail("wrong error type")
  }
}

test "parse release json - missing tagName raises error" {
  let json =
    #|{
    #|  "name": "Release 1.0.0",
    #|  "body": "Notes",
    #|  "isDraft": false,
    #|  "isPrerelease": false
    #|}
  try {
    let _ = parse_release_json(json)
    fail("expected error")
  } catch {
    GitHubError(msg) => assert_true(msg.contains("tagName"))
    _ => fail("wrong error type")
  }
}

test "parse release json - null tagName raises error" {
  let json =
    #|{
    #|  "tagName": null,
    #|  "name": "Release 1.0.0",
    #|  "body": "Notes",
    #|  "isDraft": false,
    #|  "isPrerelease": false
    #|}
  try {
    let _ = parse_release_json(json)
    fail("expected error")
  } catch {
    GitHubError(msg) => assert_true(msg.contains("tagName"))
    _ => fail("wrong error type")
  }
}

// create_pull_request_command with labels

test "create_pull_request_command - with labels" {
  let client = try { GitHubClient::new("owner", "repo") } catch { _ => fail("Unexpected error") }
  let cmd = client.create_pull_request_command(
    "title", "body", "head", "base", labels=["release", "automated"],
  )
  let mut label_count = 0
  for i = 0; i < cmd.length(); i = i + 1 {
    if cmd[i] == "--label" {
      label_count = label_count + 1
    }
  }
  assert_eq(label_count, 2)
  let mut found_release = false
  let mut found_automated = false
  for i = 0; i < cmd.length() - 1; i = i + 1 {
    if cmd[i] == "--label" && cmd[i + 1] == "release" {
      found_release = true
    }
    if cmd[i] == "--label" && cmd[i + 1] == "automated" {
      found_automated = true
    }
  }
  assert_true(found_release)
  assert_true(found_automated)
}

// parse list JSON with empty arrays

test "parse_pull_request_list_json - empty array" {
  let json = "[]"
  let result = try { parse_pull_request_list_json(json) } catch { _ => fail("Unexpected error") }
  assert_eq(result.length(), 0)
}

test "parse_release_list_json - empty array" {
  let json = "[]"
  let result = try { parse_release_list_json(json) } catch { _ => fail("Unexpected error") }
  assert_eq(result.length(), 0)
}

// PR number boundary tests

test "parse_pull_request_json - negative number treated as 0" {
  let json =
    #|{
    #|  "number": -1,
    #|  "title": "PR",
    #|  "headRefName": "branch",
    #|  "baseRefName": "main"
    #|}
  let pr = try { parse_pull_request_json(json) } catch { _ => fail("Unexpected error") }
  assert_eq(pr.number, 0U)
}

test "parse_pull_request_json - missing number treated as 0" {
  let json =
    #|{
    #|  "title": "PR",
    #|  "headRefName": "branch",
    #|  "baseRefName": "main"
    #|}
  let pr = try { parse_pull_request_json(json) } catch { _ => fail("Unexpected error") }
  assert_eq(pr.number, 0U)
}

// parse_release_list_json - non-object elements are skipped

test "parse_release_list_json - skips non-object elements" {
  let json =
    #|[
    #|  {"tagName": "v1.0.0", "name": "R1", "isDraft": false, "isPrerelease": false},
    #|  "not-an-object",
    #|  42,
    #|  null
    #|]
  let releases = try { parse_release_list_json(json) } catch { _ => fail("Unexpected error") }
  assert_eq(releases.length(), 1)
  assert_eq(releases[0].tag_name, "v1.0.0")
}
