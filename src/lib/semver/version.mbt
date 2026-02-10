///|
/// Semantic version
pub struct Version {
  major : UInt
  minor : UInt
  patch : UInt
  prerelease : String?
  build_metadata : String?
} derive(Show, Eq)

///|
/// Parse version from string
pub fn Version::parse(s : String) -> Version? {
  if s.is_empty() {
    return None
  }

  // Separate build metadata (after +)
  let (version_pre, build_metadata) = split_at_char(s, '+')

  // Separate prerelease (after -, but only - after first .)
  let (version_core, prerelease) = split_prerelease(version_pre)

  // Parse major.minor.patch
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

  // Validate prerelease
  match prerelease {
    Some(pre) => if not(validate_prerelease(pre)) { return None }
    None => ()
  }

  // Validate build metadata
  match build_metadata {
    Some(meta) => if not(validate_build_metadata(meta)) { return None }
    None => ()
  }

  Some(Version::{ major, minor, patch, prerelease, build_metadata })
}

///|
/// Split at character (first occurrence)
fn split_at_char(s : String, c : Char) -> (String, String?) {
  let chars : Array[Char] = s.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == c {
      let before = substr_chars(chars, 0, i)
      let after = substr_chars(chars, i + 1, chars.length())
      return (before, Some(after))
    }
  }
  (s, None)
}

///|
/// Separate prerelease (after - following major.minor.patch)
fn split_prerelease(s : String) -> (String, String?) {
  let chars : Array[Char] = s.to_array()
  let mut dot_count = 0
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == '.' {
      dot_count = dot_count + 1
    } else if chars[i] == '-' && dot_count >= 2 {
      // - after 2nd . is the prerelease separator
      let before = substr_chars(chars, 0, i)
      let after = substr_chars(chars, i + 1, chars.length())
      return (before, Some(after))
    }
  }
  (s, None)
}

///|
/// Get substring from character array
fn substr_chars(chars : Array[Char], start : Int, end : Int) -> String {
  let result = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    if i < chars.length() {
      result.write_char(chars[i])
    }
  }
  result.to_string()
}

///|
/// Parse string to UInt
/// Reject numbers with more than 9 digits to prevent overflow
/// Reject leading zeros per SemVer 2.0.0 spec (e.g., "01" is invalid, "0" is valid)
fn parse_uint(s : String) -> UInt? {
  if s.is_empty() {
    return None
  }
  let chars = s.to_array()
  let len = chars.length()
  // Reject more than 9 digits to prevent overflow
  // 999,999,999 < UInt max (4,294,967,295) so it's safe
  if len > 9 {
    return None
  }
  // Reject leading zeros (e.g., "01", "007") but allow "0"
  if chars[0] == '0' && len > 1 {
    return None
  }
  let mut result : UInt = 0
  for c in chars {
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_uint() - '0'.to_uint())
    } else {
      return None
    }
  }
  Some(result)
}

///|
/// Create a new version with a prerelease identifier set
/// Returns None if the prerelease identifier is invalid
pub fn Version::with_prerelease(
  self : Version,
  prerelease : String,
) -> Version? {
  if not(validate_prerelease(prerelease)) {
    return None
  }
  Some(Version::{
    major: self.major,
    minor: self.minor,
    patch: self.patch,
    prerelease: Some(prerelease),
    build_metadata: self.build_metadata,
  })
}

///|
/// Convert version to string
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

///|
/// Compare versions (SemVer 2.0.0 compliant)
/// - Compare major.minor.patch
/// - If equal, compare prerelease (no prerelease > with prerelease)
/// - build_metadata does not affect comparison
pub fn Version::compare(self : Version, other : Version) -> Int {
  // Compare major.minor.patch
  if self.major != other.major {
    return if self.major > other.major { 1 } else { -1 }
  }
  if self.minor != other.minor {
    return if self.minor > other.minor { 1 } else { -1 }
  }
  if self.patch != other.patch {
    return if self.patch > other.patch { 1 } else { -1 }
  }

  // Compare prerelease
  match (self.prerelease, other.prerelease) {
    // Both have no prerelease → equal
    (None, None) => 0
    // Only self has prerelease → self is smaller
    (Some(_), None) => -1
    // Only other has prerelease → self is larger
    (None, Some(_)) => 1
    // Both have prerelease → compare strings
    (Some(self_pre), Some(other_pre)) => compare_prerelease(self_pre, other_pre)
  }
}

///|
/// Compare prerelease strings (SemVer 2.0.0 spec)
/// - Split by . and compare each part
/// - Numeric-only parts are compared as numbers
/// - Others are compared lexicographically
/// - Fewer parts means smaller (alpha < alpha.1)
fn compare_prerelease(a : String, b : String) -> Int {
  let a_parts : Array[String] = a
    .split(".")
    .map(fn(sv) { sv.to_string() })
    .collect()
  let b_parts : Array[String] = b
    .split(".")
    .map(fn(sv) { sv.to_string() })
    .collect()

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

  // If common parts are equal, more parts means larger
  if a_parts.length() < b_parts.length() {
    -1
  } else if a_parts.length() > b_parts.length() {
    1
  } else {
    0
  }
}

///|
/// Compare each part of prerelease
fn compare_prerelease_part(a : String, b : String) -> Int {
  let a_num = parse_uint(a)
  let b_num = parse_uint(b)

  match (a_num, b_num) {
    // Both numeric → compare as numbers
    (Some(an), Some(bn)) => if an < bn { -1 } else if an > bn { 1 } else { 0 }
    // Only a is numeric → numeric comes first (smaller)
    (Some(_), None) => -1
    // Only b is numeric → numeric comes first (smaller)
    (None, Some(_)) => 1
    // Both strings → lexicographic comparison
    (None, None) => compare_string(a, b)
  }
}

///|
/// Compare strings lexicographically
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

///|
/// Validate prerelease string (SemVer 2.0.0 compliant)
/// - Only ASCII alphanumeric and hyphen [0-9A-Za-z-]
/// - Dot-separated identifiers
/// - Numeric-only identifiers cannot have leading zeros
/// - Empty string is not allowed
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

///|
/// Validate a single prerelease identifier
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

  // Numeric-only identifiers cannot have leading zeros ("0" is allowed)
  if is_numeric && chars.length() > 1 && chars[0] == '0' {
    return false
  }

  true
}

///|
/// Validate build metadata string (SemVer 2.0.0 compliant)
/// - Only ASCII alphanumeric and hyphen [0-9A-Za-z-]
/// - Dot-separated identifiers
/// - Empty identifiers are not allowed
/// - Unlike prerelease, leading zeros ARE allowed in numeric identifiers
pub fn validate_build_metadata(metadata : String) -> Bool {
  if metadata.is_empty() {
    return false
  }

  let identifiers : Array[String] = metadata
    .split(".")
    .map(fn(sv) { sv.to_string() })
    .collect()

  for id in identifiers {
    if id.is_empty() {
      return false
    }
    let chars : Array[Char] = id.to_array()
    for c in chars {
      if not(is_alphanumeric_or_hyphen(c)) {
        return false
      }
    }
  }

  true
}

///|
/// Check if character is ASCII alphanumeric or hyphen
fn is_alphanumeric_or_hyphen(c : Char) -> Bool {
  (c >= '0' && c <= '9') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= 'a' && c <= 'z') ||
  c == '-'
}
