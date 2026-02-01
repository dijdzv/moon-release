/// Git repository
pub struct Repository {
  path : String
} derive(Show, Eq)

/// Git commit
pub struct GitCommit {
  hash : String
  message : String
  author : String
  date : String
} derive(Show, Eq)

/// Git error
pub suberror GitError {
  GitError(String)
}

/// GitError to string
pub fn GitError::to_string(self : GitError) -> String {
  match self {
    GitError(msg) => msg
  }
}

/// Validate repository path for security
/// Rejects paths containing ".." (directory traversal)
/// Delegates to util module for common validation logic
fn validate_repo_path(path : String) -> String? {
  // Empty path is normalized to "." - always valid
  if path.is_empty() {
    return None
  }

  // Use common validation utility (allow absolute paths for repo)
  @util.validate_path_full(path, allow_absolute=true).error_message()
}

/// Open repository with path validation
/// Returns error if path is dangerous (e.g., contains "..")
pub fn Repository::open(path : String) -> Repository raise GitError {
  match validate_repo_path(path) {
    Some(reason) => raise GitError("Invalid repository path: " + reason)
    None => ()
  }

  // Normalize empty path to "."
  let normalized_path = if path.is_empty() { "." } else { path }
  Repository::{ path: normalized_path }
}

/// Open repository without validation (for internal use and testing)
/// Use Repository::open for untrusted paths
pub fn Repository::open_unchecked(path : String) -> Repository {
  Repository::{ path }
}

/// Open repository at current directory
pub fn Repository::current() -> Repository {
  Repository::{ path: "." }
}

/// Get command to list tags
pub fn Repository::get_tags_command(self : Repository) -> Array[String] {
  ["git", "-C", self.path, "tag", "--sort=-v:refname"]
}

/// Get command to retrieve latest tag
pub fn Repository::get_latest_tag_command(self : Repository) -> Array[String] {
  ["git", "-C", self.path, "describe", "--tags", "--abbrev=0"]
}

/// Get command to retrieve commits between two refs
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

/// Get command to retrieve commits from tag to HEAD
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

/// Get command to retrieve all commits (when no tags exist)
pub fn Repository::get_all_commits_command(self : Repository) -> Array[String] {
  ["git", "-C", self.path, "log", "--pretty=format:%H|%s|%an|%aI"]
}

/// Get command to create a tag
pub fn Repository::create_tag_command(
  self : Repository,
  tag_name : String,
  message : String
) -> Array[String] {
  ["git", "-C", self.path, "tag", "-a", tag_name, "-m", message]
}

/// Get command to create a commit
pub fn Repository::create_commit_command(
  self : Repository,
  message : String
) -> Array[String] {
  ["git", "-C", self.path, "commit", "-m", message]
}

/// Get command to stage files
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

/// Get command to push
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

/// Parse commit log output
/// Format: hash|subject|author|date (where subject may contain |)
/// We parse from both ends: hash is always 40 chars, author and date are at the end
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
    // Subject may contain | so we parse carefully:
    // - hash is always first (40 chars for full SHA)
    // - author is second-to-last
    // - date is last
    // - everything in between is the subject
    let parts : Array[String] = line
      .split("|")
      .map(fn(sv) { sv.to_string() })
      .collect()

    if parts.length() >= 4 {
      let hash = parts[0]
      let date = parts[parts.length() - 1]
      let author = parts[parts.length() - 2]
      // Join middle parts back together to reconstruct subject with |
      let message_parts : Array[String] = []
      for j = 1; j < parts.length() - 2; j = j + 1 {
        message_parts.push(parts[j])
      }
      let message = message_parts.iter().fold(init="", fn(acc, s) {
        if acc.is_empty() { s } else { acc + "|" + s }
      })
      let commit = GitCommit::{ hash, message, author, date }
      commits.push(commit)
    } else if parts.length() == 3 {
      // Edge case: subject is empty
      let commit = GitCommit::{
        hash: parts[0],
        message: "",
        author: parts[1],
        date: parts[2],
      }
      commits.push(commit)
    }
  }

  commits
}

/// Parse GitCommit array to ConventionalCommit array
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

/// Get command to retrieve current date
pub fn get_date_command() -> Array[String] {
  ["date", "+%Y-%m-%d"]
}
