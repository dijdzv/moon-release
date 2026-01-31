/// GitHub API クライアント（gh CLI コマンド生成）
pub struct GitHubClient {
  owner : String
  repo : String
} derive(Show, Eq)

/// GitHub リリース
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

/// GitHub API エラー
pub suberror GitHubError {
  GitHubError(String)
}

/// クライアントを作成
pub fn GitHubClient::new(owner : String, repo : String) -> GitHubClient {
  GitHubClient::{ owner, repo }
}

/// リポジトリ文字列を取得
fn GitHubClient::repo_string(self : GitHubClient) -> String {
  self.owner + "/" + self.repo
}

/// リリースを作成するコマンド
pub fn GitHubClient::create_release_command(
  self : GitHubClient,
  tag_name : String,
  title : String,
  notes : String,
  draft~ : Bool = false,
  prerelease~ : Bool = false
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
  cmd
}

/// リリースを取得するコマンド（タグ名で）
pub fn GitHubClient::get_release_command(
  self : GitHubClient,
  tag : String
) -> Array[String] {
  ["gh", "release", "view", tag, "--repo", self.repo_string(), "--json", "tagName,name,body,isDraft,isPrerelease"]
}

/// 最新リリースを取得するコマンド
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

/// PR を作成するコマンド
pub fn GitHubClient::create_pull_request_command(
  self : GitHubClient,
  title : String,
  body : String,
  head : String,
  base : String,
  draft~ : Bool = false
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
  cmd
}

/// PR を取得するコマンド
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

/// PR 一覧を取得するコマンド
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

/// リリースレスポンスをパース
pub fn parse_release_json(output : String) -> Release raise GitHubError {
  let json = try {
    @json.parse(output)
  } catch {
    e => raise GitHubError("Failed to parse release JSON: " + e.to_string())
  }

  let obj = match json {
    Object(o) => o
    _ => raise GitHubError("Expected JSON object in release response")
  }

  let tag_name = match obj.get("tagName") {
    Some(String(s)) => s
    _ => ""
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

/// リリース一覧レスポンスをパース
pub fn parse_release_list_json(
  output : String
) -> Array[Release] raise GitHubError {
  let json = try {
    @json.parse(output)
  } catch {
    e =>
      raise GitHubError("Failed to parse release list JSON: " + e.to_string())
  }

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

/// PR レスポンスをパース
pub fn parse_pull_request_json(output : String) -> PullRequest raise GitHubError {
  let json = try {
    @json.parse(output)
  } catch {
    e => raise GitHubError("Failed to parse PR JSON: " + e.to_string())
  }

  let obj = match json {
    Object(o) => o
    _ => raise GitHubError("Expected JSON object in PR response")
  }

  let number = match obj.get("number") {
    Some(Number(n, ..)) => n.to_uint()
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

/// PR 一覧レスポンスをパース
pub fn parse_pull_request_list_json(
  output : String
) -> Array[PullRequest] raise GitHubError {
  let json = try {
    @json.parse(output)
  } catch {
    e => raise GitHubError("Failed to parse PR list JSON: " + e.to_string())
  }

  let arr = match json {
    Array(a) => a
    _ => raise GitHubError("Expected JSON array in PR list response")
  }

  let result : Array[PullRequest] = []
  for i = 0; i < arr.length(); i = i + 1 {
    match arr[i] {
      Object(obj) => {
        let number = match obj.get("number") {
          Some(Number(n, ..)) => n.to_uint()
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
