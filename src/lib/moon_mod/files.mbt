///|
pub async fn resolve_path(prefix : String) -> String raise ParseError {
  let modern = prefix + "moon.mod"
  let legacy = prefix + "moon.mod.json"
  let modern_exists = try @fs.exists(modern) catch {
    e => raise ParseError("Cannot inspect " + modern + ": " + e.to_string())
  }
  let legacy_exists = try @fs.exists(legacy) catch {
    e => raise ParseError("Cannot inspect " + legacy + ": " + e.to_string())
  }
  if modern_exists && legacy_exists {
    raise ParseError("Both moon.mod and moon.mod.json exist in " + prefix)
  }
  if modern_exists { return modern }
  if legacy_exists { return legacy }
  raise ParseError("No moon.mod or moon.mod.json found in " + prefix)
}
