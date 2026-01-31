/// 設定
pub struct Config {
  pr_title : String
  pr_draft : Bool
  pr_labels : Array[String]
  pr_body : String
  allow_prerelease : Bool
  git_tag_enable : Bool
  git_tag_name : String
  git_release_enable : Bool
  git_release_draft : Bool
  git_release_name : String
  git_release_body : String?
  git_release_latest : Bool
  publish : Bool
  publish_frozen : Bool
  semver_check : Bool
  pr_branch_prefix : String
  base_branch : String
  packages : Array[PackageConfig]
  registry_check : Bool
  allow_dirty : Bool
  custom_major_increment_regex : String?
  custom_minor_increment_regex : String?
  max_analyze_commits : UInt?
  publish_timeout : UInt  // 秒単位、現在は未使用（将来実装予定）
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
    git_tag_enable: true,
    git_tag_name: "v{{ version }}",
    git_release_enable: true,
    git_release_draft: false,
    git_release_name: "Release v{{ version }}",
    git_release_body: None,
    git_release_latest: true,
    publish: true,
    publish_frozen: false,
    semver_check: false,
    pr_branch_prefix: "release/",
    base_branch: "main",
    packages: [],
    registry_check: false,
    allow_dirty: false,
    custom_major_increment_regex: None,
    custom_minor_increment_regex: None,
    max_analyze_commits: None,
    publish_timeout: 300,  // デフォルト5分
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
  let d = Config::default()

