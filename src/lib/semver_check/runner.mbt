///|
/// Merge multiple package_data.json files
/// When multiple packages are merged, prefixes each entry's name with the package path
/// to avoid duplicate names causing HashMap overwrites in diff_api
pub fn merge_package_apis(apis : Array[PackageApi]) -> PackageApi {
  let merged = PackageApi::{
    name: "",
    types: [],
    errors: [],
    traits: [],
    values: [],
  }

  // Only prefix names when merging multiple packages
  let need_prefix = apis.length() > 1

  for api in apis {
    let prefix = if need_prefix && not(api.name.is_empty()) {
      api.name + "."
    } else {
      ""
    }

    for t in api.types {
      let name = prefix + t.name
      let methods = prefix_methods(t.methods, prefix)
      merged.types.push(TypeInfo::{ name, signature: t.signature, methods })
    }
    for e in api.errors {
      let name = prefix + e.name
      let methods = prefix_methods(e.methods, prefix)
      merged.errors.push(ErrorInfo::{ name, signature: e.signature, methods })
    }
    for t in api.traits {
      let name = prefix + t.name
      let methods = prefix_methods(t.methods, prefix)
      merged.traits.push(TraitInfo::{ name, signature: t.signature, methods })
    }
    for v in api.values {
      let name = prefix + v.name
      merged.values.push(ValueInfo::{ name, signature: v.signature })
    }
  }

  // Detect and warn about remaining duplicates
  warn_duplicates(merged.types.iter().map(fn(t) { t.name }).collect(), "type")
  warn_duplicates(merged.errors.iter().map(fn(e) { e.name }).collect(), "error")
  warn_duplicates(merged.traits.iter().map(fn(t) { t.name }).collect(), "trait")
  warn_duplicates(merged.values.iter().map(fn(v) { v.name }).collect(), "value")

  merged
}

///|
/// Prefix method names (no-op when prefix is empty)
fn prefix_methods(
  methods : Array[MethodInfo],
  prefix : String,
) -> Array[MethodInfo] {
  if prefix.is_empty() {
    return methods
  }
  let result : Array[MethodInfo] = []
  for m in methods {
    result.push(MethodInfo::{ name: prefix + m.name, signature: m.signature })
  }
  result
}

///|
/// Warn about duplicate names in merged API entries
fn warn_duplicates(names : Array[String], category : String) -> Unit {
  let seen : @hashmap.HashMap[String, Bool] = @hashmap.new()
  for name in names {
    if seen.get(name) is Some(true) {
      println(
        "Warning: duplicate \{category} API name '\{name}' found across packages",
      )
    } else {
      seen.set(name, true)
    }
  }
}

///|
/// Get suggested bump type from API diff
/// Delegates to CheckResult::new to consolidate bump suggestion logic
pub fn get_suggested_bump_from_diff(diff : ApiDiff) -> String? {
  let result = CheckResult::new(diff)
  match result.suggested_bump {
    Some(Major) => Some("major")
    Some(Minor) => Some("minor")
    Some(Patch) => Some("patch")
    None => Option::None
  }
}

///|
/// Format check result as concise summary
pub fn format_summary(result : CheckResult) -> String {
  let lines : Array[String] = []

  let breaking_count = result.diff.changes
    .iter()
    .filter(fn(c) { c.kind == Breaking })
    .count()
  let addition_count = result.diff.changes
    .iter()
    .filter(fn(c) { c.kind == Addition })
    .count()

  if breaking_count > 0 {
    lines.push("Breaking changes: \{breaking_count}")
  }
  if addition_count > 0 {
    lines.push("Additions: \{addition_count}")
  }

  if lines.is_empty() {
    "No API changes detected."
  } else {
    lines
    .iter()
    .fold(init="", fn(acc, line) {
      if acc.is_empty() {
        line
      } else {
        acc + ", " + line
      }
    })
  }
}
