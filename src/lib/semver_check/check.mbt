/// Semver check result
pub struct CheckResult {
  suggested_bump : @semver.BumpType?
  diff : ApiDiff
  messages : Array[String]
} derive(Show)

/// Check if result indicates success (no breaking changes)
pub fn CheckResult::is_success(self : CheckResult) -> Bool {
  not(self.diff.has_breaking())
}

/// Create check result
pub fn CheckResult::new(diff : ApiDiff) -> CheckResult {
  let messages : Array[String] = []
  let suggested_bump : @semver.BumpType? = if diff.has_breaking() {
    Some(Major)
  } else if diff.has_additions() {
    Some(Minor)
  } else if diff.changes.is_empty() {
    None
  } else {
    Some(Patch)
  }

  // Generate messages
  if diff.has_breaking() {
    messages.push("BREAKING CHANGES detected:")
    for change in diff.changes {
      if change.kind == Breaking {
        messages.push("  - [\{change.category}] \{change.name}: \{change.description}")
      }
    }
  }

  if diff.has_additions() {
    messages.push("New additions:")
    for change in diff.changes {
      if change.kind == Addition {
        messages.push("  + [\{change.category}] \{change.name}: \{change.description}")
      }
    }
  }

  CheckResult::{ suggested_bump, diff, messages }
}

/// Convert result to display string
pub fn CheckResult::format(self : CheckResult) -> String {
  let lines : Array[String] = []

  lines.push("=== Semver Check Result ===")
  lines.push("")

  if self.diff.changes.is_empty() {
    lines.push("No API changes detected.")
  } else {
    lines.push("API changes: \{self.diff.changes.length()}")
    lines.push("")

    for msg in self.messages {
      lines.push(msg)
    }
  }

  lines.push("")
  let bump_str = match self.suggested_bump {
    Some(Major) => "MAJOR (breaking changes)"
    Some(Minor) => "MINOR (new features)"
    Some(Patch) => "PATCH (compatible changes)"
    None => "NONE (no changes)"
  }
  lines.push("Suggested version bump: " + bump_str)

  if not(self.is_success()) {
    lines.push("")
    lines.push("WARNING: Breaking changes detected!")
    lines.push("Consider bumping the major version or documenting the breaking changes.")
  }

  lines.iter().fold(init="", fn(acc, line) {
    if acc.is_empty() { line } else { acc + "\n" + line }
  })
}
