/// Maximum value for safe UInt conversion from Double
let uint_max_as_double : Double = 4294967295.0

/// GitHub API client (gh CLI command generation)
pub struct GitHubClient {
  owner : String
  repo : String
} derive(Show, Eq)

/// GitHub release
pub struct Release {
  tag_name : String
  name : String
  body : String
  draft : Bool
  prerelease : Bool
} derive(Show, Eq)

/// Pull Request
pub struct PullRequest {
  number : UInt
  title : String
  body : String
  head : String
  base : String
} derive(Show, Eq)

/// GitHub API error
pub suberror GitHubError {
  GitHubError(String)
}

/// Validate a GitHub repository component (owner or repo name)
/// Only allows alphanumeric, hyphen, underscore, and dot characters
fn validate_repo_component(s : String) -> Bool {
  if s.is_empty() {
    return false
  }
  let chars = s.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    let c = chars[i]
    if not((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.') {
      return false
    }
  }
  true
}

/// Create client with owner/repo validation
pub fn GitHubClient::new(
  owner : String,
  repo : String
) -> GitHubClient raise GitHubError {
  if not(validate_repo_component(owner)) {
    raise GitHubError(
      "Invalid GitHub owner: '" + owner + "' (only alphanumeric, hyphen, underscore, and dot allowed)",
    )
  }
  if not(validate_repo_component(repo)) {
    raise GitHubError(
      "Invalid GitHub repo: '" + repo + "' (only alphanumeric, hyphen, underscore, and dot allowed)",
    )
  }
  GitHubClient::{ owner, repo }
}

/// Get repository string
fn GitHubClient::repo_string(self : GitHubClient) -> String {
  self.owner + "/" + self.repo
}

/// Command to create a release
pub fn GitHubClient::create_release_command(
  self : GitHubClient,
  tag_name : String,
  title : String,
  notes : String,
  draft~ : Bool = false,
  prerelease~ : Bool = false,
  latest~ : Bool = true
) -> Array[String] {
  let cmd : Array[String] = [
    "gh",
    "release",
    "create",
    tag_name,
    "--repo",
    self.repo_string(),
    "--title",
    title,
    "--notes",
    notes,
  ]
  if draft {
    cmd.push("--draft")
  }
  if prerelease {
    cmd.push("--prerelease")
  }
  if latest {
    cmd.push("--latest")
  } else {
    cmd.push("--latest=false")
  }
  cmd
}

/// Command to get a release (by tag name)
pub fn GitHubClient::get_release_command(
  self : GitHubClient,
  tag : String
) -> Array[String] {
  ["gh", "release", "view", tag, "--repo", self.repo_string(), "--json", "tagName,name,body,isDraft,isPrerelease"]
}

/// Command to get the latest release
pub fn GitHubClient::get_latest_release_command(
  self : GitHubClient
) -> Array[String] {
  [
    "gh",
    "release",
    "list",
    "--repo",
    self.repo_string(),
    "--limit",
    "1",
    "--json",
    "tagName,name,isDraft,isPrerelease",
  ]
}

/// Command to create a PR
pub fn GitHubClient::create_pull_request_command(
  self : GitHubClient,
  title : String,
  body : String,
  head : String,
  base : String,
  draft~ : Bool = false,
  labels~ : Array[String] = []
) -> Array[String] {
  let cmd : Array[String] = [
    "gh",
    "pr",
    "create",
    "--repo",
    self.repo_string(),
    "--title",
    title,
    "--body",
    body,
    "--head",
    head,
    "--base",
    base,
  ]
  if draft {
    cmd.push("--draft")
  }
  for label in labels {
    cmd.push("--label")
    cmd.push(label)
  }
  cmd
}

/// Command to get a PR
pub fn GitHubClient::get_pull_request_command(
  self : GitHubClient,
  number : UInt
) -> Array[String] {
  [
    "gh",
    "pr",
    "view",
    number.to_string(),
    "--repo",
    self.repo_string(),
    "--json",
    "number,title,body,headRefName,baseRefName",
  ]
}

/// Command to list PRs
pub fn GitHubClient::list_pull_requests_command(
  self : GitHubClient,
  state~ : String = "open",
  limit~ : UInt = 30U
) -> Array[String] {
  [
    "gh",
    "pr",
    "list",
    "--repo",
    self.repo_string(),
    "--state",
    state,
    "--limit",
    limit.to_string(),
    "--json",
    "number,title,headRefName,baseRefName",
  ]
}

