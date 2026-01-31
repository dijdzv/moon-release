/// セマンティックバージョン
pub struct Version {
  major : UInt
  minor : UInt
  patch : UInt
  prerelease : String?
  build_metadata : String?
} derive(Show, Eq)

/// 文字列からバージョンをパース
pub fn Version::parse(s : String) -> Version? {
  if s.is_empty() {
    return None
  }

  // build metadata を分離 (+以降)
  let (version_pre, build_metadata) = split_at_char(s, '+')

  // prerelease を分離 (-以降、ただし最初の . より前の - のみ)
  let (version_core, prerelease) = split_prerelease(version_pre)

  // major.minor.patch をパース
  let parts : Array[String] = version_core
    .split(".")
    .map(fn(sv) { sv.to_string() })
    .collect()
  if parts.length() != 3 {
    return None
  }

  let major = match parse_uint(parts[0]) {
    Some(n) => n
    None => return None
  }
  let minor = match parse_uint(parts[1]) {
    Some(n) => n
    None => return None
  }
  let patch = match parse_uint(parts[2]) {
    Some(n) => n
    None => return None
  }

  Some(Version::{ major, minor, patch, prerelease, build_metadata })
}

/// 特定の文字で分割（最初の出現で）
fn split_at_char(s : String, c : Char) -> (String, String?) {
  let chars : Array[Char] = s.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == c {
      let before = substr_chars(chars, 0, i)
      let after = substr_chars(chars, i + 1, chars.length())
      return (before, if after.is_empty() { None } else { Some(after) })
    }
  }
  (s, None)
}

/// prerelease を分離（major.minor.patch の後の - 以降）
fn split_prerelease(s : String) -> (String, String?) {
  let chars : Array[Char] = s.to_array()
  let mut dot_count = 0
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == '.' {
      dot_count = dot_count + 1
    } else if chars[i] == '-' && dot_count >= 2 {
      // 2つ目の . を見つけた後の - は prerelease の区切り
      let before = substr_chars(chars, 0, i)
      let after = substr_chars(chars, i + 1, chars.length())
      return (before, if after.is_empty() { None } else { Some(after) })
    }
  }
  (s, None)
}

/// 文字配列から部分文字列を取得
fn substr_chars(chars : Array[Char], start : Int, end : Int) -> String {
  let result = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    if i < chars.length() {
      result.write_char(chars[i])
    }
  }
  result.to_string()
}

/// 文字列を UInt にパース
/// オーバーフロー防止のため、9桁を超える場合は拒否
fn parse_uint(s : String) -> UInt? {
  if s.is_empty() {
    return None
  }
  // 9桁を超えるとオーバーフローの可能性があるため拒否
  // 999,999,999 < UInt max (4,294,967,295) なので安全
  if s.length() > 9 {
    return None
  }
  let mut result : UInt = 0
  for c in s {
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_uint() - '0'.to_uint())
    } else {
      return None
    }
  }
  Some(result)
}

/// バージョンを文字列に変換
pub fn Version::to_string(self : Version) -> String {
  let base = "\{self.major}.\{self.minor}.\{self.patch}"
  let with_pre = match self.prerelease {
    Some(pre) => "\{base}-\{pre}"
    None => base
  }
  match self.build_metadata {
    Some(meta) => "\{with_pre}+\{meta}"
    None => with_pre
  }
}

/// バージョンを比較（SemVer 2.0.0 準拠）
/// - major.minor.patch を比較
/// - 同じ場合、prerelease を比較（prerelease なし > prerelease あり）
/// - build_metadata は比較に影響しない
pub fn Version::compare(self : Version, other : Version) -> Int {
  // major.minor.patch を比較
  if self.major != other.major {
    return if self.major > other.major { 1 } else { -1 }
  }
  if self.minor != other.minor {
    return if self.minor > other.minor { 1 } else { -1 }
  }
  if self.patch != other.patch {
    return if self.patch > other.patch { 1 } else { -1 }
  }

  // prerelease を比較
  match (self.prerelease, other.prerelease) {
    // 両方 prerelease なし → 同じ
    (None, None) => 0
    // self のみ prerelease あり → self が小さい
    (Some(_), None) => -1
    // other のみ prerelease あり → self が大きい
    (None, Some(_)) => 1
    // 両方 prerelease あり → 文字列を比較
    (Some(self_pre), Some(other_pre)) => compare_prerelease(self_pre, other_pre)
  }
}

