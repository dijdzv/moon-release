///|
fn is_json_manifest(content : String) -> Bool {
  content.trim().to_owned().has_prefix("{")
}

///|
fn quoted_end(chars : Array[Char], start : Int) -> Int raise ParseError {
  let mut i = start + 1
  while i < chars.length() {
    if chars[i] == '\\' { i += 2; continue }
    if chars[i] == '"' { return i + 1 }
    i += 1
  }
  raise ParseError("Unterminated string in moon.mod")
}

///|
fn skip_space_comments(chars : Array[Char], start : Int) -> Int {
  let mut i = start
  while i < chars.length() {
    if chars[i] == ' ' || chars[i] == '\t' || chars[i] == '\r' || chars[i] == '\n' {
      i += 1
    } else if i + 1 < chars.length() && chars[i] == '/' && chars[i + 1] == '/' {
      while i < chars.length() && chars[i] != '\n' { i += 1 }
    } else {
      break
    }
  }
  i
}

///|
fn modern_field_span(content : String, field : String) -> (Int, Int) raise ParseError {
  let chars = content.to_array()
  let mut i = 0
  let mut depth = 0
  let mut found : (Int, Int)? = None
  while i < chars.length() {
    i = skip_space_comments(chars, i)
    if i == chars.length() { break }
    let c = chars[i]
    if c == '"' {
      i = quoted_end(chars, i)
      continue
    }
    // Multiline strings are line-prefixed; their text must never become metadata.
    if c == '#' && i + 1 < chars.length() && chars[i + 1] == '|' {
      while i < chars.length() && chars[i] != '\n' { i += 1 }
      continue
    }
    if c == '{' || c == '[' || c == '(' { depth += 1 }
    if c == '}' || c == ']' || c == ')' {
      depth -= 1
      if depth < 0 { raise ParseError("Unbalanced delimiters in moon.mod") }
    }
    if (c >= 'a' && c <= 'z') || c == '_' {
      let start = i
      while i < chars.length() && ((chars[i] >= 'a' && chars[i] <= 'z') ||
        (chars[i] >= 'A' && chars[i] <= 'Z') || (chars[i] >= '0' && chars[i] <= '9') || chars[i] == '_') {
        i += 1
      }
      if depth == 0 && substr_str(chars, start, i) == field {
        let equals = skip_space_comments(chars, i)
        if equals < chars.length() && chars[equals] == '=' {
          let start = skip_space_comments(chars, equals + 1)
          if start >= chars.length() || chars[start] != '"' {
            raise ParseError("'" + field + "' must be a string literal in moon.mod")
          }
          let end = quoted_end(chars, start)
          if found is Some(_) { raise ParseError("Duplicate '" + field + "' in moon.mod") }
          found = Some((start, end))
          i = end
        }
      }
      continue
    }
    i += 1
  }
  if depth != 0 { raise ParseError("Unbalanced delimiters in moon.mod") }
  match found {
    Some(span) => span
    None => raise ParseError("Missing '" + field + "' field in moon.mod")
  }
}

///|
pub fn read_name(content : String) -> String raise ParseError {
  if is_json_manifest(content) {
    let json = try @json.parse(content) catch {
      e => raise ParseError(e.to_string())
    }
    match json {
      Object(obj) => match obj.get("name") {
        Some(String(name)) => name
        _ => raise ParseError("Missing string 'name' in manifest")
      }
      _ => raise ParseError("Expected JSON object")
    }
  } else {
    read_mod_field(content, "name")
  }
}

///|
fn read_mod_field(content : String, field : String) -> String raise ParseError {
  let (start, end) = modern_field_span(content, field)
  let literal = substr_str(content.to_array(), start, end)
  let value = try @json.parse(literal) catch {
    e => raise ParseError("Invalid string literal: " + e.to_string())
  }
  match value {
    String(s) => s
    _ => raise ParseError("Expected string literal")
  }
}
