/// Git リポジトリ
pub struct Repository {
  path : String
} derive(Show, Eq)

/// Git コミット
pub struct GitCommit {
  hash : String
  message : String
  author : String
  date : String
} derive(Show, Eq)

/// Open repository
pub fn Repository::open(path : String) -> Repository {
  Repository::{ path }
}

/// 現在のディレクトリでリポジトリを開く
pub fn Repository::current() -> Repository {
  Repository::{ path: "." }
}

/// タグ一覧を取得するコマンド
pub fn Repository::get_tags_command(self : Repository) -> Array[String] {
  ["git", "-C", self.path, "tag", "--sort=-v:refname"]
}

/// 最新タグを取得するコマンド
pub fn Repository::get_latest_tag_command(self : Repository) -> Array[String] {
  ["git", "-C", self.path, "describe", "--tags", "--abbrev=0"]
}

/// 2点間のコミットを取得するコマンド
pub fn Repository::get_commits_command(
  self : Repository,
  from : String,
  to : String
) -> Array[String] {
  [
    "git",
    "-C",
    self.path,
    "log",
    "--pretty=format:%H|%s|%an|%aI",
    from + ".." + to,
  ]
}

/// HEAD までのコミットを取得するコマンド（タグから）
pub fn Repository::get_commits_since_tag_command(
  self : Repository,
  tag : String
) -> Array[String] {
  [
    "git",
    "-C",
    self.path,
    "log",
    "--pretty=format:%H|%s|%an|%aI",
    tag + "..HEAD",
  ]
}

/// 全コミットを取得するコマンド（タグがない場合）
pub fn Repository::get_all_commits_command(self : Repository) -> Array[String] {
  ["git", "-C", self.path, "log", "--pretty=format:%H|%s|%an|%aI"]
}

/// タグを作成するコマンド
pub fn Repository::create_tag_command(
  self : Repository,
  tag_name : String,
  message : String
) -> Array[String] {
  ["git", "-C", self.path, "tag", "-a", tag_name, "-m", message]
}

/// コミットを作成するコマンド
pub fn Repository::create_commit_command(
  self : Repository,
  message : String
) -> Array[String] {
  ["git", "-C", self.path, "commit", "-m", message]
}

/// ファイルをステージングするコマンド
pub fn Repository::stage_files_command(
  self : Repository,
  files : Array[String]
) -> Array[String] {
  let cmd : Array[String] = ["git", "-C", self.path, "add"]
  for file in files {
    cmd.push(file)
  }
  cmd
}

/// push するコマンド
pub fn Repository::push_command(
  self : Repository,
  include_tags : Bool
) -> Array[String] {
  if include_tags {
    ["git", "-C", self.path, "push", "--follow-tags"]
  } else {
    ["git", "-C", self.path, "push"]
  }
}

/// コミットログをパース
pub fn parse_commit_log(output : String) -> Array[GitCommit] {
  let commits : Array[GitCommit] = []
  let lines : Array[String] = output
    .split("\n")
    .map(fn(sv) { sv.to_string() })
    .collect()

  for i = 0; i < lines.length(); i = i + 1 {
    let line = lines[i].trim().to_string()
    if line.is_empty() {
      continue
    }

    // format: hash|subject|author|date
    let parts : Array[String] = line
      .split("|")
      .map(fn(sv) { sv.to_string() })
      .collect()
    if parts.length() >= 4 {
      let commit = GitCommit::{
        hash: parts[0],
        message: parts[1],
        author: parts[2],
        date: parts[3],
      }
      commits.push(commit)
    }
  }

  commits
}

/// GitCommit を ConventionalCommit にパース
pub fn parse_conventional_commits(
  commits : Array[GitCommit]
) -> Array[(@conventional.ConventionalCommit, String)] {
  let result : Array[(@conventional.ConventionalCommit, String)] = []

  for i = 0; i < commits.length(); i = i + 1 {
    let commit = commits[i]
    match @conventional.parse(commit.message) {
      Some(cc) => result.push((cc, commit.hash))
      None => ()
    }
  }

  result
}

/// 現在の日付を取得するコマンド
pub fn get_date_command() -> Array[String] {
  ["date", "+%Y-%m-%d"]
}
