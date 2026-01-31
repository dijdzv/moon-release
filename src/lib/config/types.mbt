/// 設定
pub struct Config {
  pr_title : String
  changelog_include : Array[String]
  allow_prerelease : Bool
  github_release : Bool
  publish : Bool
} derive(Show, Eq)

/// 設定エラー
pub suberror ConfigError {
  ConfigError(String)
}

/// デフォルト設定
pub fn Config::default() -> Config {
  Config::{
    pr_title: "chore: release v{{ version }}",
    changelog_include: ["feat", "fix", "perf", "refactor"],
    allow_prerelease: false,
    github_release: true,
    publish: true,
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

  let changelog_include = match obj.get("changelog_include") {
    Some(Array(arr)) => {
      let result : Array[String] = []
      for i = 0; i < arr.length(); i = i + 1 {
        match arr[i] {
          String(s) => result.push(s)
          _ => raise ConfigError("'changelog_include' must be an array of strings")
        }
      }
      result
    }
    Some(_) => raise ConfigError("'changelog_include' must be an array")
    None => default.changelog_include
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

  let publish = match obj.get("publish") {
    Some(True) => true
    Some(False) => false
    Some(_) => raise ConfigError("'publish' must be a boolean")
    None => default.publish
  }

  Config::{ pr_title, changelog_include, allow_prerelease, github_release, publish }
}

/// タイトルテンプレートにバージョンを適用
pub fn Config::apply_version_template(self : Config, version : String) -> String {
  self.pr_title.replace(old="{{ version }}", new=version)
}
