/// コミットメッセージをパースして ConventionalCommit を返す
pub fn parse(message : String) -> ConventionalCommit? {
  let lines : Array[String] = message
    .split("\n")
    .map(fn(sv) { sv.to_string() })
    .collect()
  if lines.is_empty() {
    return None
  }
  let header = lines[0]

  // ヘッダーをパース: type(scope)!: description
  let parsed = match parse_header(header) {
    Some(p) => p
    None => return None
  }
  let (typ, scope, breaking_mark, description) = parsed

  // body と footers を分離
  let (body, footers) = parse_body_and_footers(lines)

  // BREAKING CHANGE footer があれば breaking = true
  let breaking = breaking_mark ||
    footers.iter().any(fn(f) {
      f.0 == "BREAKING CHANGE" || f.0 == "BREAKING-CHANGE"
    })

  Some(
    ConventionalCommit::{
      typ,
      scope,
      description,
      body,
      breaking,
      footers,
    },
  )
}

/// ヘッダー行をパース
fn parse_header(header : String) -> (CommitType, String?, Bool, String)? {
  // ": " の位置を探す
  let colon_idx = match find_substring(header, ": ") {
    Some(i) => i
    None => return None
  }
  let type_part = substr(header, 0, colon_idx)
  let description = substr(header, colon_idx + 2, header.length())

  if description.is_empty() {
    return None
  }

  // breaking change の ! をチェック
  let (type_scope_part, breaking) = if type_part.has_suffix("!") {
    (substr(type_part, 0, type_part.length() - 1), true)
  } else {
    (type_part, false)
  }

  // scope をパース
  let (type_str, scope) = if type_scope_part.contains("(") &&
    type_scope_part.has_suffix(")") {
    match find_substring(type_scope_part, "(") {
      Some(paren_start) => {
        let scope_str = substr(
          type_scope_part,
          paren_start + 1,
          type_scope_part.length() - 1,
        )
        (substr(type_scope_part, 0, paren_start), Some(scope_str))
      }
      None => (type_scope_part, None)
    }
  } else {
    (type_scope_part, None)
  }

  let typ = match parse_type(type_str) {
    Some(t) => t
    None => return None
  }
  Some((typ, scope, breaking, description))
}

/// type 文字列を CommitType に変換
fn parse_type(s : String) -> CommitType? {
  match s {
    "feat" => Some(Feat)
    "fix" => Some(Fix)
    "docs" => Some(Docs)
    "style" => Some(Style)
    "refactor" => Some(Refactor)
    "perf" => Some(Perf)
    "test" => Some(Test)
    "build" => Some(Build)
    "ci" => Some(Ci)
    "chore" => Some(Chore)
    "revert" => Some(Revert)
    _ => Some(Custom(s))
  }
}

