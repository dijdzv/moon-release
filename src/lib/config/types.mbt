/// 設定
pub struct Config {
  pr_title : String
  pr_draft : Bool
  pr_labels : Array[String]
  pr_body : String
  allow_prerelease : Bool
  github_release : Bool
  git_release_draft : Bool
  git_release_name : String
  git_tag_name : String
  publish : Bool
  release_branch_prefix : String
  base_branch : String
  packages : Array[PackageConfig]
  registry_check : Bool
  allow_dirty : Bool
  custom_major_increment_regex : String?
  custom_minor_increment_regex : String?
} derive(Show, Eq)

/// パッケージ設定（モノレポ用）
pub struct PackageConfig {
  name : String
  path : String
  publish : Bool
  version_group : String?
} derive(Show, Eq)

/// 設定エラー
pub suberror ConfigError {
  ConfigError(String)
}

/// ConfigError を文字列に変換
pub fn ConfigError::to_string(self : ConfigError) -> String {
  match self {
    ConfigError(msg) => msg
  }
}

/// デフォルト設定
pub fn Config::default() -> Config {
  Config::{
    pr_title: "chore: release v{{ version }}",
    pr_draft: false,
    pr_labels: [],
    pr_body: "## Release v{{ version }}\n\n---\n*This PR was automatically created by moon-release.*",
    allow_prerelease: false,
    github_release: true,
    git_release_draft: false,
    git_release_name: "Release v{{ version }}",
    git_tag_name: "v{{ version }}",
    publish: true,
    release_branch_prefix: "release/",
    base_branch: "main",
    packages: [],
    registry_check: false,
    allow_dirty: false,
    custom_major_increment_regex: None,
    custom_minor_increment_regex: None,
  }
}

/// デフォルトパッケージ設定
pub fn PackageConfig::default(name : String, path : String) -> PackageConfig {
  PackageConfig::{
    name,
    path,
    publish: true,
    version_group: None,
  }
}

