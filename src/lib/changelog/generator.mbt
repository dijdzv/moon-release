/// CHANGELOG エントリ
pub struct ChangelogEntry {
  version : @semver.Version
  date : String
  sections : @hashmap.HashMap[String, Array[ChangelogItem]]
} derive(Show)

/// CHANGELOG アイテム
pub struct ChangelogItem {
  description : String
  scope : String?
  commit_hash : String?
} derive(Show)

/// セクション名の順序
let section_order : Array[String] = [
  "BREAKING CHANGES",
  "Added",
  "Changed",
  "Deprecated",
  "Removed",
  "Fixed",
  "Security",
  "Other",
]

/// CommitType をセクション名に変換
fn type_to_section(typ : @conventional.CommitType, breaking : Bool) -> String {
  if breaking {
    return "BREAKING CHANGES"
  }
  match typ {
    @conventional.Feat => "Added"
    @conventional.Fix => "Fixed"
    @conventional.Perf => "Changed"
    @conventional.Refactor => "Changed"
    @conventional.Docs => "Other"
    @conventional.Style => "Other"
    @conventional.Test => "Other"
    @conventional.Build => "Other"
    @conventional.Ci => "Other"
    @conventional.Chore => "Other"
    @conventional.Revert => "Changed"
    @conventional.Custom(_) => "Other"
  }
}

/// CHANGELOG エントリを生成
pub fn generate_entry(
  commits : Array[(@conventional.ConventionalCommit, String)],
  new_version : @semver.Version,
  date : String
) -> ChangelogEntry {
  let sections : @hashmap.HashMap[String, Array[ChangelogItem]] = @hashmap.new()

  for i = 0; i < commits.length(); i = i + 1 {
    let (commit, hash) = commits[i]
    let section = type_to_section(commit.typ, commit.breaking)

    let item = ChangelogItem::{
      description: commit.description,
      scope: commit.scope,
      commit_hash: Some(hash),
    }

    match sections.get(section) {
      Some(items) => items.push(item)
      None => sections.set(section, [item])
    }
  }

  ChangelogEntry::{ version: new_version, date, sections }
}

/// CHANGELOG エントリを Markdown 文字列に変換
pub fn entry_to_markdown(entry : ChangelogEntry) -> String {
  let result = StringBuilder::new()

  // ヘッダー
  result.write_string("## [")
  result.write_string(entry.version.to_string())
  result.write_string("] - ")
  result.write_string(entry.date)
  result.write_string("\n")

  // セクションを順序通りに出力
  for i = 0; i < section_order.length(); i = i + 1 {
    let section = section_order[i]
    match entry.sections.get(section) {
      Some(items) => {
        if items.length() > 0 {
          result.write_string("\n### ")
          result.write_string(section)
          result.write_string("\n\n")

          for j = 0; j < items.length(); j = j + 1 {
            let item = items[j]
            result.write_string("- ")
            match item.scope {
              Some(s) => {
                result.write_string("**")
                result.write_string(s)
                result.write_string("**: ")
              }
              None => ()
            }
            result.write_string(item.description)
            match item.commit_hash {
              Some(h) => {
                result.write_string(" (")
                result.write_string(substr_hash(h, 7))
                result.write_string(")")
              }
              None => ()
            }
            result.write_string("\n")
          }
        }
      }
      None => ()
    }
  }

  result.to_string()
}

/// ハッシュを短縮
fn substr_hash(hash : String, len : Int) -> String {
  if hash.length() <= len {
    return hash
  }
  let chars : Array[Char] = hash.to_array()
  let result = StringBuilder::new()
  for i = 0; i < len; i = i + 1 {
    if i < chars.length() {
      result.write_char(chars[i])
    }
  }
  result.to_string()
}

/// CHANGELOG を生成（便利関数）
pub fn generate(
  commits : Array[(@conventional.ConventionalCommit, String)],
  new_version : @semver.Version,
  date : String
) -> String {
  let entry = generate_entry(commits, new_version, date)
  entry_to_markdown(entry)
}

/// 既存の CHANGELOG に新しいエントリを追加
pub fn prepend_to_changelog(existing : String, new_entry : ChangelogEntry) -> String {
  let new_content = entry_to_markdown(new_entry)

  // # Changelog ヘッダーを探す
  let header_end = find_header_end(existing)

  if header_end > 0 {
    // ヘッダーの後に挿入
    let before = substr_str(existing, 0, header_end)
    let after = substr_str(existing, header_end, existing.length())
    before + "\n" + new_content + after
  } else {
    // ヘッダーがなければ先頭に追加
    "# Changelog\n\n" + new_content + "\n" + existing
  }
}

/// CHANGELOG ヘッダーの終了位置を探す
fn find_header_end(s : String) -> Int {
  let lines : Array[String] = s.split("\n").map(fn(sv) { sv.to_string() }).collect()
  let mut pos = 0

  for i = 0; i < lines.length(); i = i + 1 {
    let line = lines[i]
    pos = pos + line.length() + 1 // +1 for newline

    // # Changelog または # CHANGELOG の後
    if line.has_prefix("# Changelog") || line.has_prefix("# CHANGELOG") {
      // 次の空行まで進む
      for j = i + 1; j < lines.length(); j = j + 1 {
        let next_line = lines[j]
        pos = pos + next_line.length() + 1
        if next_line.trim().is_empty() {
          return pos
        }
        if next_line.has_prefix("## ") {
          // 次のセクションの前で止まる
          return pos - next_line.length() - 1
        }
      }
      return pos
    }
  }
  0
}

/// 文字列の部分取得
fn substr_str(s : String, start : Int, end : Int) -> String {
  if start < 0 || end > s.length() || start > end {
    return ""
  }
  let chars : Array[Char] = s.to_array()
  let result = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    if i < chars.length() {
      result.write_char(chars[i])
    }
  }
  result.to_string()
}
