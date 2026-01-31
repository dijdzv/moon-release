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
