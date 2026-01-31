/// moon.mod.json の構造
pub struct MoonMod {
  name : String
  version : String
  deps : @hashmap.HashMap[String, String]?
} derive(Show)

/// パースエラー
pub suberror ParseError {
  ParseError(String)
}

/// moon.mod.json をパース
pub fn parse(content : String) -> MoonMod raise ParseError {
  let json = try {
    @json.parse(content)
  } catch {
    e => raise ParseError("JSON parse error: " + e.to_string())
  }

  let obj = match json {
    Object(o) => o
    _ => raise ParseError("Expected JSON object")
  }

  // name フィールド
  let name = match obj.get("name") {
    Some(String(s)) => s
    Some(_) => raise ParseError("'name' must be a string")
    None => raise ParseError("Missing 'name' field")
  }

  // version フィールド
  let version = match obj.get("version") {
    Some(String(s)) => s
    Some(_) => raise ParseError("'version' must be a string")
    None => raise ParseError("Missing 'version' field")
  }

  // deps フィールド（オプショナル）
  let deps : @hashmap.HashMap[String, String]? = match obj.get("deps") {
    Some(Object(deps_obj)) => {
      let deps_map : @hashmap.HashMap[String, String] = @hashmap.new()
      for k, v in deps_obj {
        match v {
          String(version_str) => deps_map.set(k, version_str)
          _ => raise ParseError("Dependency version must be a string")
        }
      }
      Some(deps_map)
    }
    Some(Null) => None
    None => None
    _ => raise ParseError("'deps' must be an object")
  }

  MoonMod::{ name, version, deps }
}

/// バージョンを更新（JSON を維持しながら version のみ変更）
pub fn update_version(
  content : String,
  new_version : @semver.Version
) -> String raise ParseError {
  // まずパースして有効な JSON か確認
  let _ = parse(content)

  // version フィールドを置換
  let version_str = new_version.to_string()
  replace_json_field(content, "version", version_str)
}

/// JSON フィールドの値を置換（フォーマットを維持）
fn replace_json_field(
  content : String,
  field : String,
  new_value : String
) -> String raise ParseError {
  // "version": "..." のパターンを探して置換
  let pattern = "\"" + field + "\""
  let chars : Array[Char] = content.to_array()

  // フィールド名を探す
  let field_start = find_pattern(content, pattern)
  if field_start < 0 {
    raise ParseError("Field '" + field + "' not found")
  }

  // : の後の値を探す
  let mut value_start = -1
  for i = field_start + pattern.length(); i < chars.length(); i = i + 1 {
    let c = chars[i]
    if c == '"' {
      value_start = i
      break
    }
  }

  if value_start < 0 {
    raise ParseError("Value for '" + field + "' not found")
  }

  // 値の終端を探す
  let mut value_end = -1
  let mut i = value_start + 1
  while i < chars.length() {
    let c = chars[i]
    if c == '\\' && i + 1 < chars.length() {
      // エスケープシーケンスをスキップ
      i = i + 2
      continue
    }
    if c == '"' {
      value_end = i + 1
      break
    }
    i = i + 1
  }

  if value_end < 0 {
    raise ParseError("Unterminated string value for '" + field + "'")
  }

  // 新しい値で置換
  let before = substr_str(chars, 0, value_start)
  let after = substr_str(chars, value_end, chars.length())
  before + "\"" + new_value + "\"" + after
}

/// パターンの位置を探す
fn find_pattern(haystack : String, needle : String) -> Int {
  let h_chars : Array[Char] = haystack.to_array()
  let n_chars : Array[Char] = needle.to_array()

  if n_chars.length() > h_chars.length() {
    return -1
  }

  for i = 0; i <= h_chars.length() - n_chars.length(); i = i + 1 {
    let mut matched = true
    for j = 0; j < n_chars.length(); j = j + 1 {
      if h_chars[i + j] != n_chars[j] {
        matched = false
        break
      }
    }
    if matched {
      return i
    }
  }
  -1
}

/// 文字配列から部分文字列を取得
fn substr_str(chars : Array[Char], start : Int, end : Int) -> String {
  let result = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    if i >= 0 && i < chars.length() {
      result.write_char(chars[i])
    }
  }
  result.to_string()
}