/// Parse release response with try-catch-noraise pattern
pub fn parse_release_json(output : String) -> Release raise GitHubError {
  let json = try @json.parse(output) catch {
    e => raise GitHubError("Failed to parse release JSON: " + e.to_string())
  } noraise { r => r }

  let obj = match json {
    Object(o) => o
    _ => raise GitHubError("Expected JSON object in release response")
  }

  let tag_name = match obj.get("tagName") {
    Some(String(s)) => s
    _ =>
      raise GitHubError(
        "Missing or invalid 'tagName' in release JSON response",
      )
  }

  let name = match obj.get("name") {
    Some(String(s)) => s
    Some(Null) => ""
    _ => ""
  }

  let body = match obj.get("body") {
    Some(String(s)) => s
    Some(Null) => ""
    _ => ""
  }

  let draft = match obj.get("isDraft") {
    Some(True) => true
    _ => false
  }

  let prerelease = match obj.get("isPrerelease") {
    Some(True) => true
    _ => false
  }

  Release::{ tag_name, name, body, draft, prerelease }
}

/// Parse release list response with try-catch-noraise pattern
pub fn parse_release_list_json(
  output : String
) -> Array[Release] raise GitHubError {
  let json = try @json.parse(output) catch {
    e =>
      raise GitHubError("Failed to parse release list JSON: " + e.to_string())
  } noraise { r => r }

  let arr = match json {
    Array(a) => a
    _ => raise GitHubError("Expected JSON array in release list response")
  }

  let result : Array[Release] = []
  for i = 0; i < arr.length(); i = i + 1 {
    match arr[i] {
      Object(obj) => {
        let tag_name = match obj.get("tagName") {
          Some(String(s)) => s
          _ => ""
        }
        let name = match obj.get("name") {
          Some(String(s)) => s
          _ => ""
        }
        let draft = match obj.get("isDraft") {
          Some(True) => true
          _ => false
        }
        let prerelease = match obj.get("isPrerelease") {
          Some(True) => true
          _ => false
        }
        result.push(
          Release::{ tag_name, name, body: "", draft, prerelease },
        )
      }
      _ => ()
    }
  }
  result
}

/// Parse PR response with try-catch-noraise pattern
pub fn parse_pull_request_json(output : String) -> PullRequest raise GitHubError {
  let json = try @json.parse(output) catch {
    e => raise GitHubError("Failed to parse PR JSON: " + e.to_string())
  } noraise { r => r }

  let obj = match json {
    Object(o) => o
    _ => raise GitHubError("Expected JSON object in PR response")
  }

  // Note: 0 is used as a sentinel value for parse failure.
  // Callers should check for number == 0 before using the PR number.
  let number = match obj.get("number") {
    Some(Number(n, ..)) =>
      // Treat negative, non-integer, or overflow values as 0
      if n < 0.0 || n > uint_max_as_double || n % 1.0 != 0.0 {
        0U
      } else {
        n.to_uint()
      }
    _ => 0U
  }

  let title = match obj.get("title") {
    Some(String(s)) => s
    _ => ""
  }

  let body = match obj.get("body") {
    Some(String(s)) => s
    Some(Null) => ""
    _ => ""
  }

  let head = match obj.get("headRefName") {
    Some(String(s)) => s
    _ => ""
  }

  let base = match obj.get("baseRefName") {
    Some(String(s)) => s
    _ => ""
  }

  PullRequest::{ number, title, body, head, base }
}

/// Parse PR list response with try-catch-noraise pattern
pub fn parse_pull_request_list_json(
  output : String
) -> Array[PullRequest] raise GitHubError {
  let json = try @json.parse(output) catch {
    e => raise GitHubError("Failed to parse PR list JSON: " + e.to_string())
  } noraise { r => r }

  let arr = match json {
    Array(a) => a
    _ => raise GitHubError("Expected JSON array in PR list response")
  }

  let result : Array[PullRequest] = []
  for i = 0; i < arr.length(); i = i + 1 {
    match arr[i] {
      Object(obj) => {
        let number = match obj.get("number") {
          Some(Number(n, ..)) =>
            // Treat negative, non-integer, or overflow values as 0
            if n >= 0.0 && n <= uint_max_as_double && n % 1.0 == 0.0 {
              n.to_uint()
            } else {
              0U
            }
          _ => 0U
        }
        let title = match obj.get("title") {
          Some(String(s)) => s
          _ => ""
        }
        let head = match obj.get("headRefName") {
          Some(String(s)) => s
          _ => ""
        }
        let base = match obj.get("baseRefName") {
          Some(String(s)) => s
          _ => ""
        }
        result.push(
          PullRequest::{ number, title, body: "", head, base },
        )
      }
      _ => ()
    }
  }
  result
}
