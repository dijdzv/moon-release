///|
/// Git repository
pub struct Repository {
  path : String
} derive(Show, Eq)

///|
/// Git commit
pub struct GitCommit {
  hash : String
  message : String
  author : String
  date : String
} derive(Show, Eq)

///|
/// Git error
pub suberror GitError {
  GitError(String)
}

///|
/// GitError to string
pub fn GitError::to_string(self : GitError) -> String {
  match self {
    GitError(msg) => msg
  }
}

///|
/// Validates that a git ref name doesn't contain dangerous characters
fn validate_ref_param(ref_name : String) -> Bool {
  if ref_name.is_empty() {
    return false
  }
  let chars = ref_name.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    let c = chars[i]
    // Reject shell metacharacters, git special chars, and control characters
    if c == ' ' ||
      c == '\n' ||
      c == '\r' ||
      c == '\u0000' ||
      c == '|' ||
      c == ';' ||
      c == '`' ||
      c == '$' ||
      c == '&' ||
      c == '>' ||
      c == '<' ||
      c == '(' ||
      c == ')' ||
      c == '{' ||
      c == '}' ||
      c == '~' ||
      c == '^' ||
      c == ':' ||
      c == '?' ||
      c == '*' ||
      c == '[' ||
      c == '\\' {
      return false
    }
  }
  // Reject option-like arguments
  if ref_name.has_prefix("--") {
    return false
  }
  // Reject directory traversal sequences
  if ref_name.contains("..") {
    return false
  }
  true
}

///|
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

///|
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

///|
/// Open repository without validation (for internal use and testing)
/// Use Repository::open for untrusted paths
pub fn Repository::open_unchecked(path : String) -> Repository {
  Repository::{ path, }
}

///|
/// Open repository at current directory
pub fn Repository::current() -> Repository {
  Repository::{ path: "." }
}

///|
/// Get command to list tags
pub fn Repository::get_tags_command(self : Repository) -> Array[String] {
  ["git", "-C", self.path, "tag", "--sort=-v:refname"]
}

///|
/// Get command to retrieve latest tag
pub fn Repository::get_latest_tag_command(self : Repository) -> Array[String] {
  ["git", "-C", self.path, "describe", "--tags", "--abbrev=0"]
}

///|
/// Get command to retrieve commits between two refs
pub fn Repository::get_commits_command(
  self : Repository,
  from : String,
  to : String,
) -> Array[String] raise GitError {
  if not(validate_ref_param(from)) {
    raise GitError("Invalid git ref: '" + from + "'")
  }
  if not(validate_ref_param(to)) {
    raise GitError("Invalid git ref: '" + to + "'")
  }
  [
    "git",
    "-C",
    self.path,
    "log",
    "--pretty=format:%H%x1E%s%x1E%an%x1E%aI",
    from + ".." + to,
  ]
}

///|
/// Get command to retrieve commits from tag to HEAD
pub fn Repository::get_commits_since_tag_command(
  self : Repository,
  tag : String,
) -> Array[String] raise GitError {
  if not(validate_ref_param(tag)) {
    raise GitError("Invalid git ref: '" + tag + "'")
  }
  [
    "git",
    "-C",
    self.path,
    "log",
    "--pretty=format:%H%x1E%s%x1E%an%x1E%aI",
    tag + "..HEAD",
  ]
}

///|
/// Get command to retrieve all commits (when no tags exist)
pub fn Repository::get_all_commits_command(self : Repository) -> Array[String] {
  ["git", "-C", self.path, "log", "--pretty=format:%H%x1E%s%x1E%an%x1E%aI"]
}

///|
/// Get command to create a tag
pub fn Repository::create_tag_command(
  self : Repository,
  tag_name : String,
  message : String,
) -> Array[String] {
  ["git", "-C", self.path, "tag", "-a", "-m", message, "--", tag_name]
}

///|
/// Get command to create a commit
pub fn Repository::create_commit_command(
  self : Repository,
  message : String,
) -> Array[String] {
  ["git", "-C", self.path, "commit", "-m", message]
}

///|
/// Get command to stage files
pub fn Repository::stage_files_command(
  self : Repository,
  files : Array[String],
) -> Array[String] {
  let cmd : Array[String] = ["git", "-C", self.path, "add"]
  for file in files {
    cmd.push(file)
  }
  cmd
}

///|
/// Get command to push
pub fn Repository::push_command(
  self : Repository,
  include_tags : Bool,
) -> Array[String] {
  if include_tags {
    ["git", "-C", self.path, "push", "--follow-tags"]
  } else {
    ["git", "-C", self.path, "push"]
  }
}

///|
/// Parse commit log output
/// Format: hash\x1Esubject\x1Eauthor\x1Edate (using Record Separator U+001E)
/// Subject may contain any printable character safely since \x1E is a control character
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

    // Split by Record Separator (U+001E)
    let parts : Array[String] = line
      .split("\u001e")
      .map(fn(sv) { sv.to_string() })
      .collect()

    if parts.length() >= 4 {
      let hash = parts[0]
      let date = parts[parts.length() - 1]
      let author = parts[parts.length() - 2]
      // Join middle parts back together (should be just one part with \x1E separator)
      let message_parts : Array[String] = []
      for j = 1; j < parts.length() - 2; j = j + 1 {
        message_parts.push(parts[j])
      }
      let sb = StringBuilder::new()
      for j2, part in message_parts {
        if j2 > 0 {
          sb.write_string("\u001e")
        }
        sb.write_string(part)
      }
      let message = sb.to_string()
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

///|
/// Parse GitCommit array to ConventionalCommit array
pub fn parse_conventional_commits(
  commits : Array[GitCommit],
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

///|
/// Get command to retrieve current date
pub fn get_date_command() -> Array[String] {
  ["date", "+%Y-%m-%d"]
}
