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
fn parse_uint(s : String) -> UInt? {
  if s.is_empty() {
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

/// バージョンを比較
pub fn Version::compare(self : Version, other : Version) -> Int {
  if self.major != other.major {
    return if self.major > other.major { 1 } else { -1 }
  }
  if self.minor != other.minor {
    return if self.minor > other.minor { 1 } else { -1 }
  }
  if self.patch != other.patch {
    return if self.patch > other.patch { 1 } else { -1 }
  }
  0
}