  if content.trim().is_empty() {
    return d
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

  // packages は特別な処理が必要
  let packages = match obj.get("packages") {
    Some(Array(arr)) => parse_packages(arr)
    Some(_) => raise ConfigError("'packages' must be an array")
    None => d.packages
  }

  Config::{
    pr_title: parse_string(obj, "pr_title", d.pr_title),
    pr_draft: parse_bool(obj, "pr_draft", d.pr_draft),
    pr_labels: parse_string_array(obj, "pr_labels", d.pr_labels),
    pr_body: parse_string(obj, "pr_body", d.pr_body),
    allow_prerelease: parse_bool(obj, "allow_prerelease", d.allow_prerelease),
    git_tag_enable: parse_bool(obj, "git_tag_enable", d.git_tag_enable),
    git_tag_name: parse_string(obj, "git_tag_name", d.git_tag_name),
    git_release_enable: parse_bool(obj, "git_release_enable", d.git_release_enable),
    git_release_draft: parse_bool(obj, "git_release_draft", d.git_release_draft),
    git_release_name: parse_string(obj, "git_release_name", d.git_release_name),
    git_release_body: parse_optional_string(obj, "git_release_body", d.git_release_body),
    git_release_latest: parse_bool(obj, "git_release_latest", d.git_release_latest),
    publish: parse_bool(obj, "publish", d.publish),
    publish_frozen: parse_bool(obj, "publish_frozen", d.publish_frozen),
    semver_check: parse_bool(obj, "semver_check", d.semver_check),
    pr_branch_prefix: parse_string(obj, "pr_branch_prefix", d.pr_branch_prefix),
    base_branch: parse_string(obj, "base_branch", d.base_branch),
    packages,
    registry_check: parse_bool(obj, "registry_check", d.registry_check),
    allow_dirty: parse_bool(obj, "allow_dirty", d.allow_dirty),
    custom_major_increment_regex: parse_optional_string(
      obj,
      "custom_major_increment_regex",
      d.custom_major_increment_regex,
    ),
    custom_minor_increment_regex: parse_optional_string(
      obj,
      "custom_minor_increment_regex",
      d.custom_minor_increment_regex,
    ),
    max_analyze_commits: parse_optional_uint(
      obj,
      "max_analyze_commits",
      d.max_analyze_commits,
    ),
    publish_timeout: parse_uint(obj, "publish_timeout", d.publish_timeout),
  }
}

/// パッケージ設定をパース
fn parse_packages(arr : Array[Json]) -> Array[PackageConfig] raise ConfigError {
  let result : Array[PackageConfig] = []
  for i = 0; i < arr.length(); i = i + 1 {
    match arr[i] {
      Object(pkg_obj) => {
        let name = parse_pkg_required_string(pkg_obj, "name")
        let path = parse_pkg_string(pkg_obj, "path", ".")
        let publish = parse_pkg_bool(pkg_obj, "publish", true)
        let version_group = parse_pkg_optional_string(pkg_obj, "version_group", None)
        result.push(PackageConfig::{ name, path, publish, version_group })
      }
      _ => raise ConfigError("package must be an object")
    }
  }
  result
}

// ============================================================================
// JSON パースヘルパー関数
// ============================================================================

/// 文字列フィールドをパース
fn parse_string(
  obj : Map[String, Json],
  key : String,
  default : String
) -> String raise ConfigError {
  match obj.get(key) {
    Some(String(s)) => s
    Some(_) => raise ConfigError("'" + key + "' must be a string")
    None => default
  }
}

/// 必須の文字列フィールドをパース（パッケージ用）
fn parse_pkg_required_string(
  obj : Map[String, Json],
  key : String
) -> String raise ConfigError {
  match obj.get(key) {
    Some(String(s)) => s
    Some(_) => raise ConfigError("package '" + key + "' must be a string")
    None => raise ConfigError("package '" + key + "' is required")
  }
}

/// 文字列フィールドをパース（パッケージ用）
fn parse_pkg_string(
  obj : Map[String, Json],
  key : String,
  default : String
) -> String raise ConfigError {
  match obj.get(key) {
    Some(String(s)) => s
    Some(_) => raise ConfigError("package '" + key + "' must be a string")
    None => default
  }
}

/// オプショナルな文字列フィールドをパース
fn parse_optional_string(
  obj : Map[String, Json],
  key : String,
  default : String?
) -> String? raise ConfigError {
  match obj.get(key) {
    Some(String(s)) => Some(s)
    Some(Null) => None
    Some(_) => raise ConfigError("'" + key + "' must be a string")
    None => default
  }
}

/// オプショナルな文字列フィールドをパース（パッケージ用）
fn parse_pkg_optional_string(
  obj : Map[String, Json],
  key : String,
  default : String?
) -> String? raise ConfigError {
  match obj.get(key) {
    Some(String(s)) => Some(s)
    Some(Null) => None
    Some(_) => raise ConfigError("package '" + key + "' must be a string")
    None => default
  }
}

/// ブーリアンフィールドをパース
fn parse_bool(
  obj : Map[String, Json],
  key : String,
  default : Bool
) -> Bool raise ConfigError {
  match obj.get(key) {
    Some(True) => true
    Some(False) => false
    Some(_) => raise ConfigError("'" + key + "' must be a boolean")
    None => default
  }
}

/// オプショナルな数値フィールドをパース
fn parse_optional_uint(
  obj : Map[String, Json],
  key : String,
  default : UInt?
) -> UInt? raise ConfigError {
  match obj.get(key) {
    Some(Number(n, ..)) =>
      if n >= 0.0 && n == n.to_int().to_double() {
        Some(n.to_uint())
      } else {
        raise ConfigError("'" + key + "' must be a positive integer")
      }
    Some(Null) => None
    Some(_) => raise ConfigError("'" + key + "' must be a number")
    None => default
  }
}

/// 数値フィールドをパース
fn parse_uint(
  obj : Map[String, Json],
  key : String,
  default : UInt
) -> UInt raise ConfigError {
  match obj.get(key) {
    Some(Number(n, ..)) =>
      if n >= 0.0 && n == n.to_int().to_double() {
        n.to_uint()
      } else {
        raise ConfigError("'" + key + "' must be a positive integer")
      }
    Some(_) => raise ConfigError("'" + key + "' must be a number")
    None => default
  }
}

/// ブーリアンフィールドをパース（パッケージ用）
fn parse_pkg_bool(
  obj : Map[String, Json],
  key : String,
  default : Bool
) -> Bool raise ConfigError {
  match obj.get(key) {
    Some(True) => true
    Some(False) => false
    Some(_) => raise ConfigError("package '" + key + "' must be a boolean")
    None => default
  }
}

/// 文字列配列フィールドをパース
fn parse_string_array(
  obj : Map[String, Json],
  key : String,
  default : Array[String]
) -> Array[String] raise ConfigError {
  match obj.get(key) {
    Some(Array(arr)) => {
      let result : Array[String] = []
      for i = 0; i < arr.length(); i = i + 1 {
        match arr[i] {
          String(s) => result.push(s)
          _ => raise ConfigError("'" + key + "' must be an array of strings")
        }
      }
      result
    }
    Some(_) => raise ConfigError("'" + key + "' must be an array")
    None => default
  }
}

/// タイトルテンプレートにバージョンを適用
pub fn Config::apply_version_template(self : Config, version : String) -> String {
  self.pr_title.replace(old="{{ version }}", new=version)
}
