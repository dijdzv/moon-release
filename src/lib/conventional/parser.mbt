/// Parse commit message and return ConventionalCommit
pub fn parse(message : String) -> ConventionalCommit? {
  let lines : Array[String] = message
    .split("\n")
    .map(fn(sv) { sv.to_string() })
    .collect()
  if lines.is_empty() {
    return None
  }
  let header = lines[0]

  // Parse header: type(scope)!: description
  let parsed = match parse_header(header) {
    Some(p) => p
    None => return None
  }
  let (typ, scope, breaking_mark, description) = parsed

  // Separate body and footers
  let (body, footers) = parse_body_and_footers(lines)

  // Set breaking = true if BREAKING CHANGE footer exists
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

/// Parse header line
fn parse_header(header : String) -> (CommitType, String?, Bool, String)? {
  // Find position of ": "
  let colon_idx = match find_substring(header, ": ") {
    Some(i) => i
    None => return None
  }
  let type_part = substr(header, 0, colon_idx)
  let description = substr(header, colon_idx + 2, header.length())

  if description.is_empty() {
    return None
  }

  // Check for breaking change indicator !
  let (type_scope_part, breaking) = if type_part.has_suffix("!") {
    (substr(type_part, 0, type_part.length() - 1), true)
  } else {
    (type_part, false)
  }

  // Parse scope
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

/// Convert type string to CommitType
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

/// Get substring (safe version)
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

/// Find position of substring
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

/// Parse body and footers
fn parse_body_and_footers(
  lines : Array[String]
) -> (String?, Array[(String, String)]) {
  if lines.length() <= 1 {
    return (None, [])
  }

  // Get lines from 2nd line onwards
  let rest : Array[String] = []
  for i = 1; i < lines.length(); i = i + 1 {
    rest.push(lines[i])
  }

  // If only empty lines
  if rest.iter().all(fn(l) { l.trim().is_empty() }) {
    return (None, [])
  }

  // Find footer start position
  let mut footer_start = -1
  for i = 0; i < rest.length(); i = i + 1 {
    let line = rest[i]
    if is_footer_line(line) {
      // Verify there is an empty line before footer
      if i > 0 && rest[i - 1].trim().is_empty() {
        footer_start = i
        break
      } else if i == 0 {
        // If footer starts from beginning (empty lines only, no body)
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

  // Build body (remove leading empty lines)
  let body = build_body(body_lines)

  // Parse footers
  let footers = parse_footers(footer_lines)

  (body, footers)
}

/// Build body string from body lines
fn build_body(lines : Array[String]) -> String? {
  if lines.is_empty() {
    return None
  }

  // Skip leading empty lines
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

/// Check if line is a footer line
fn is_footer_line(line : String) -> Bool {
  let trimmed = line.trim().to_string()
  if trimmed.is_empty() {
    return false
  }

  // "BREAKING CHANGE: ..." format
  if trimmed.has_prefix("BREAKING CHANGE:") ||
    trimmed.has_prefix("BREAKING-CHANGE:") {
    return true
  }

  // "token: value" or "token #value" format
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

/// Check if token is valid (alphanumeric and hyphens only)
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

/// Parse footer lines
fn parse_footers(lines : Array[String]) -> Array[(String, String)] {
  let footers : Array[(String, String)] = []

  for i = 0; i < lines.length(); i = i + 1 {
    let line = lines[i]
    let trimmed = line.trim().to_string()
    if trimmed.is_empty() {
      continue
    }

    // "BREAKING CHANGE: value" format
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

    // "token: value" format
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

    // "token #value" format
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
