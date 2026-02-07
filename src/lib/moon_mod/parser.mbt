/// moon.mod.json structure
pub struct MoonMod {
  name : String
  version : String
  deps : @hashmap.HashMap[String, String]?
} derive(Show)

/// Parse error
pub suberror ParseError {
  ParseError(String)
}

/// Convert ParseError to string
pub fn ParseError::to_string(self : ParseError) -> String {
  match self {
    ParseError(msg) => msg
  }
}

/// Parse moon.mod.json with try-catch-noraise pattern
pub fn parse(content : String) -> MoonMod raise ParseError {
  let json = try @json.parse(content) catch {
    e => raise ParseError("JSON parse error: " + e.to_string())
  } noraise { r => r }

  let obj = match json {
    Object(o) => o
    _ => raise ParseError("Expected JSON object")
  }

  // name field
  let name = match obj.get("name") {
    Some(String(s)) => s
    Some(_) => raise ParseError("'name' must be a string")
    None => raise ParseError("Missing 'name' field")
  }

  // version field
  let version = match obj.get("version") {
    Some(String(s)) => s
    Some(_) => raise ParseError("'version' must be a string")
    None => raise ParseError("Missing 'version' field")
  }

  // deps field (optional)
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

/// Update version (change only version while preserving JSON)
pub fn update_version(
  content : String,
  new_version : @semver.Version
) -> String raise ParseError {
  // First parse to verify valid JSON
  let _ = parse(content)

  // Replace version field
  let version_str = new_version.to_string()
  replace_json_field(content, "version", version_str)
}

/// Replace JSON field value (preserving format)
fn replace_json_field(
  content : String,
  field : String,
  new_value : String
) -> String raise ParseError {
  // Verify new_value doesn't contain JSON special characters
  for c in new_value {
    if c == '"' || c == '\\' || c.to_int() < 32 {
      raise ParseError(
        "Invalid character in value: values cannot contain quotes, backslashes, or control characters",
      )
    }
  }

  // Find and replace "field": "..." pattern
  // Must find the field as a JSON key (followed by ':'), not inside a string value
  let pattern = "\"" + field + "\""
  let chars : Array[Char] = content.to_array()

  // Find field name as a JSON key (not inside a string value)
  let field_start = find_json_key(content, pattern)
  if field_start < 0 {
    raise ParseError("Field '" + field + "' not found")
  }

  // Find value after :
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

  // Find end of value
  let mut value_end = -1
  let mut i = value_start + 1
  while i < chars.length() {
    let c = chars[i]
    if c == '\\' && i + 1 < chars.length() {
      // Skip escape sequence
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

  // Replace with new value
  let before = substr_str(chars, 0, value_start)
  let after = substr_str(chars, value_end, chars.length())
  before + "\"" + new_value + "\"" + after
}

/// Find JSON key position (skips occurrences inside string values)
/// Returns the char index of the key pattern, only if followed by ':'
/// Only matches keys at brace depth 1 (top-level keys inside the root object)
fn find_json_key(haystack : String, needle : String) -> Int {
  let h_chars : Array[Char] = haystack.to_array()
  let n_chars : Array[Char] = needle.to_array()

  if n_chars.length() > h_chars.length() {
    return -1
  }

  let mut in_string = false
  let mut depth = 0
  let mut i = 0
  while i <= h_chars.length() - n_chars.length() {
    let c = h_chars[i]
    if c == '\\' && in_string && i + 1 < h_chars.length() {
      // Skip escaped character inside string
      i = i + 2
      continue
    }
    if c == '"' {
      if in_string {
        // Closing quote - we were inside a string value
        in_string = false
        i = i + 1
        continue
      }
      // Opening quote - check if this matches the needle pattern
      let mut matched = true
      for j = 0; j < n_chars.length(); j = j + 1 {
        if i + j >= h_chars.length() || h_chars[i + j] != n_chars[j] {
          matched = false
          break
        }
      }
      if matched {
        // Check if followed by ':' (with optional whitespace)
        let mut k = i + n_chars.length()
        while k < h_chars.length() && (h_chars[k] == ' ' || h_chars[k] == '\t') {
          k = k + 1
        }
        if k < h_chars.length() && h_chars[k] == ':' {
          // Only match at depth 1 (top-level keys inside root object)
          if depth == 1 {
            return i
          }
        }
        // Not a match or wrong depth - it's a string value, skip past the closing quote
        // Move past the opening quote and into the string
        i = i + 1
        in_string = true
      } else {
        // Opening quote of some other string
        i = i + 1
        in_string = true
      }
      continue
    }
    if not(in_string) {
      if c == '{' {
        depth = depth + 1
      } else if c == '}' {
        depth = depth - 1
      }
    }
    i = i + 1
  }
  -1
}

/// Get substring from character array
fn substr_str(chars : Array[Char], start : Int, end : Int) -> String {
  let result = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    if i >= 0 && i < chars.length() {
      result.write_char(chars[i])
    }
  }
  result.to_string()
}