/// 部分文字列を取得（安全版）
fn substr(s : String, start : Int, end : Int) -> String {
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

/// 部分文字列の位置を検索
fn find_substring(haystack : String, needle : String) -> Int? {
  let haystack_len = haystack.length()
  let needle_len = needle.length()
  if needle_len > haystack_len {
    return None
  }
  for i = 0; i <= haystack_len - needle_len; i = i + 1 {
    if substr(haystack, i, i + needle_len) == needle {
      return Some(i)
    }
  }
  None
}

/// body と footers をパース
fn parse_body_and_footers(
  lines : Array[String]
) -> (String?, Array[(String, String)]) {
  if lines.length() <= 1 {
    return (None, [])
  }

  // 2行目以降を取得
  let rest : Array[String] = []
  for i = 1; i < lines.length(); i = i + 1 {
    rest.push(lines[i])
  }

  // 空行のみの場合
  if rest.iter().all(fn(l) { l.trim().is_empty() }) {
    return (None, [])
  }

  // footer の開始位置を探す
  let mut footer_start = -1
  for i = 0; i < rest.length(); i = i + 1 {
    let line = rest[i]
    if is_footer_line(line) {
      // footer より前に空行があることを確認
      if i > 0 && rest[i - 1].trim().is_empty() {
        footer_start = i
        break
      } else if i == 0 {
        // 最初から footer の場合（空行のみで body なし）
        footer_start = 0
        break
      }
    }
  }

  let body_lines : Array[String] = []
  let footer_lines : Array[String] = []

  if footer_start >= 0 {
    for i = 0; i < footer_start; i = i + 1 {
      body_lines.push(rest[i])
    }
    for i = footer_start; i < rest.length(); i = i + 1 {
      footer_lines.push(rest[i])
    }
  } else {
    for i = 0; i < rest.length(); i = i + 1 {
      body_lines.push(rest[i])
    }
  }

  // body を構築（先頭の空行を除去）
  let body = build_body(body_lines)

  // footers をパース
  let footers = parse_footers(footer_lines)

  (body, footers)
}

/// body 行群から body 文字列を構築
fn build_body(lines : Array[String]) -> String? {
  if lines.is_empty() {
    return None
  }

  // 先頭の空行をスキップ
  let mut start_idx = 0
  while start_idx < lines.length() && lines[start_idx].trim().is_empty() {
    start_idx = start_idx + 1
  }

  if start_idx >= lines.length() {
    return None
  }

  let result : Array[String] = []
  for i = start_idx; i < lines.length(); i = i + 1 {
    result.push(lines[i])
  }

  if result.is_empty() {
    None
  } else {
    Some(result.join("\n"))
  }
}

/// footer 行かどうかを判定
fn is_footer_line(line : String) -> Bool {
  let trimmed = line.trim().to_string()
  if trimmed.is_empty() {
    return false
  }

  // "BREAKING CHANGE: ..." 形式
  if trimmed.has_prefix("BREAKING CHANGE:") ||
    trimmed.has_prefix("BREAKING-CHANGE:") {
    return true
  }

  // "token: value" または "token #value" 形式
  match find_substring(trimmed, ": ") {
    Some(colon_idx) => {
      let token = substr(trimmed, 0, colon_idx)
      if is_valid_token(token) {
        return true
      }
    }
    None => ()
  }

  match find_substring(trimmed, " #") {
    Some(hash_idx) => {
      let token = substr(trimmed, 0, hash_idx)
      if is_valid_token(token) {
        return true
      }
    }
    None => ()
  }

  false
}

/// token が有効かチェック（英数字とハイフンのみ）
fn is_valid_token(token : String) -> Bool {
  if token.is_empty() {
    return false
  }
  token.iter().all(fn(c) {
    (c >= 'a' && c <= 'z') ||
    (c >= 'A' && c <= 'Z') ||
    (c >= '0' && c <= '9') ||
    c == '-'
  })
}

/// footer 行群をパース
fn parse_footers(lines : Array[String]) -> Array[(String, String)] {
  let footers : Array[(String, String)] = []

  for i = 0; i < lines.length(); i = i + 1 {
    let line = lines[i]
    let trimmed = line.trim().to_string()
    if trimmed.is_empty() {
      continue
    }

    // "BREAKING CHANGE: value" 形式
    if trimmed.has_prefix("BREAKING CHANGE:") {
      let value = substr(trimmed, 16, trimmed.length()).trim().to_string()
      footers.push(("BREAKING CHANGE", value))
      continue
    }

    if trimmed.has_prefix("BREAKING-CHANGE:") {
      let value = substr(trimmed, 16, trimmed.length()).trim().to_string()
      footers.push(("BREAKING-CHANGE", value))
      continue
    }

    // "token: value" 形式
    match find_substring(trimmed, ": ") {
      Some(colon_idx) => {
        let token = substr(trimmed, 0, colon_idx)
        let value = substr(trimmed, colon_idx + 2, trimmed.length())
        if is_valid_token(token) {
          footers.push((token, value))
          continue
        }
      }
      None => ()
    }

    // "token #value" 形式
    match find_substring(trimmed, " #") {
      Some(hash_idx) => {
        let token = substr(trimmed, 0, hash_idx)
        let value = substr(trimmed, hash_idx + 2, trimmed.length())
        if is_valid_token(token) {
          footers.push((token, value))
          continue
        }
      }
      None => ()
    }
  }

  footers
}