/// JSON から設定をパース（デフォルト値とマージ）
pub fn Config::parse(content : String) -> Config raise ConfigError {
  let default = Config::default()

  if content.trim().is_empty() {
    return default
  }

  let json = try {
    @json.parse(content)
  } catch {
    e => raise ConfigError("JSON parse error: " + e.to_string())
  }

  let obj = match json {
    Object(o) => o
    _ => raise ConfigError("Expected JSON object")
  }

  // 各フィールドをオプショナルでパース
  let pr_title = match obj.get("pr_title") {
    Some(String(s)) => s
    Some(_) => raise ConfigError("'pr_title' must be a string")
    None => default.pr_title
  }

  let pr_draft = match obj.get("pr_draft") {
    Some(True) => true
    Some(False) => false
    Some(_) => raise ConfigError("'pr_draft' must be a boolean")
    None => default.pr_draft
  }

  let pr_labels = match obj.get("pr_labels") {
    Some(Array(arr)) => {
      let result : Array[String] = []
      for i = 0; i < arr.length(); i = i + 1 {
        match arr[i] {
          String(s) => result.push(s)
          _ => raise ConfigError("'pr_labels' must be an array of strings")
        }
      }
      result
    }
    Some(_) => raise ConfigError("'pr_labels' must be an array")
    None => default.pr_labels
  }

  let pr_body = match obj.get("pr_body") {
    Some(String(s)) => s
    Some(_) => raise ConfigError("'pr_body' must be a string")
    None => default.pr_body
  }

  let allow_prerelease = match obj.get("allow_prerelease") {
    Some(True) => true
    Some(False) => false
    Some(_) => raise ConfigError("'allow_prerelease' must be a boolean")
    None => default.allow_prerelease
  }

  let github_release = match obj.get("github_release") {
    Some(True) => true
    Some(False) => false
    Some(_) => raise ConfigError("'github_release' must be a boolean")
    None => default.github_release
  }

  let git_release_draft = match obj.get("git_release_draft") {
    Some(True) => true
    Some(False) => false
    Some(_) => raise ConfigError("'git_release_draft' must be a boolean")
    None => default.git_release_draft
  }

  let git_release_name = match obj.get("git_release_name") {
    Some(String(s)) => s
    Some(_) => raise ConfigError("'git_release_name' must be a string")
    None => default.git_release_name
  }

  let git_tag_name = match obj.get("git_tag_name") {
    Some(String(s)) => s
    Some(_) => raise ConfigError("'git_tag_name' must be a string")
    None => default.git_tag_name
  }

  let publish = match obj.get("publish") {
    Some(True) => true
    Some(False) => false
    Some(_) => raise ConfigError("'publish' must be a boolean")
    None => default.publish
  }

  let release_branch_prefix = match obj.get("release_branch_prefix") {
    Some(String(s)) => s
    Some(_) => raise ConfigError("'release_branch_prefix' must be a string")
    None => default.release_branch_prefix
  }

  let base_branch = match obj.get("base_branch") {
    Some(String(s)) => s
    Some(_) => raise ConfigError("'base_branch' must be a string")
    None => default.base_branch
  }

  let packages = match obj.get("packages") {
    Some(Array(arr)) => parse_packages(arr)
    Some(_) => raise ConfigError("'packages' must be an array")
    None => default.packages
  }

  let registry_check = match obj.get("registry_check") {
    Some(True) => true
    Some(False) => false
    Some(_) => raise ConfigError("'registry_check' must be a boolean")
    None => default.registry_check
  }

  let allow_dirty = match obj.get("allow_dirty") {
    Some(True) => true
    Some(False) => false
    Some(_) => raise ConfigError("'allow_dirty' must be a boolean")
    None => default.allow_dirty
  }

  let custom_major_increment_regex : String? = match obj.get(
    "custom_major_increment_regex",
  ) {
    Some(String(s)) => Some(s)
    Some(Null) => None
    Some(_) => raise ConfigError("'custom_major_increment_regex' must be a string")
    None => default.custom_major_increment_regex
  }

  let custom_minor_increment_regex : String? = match obj.get(
    "custom_minor_increment_regex",
  ) {
    Some(String(s)) => Some(s)
    Some(Null) => None
    Some(_) => raise ConfigError("'custom_minor_increment_regex' must be a string")
    None => default.custom_minor_increment_regex
  }

  Config::{
    pr_title,
    pr_draft,
    pr_labels,
    pr_body,
    allow_prerelease,
    github_release,
    git_release_draft,
    git_release_name,
    git_tag_name,
    publish,
    release_branch_prefix,
    base_branch,
    packages,
    registry_check,
    allow_dirty,
    custom_major_increment_regex,
    custom_minor_increment_regex,
  }
}

/// パッケージ設定をパース
fn parse_packages(arr : Array[Json]) -> Array[PackageConfig] raise ConfigError {
  let result : Array[PackageConfig] = []
  for i = 0; i < arr.length(); i = i + 1 {
    match arr[i] {
      Object(pkg_obj) => {
        let name = match pkg_obj.get("name") {
          Some(String(s)) => s
          Some(_) => raise ConfigError("package 'name' must be a string")
          None => raise ConfigError("package 'name' is required")
        }
        let path = match pkg_obj.get("path") {
          Some(String(s)) => s
          Some(_) => raise ConfigError("package 'path' must be a string")
          None => "."
        }
        let publish = match pkg_obj.get("publish") {
          Some(True) => true
          Some(False) => false
          Some(_) => raise ConfigError("package 'publish' must be a boolean")
          None => true
        }
        let version_group : String? = match pkg_obj.get("version_group") {
          Some(String(s)) => Some(s)
          Some(Null) => None
          Some(_) => raise ConfigError("package 'version_group' must be a string")
          None => None
        }
        result.push(
          PackageConfig::{
            name,
            path,
            publish,
            version_group,
          },
        )
      }
      _ => raise ConfigError("package must be an object")
    }
  }
  result
}

/// タイトルテンプレートにバージョンを適用
pub fn Config::apply_version_template(self : Config, version : String) -> String {
  self.pr_title.replace(old="{{ version }}", new=version)
}