/// prerelease 文字列を比較（SemVer 2.0.0 仕様）
/// - . で分割して各部分を比較
/// - 数値のみの部分は数値として比較
/// - それ以外は辞書順で比較
/// - 部分が少ない方が小さい（alpha < alpha.1）
fn compare_prerelease(a : String, b : String) -> Int {
  let a_parts : Array[String] = a.split(".").map(fn(sv) { sv.to_string() }).collect()
  let b_parts : Array[String] = b.split(".").map(fn(sv) { sv.to_string() }).collect()

  let min_len = if a_parts.length() < b_parts.length() {
    a_parts.length()
  } else {
    b_parts.length()
  }

  for i = 0; i < min_len; i = i + 1 {
    let cmp = compare_prerelease_part(a_parts[i], b_parts[i])
    if cmp != 0 {
      return cmp
    }
  }

  // 共通部分が同じなら、部分が多い方が大きい
  if a_parts.length() < b_parts.length() {
    -1
  } else if a_parts.length() > b_parts.length() {
    1
  } else {
    0
  }
}

/// prerelease の各部分を比較
fn compare_prerelease_part(a : String, b : String) -> Int {
  let a_num = parse_uint(a)
  let b_num = parse_uint(b)

  match (a_num, b_num) {
    // 両方数値 → 数値として比較
    (Some(an), Some(bn)) =>
      if an < bn {
        -1
      } else if an > bn {
        1
      } else {
        0
      }
    // a のみ数値 → 数値が先（小さい）
    (Some(_), None) => -1
    // b のみ数値 → 数値が先（小さい）
    (None, Some(_)) => 1
    // 両方文字列 → 辞書順
    (None, None) => compare_string(a, b)
  }
}

/// 文字列を辞書順で比較
fn compare_string(a : String, b : String) -> Int {
  let a_chars = a.to_array()
  let b_chars = b.to_array()
  let min_len = if a_chars.length() < b_chars.length() {
    a_chars.length()
  } else {
    b_chars.length()
  }

  for i = 0; i < min_len; i = i + 1 {
    if a_chars[i] < b_chars[i] {
      return -1
    } else if a_chars[i] > b_chars[i] {
      return 1
    }
  }

  if a_chars.length() < b_chars.length() {
    -1
  } else if a_chars.length() > b_chars.length() {
    1
  } else {
    0
  }
}

/// prerelease 文字列のバリデーション（SemVer 2.0.0 準拠）
/// - ASCII 英数字とハイフンのみ [0-9A-Za-z-]
/// - ドットで区切られた識別子
/// - 数値のみの識別子は先頭ゼロ禁止
/// - 空文字列は禁止
pub fn validate_prerelease(prerelease : String) -> Bool {
  if prerelease.is_empty() {
    return false
  }

  let identifiers : Array[String] = prerelease
    .split(".")
    .map(fn(sv) { sv.to_string() })
    .collect()

  for id in identifiers {
    if not(validate_prerelease_identifier(id)) {
      return false
    }
  }

  true
}

/// 単一の prerelease 識別子をバリデーション
fn validate_prerelease_identifier(id : String) -> Bool {
  if id.is_empty() {
    return false
  }

  let chars : Array[Char] = id.to_array()
  let mut is_numeric = true

  for c in chars {
    if not(is_alphanumeric_or_hyphen(c)) {
      return false
    }
    if not(c >= '0' && c <= '9') {
      is_numeric = false
    }
  }

  // 数値のみの識別子は先頭ゼロ禁止（"0" は許可）
  if is_numeric && chars.length() > 1 && chars[0] == '0' {
    return false
  }

  true
}

/// ASCII 英数字またはハイフンかどうかをチェック
fn is_alphanumeric_or_hyphen(c : Char) -> Bool {
  (c >= '0' && c <= '9') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= 'a' && c <= 'z') ||
  c == '-'
}
