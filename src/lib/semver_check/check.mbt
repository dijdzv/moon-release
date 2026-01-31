/// Semver check result
pub struct CheckResult {
  success : Bool
  suggested_bump : SuggestedBump
  diff : ApiDiff
  messages : Array[String]
} derive(Show)

/// Suggested version bump
pub enum SuggestedBump {
  /// Breaking changes detected -> Major
  Major
  /// New features added -> Minor
  Minor
  /// No changes or only compatible changes -> Patch
  Patch
  /// No API changes
  None
} derive(Show, Eq)

/// Create check result
pub fn CheckResult::new(diff : ApiDiff) -> CheckResult {
  let messages : Array[String] = []
  let suggested_bump = if diff.has_breaking {
    Major
  } else if diff.has_additions {
    Minor
  } else if diff.changes.is_empty() {
    None
  } else {
    Patch
  }

  // Generate messages
  if diff.has_breaking {
    messages.push("BREAKING CHANGES detected:")
    for change in diff.changes {
      if change.kind == Breaking {
        messages.push("  - [\{change.category}] \{change.name}: \{change.description}")
      }
    }
  }

  if diff.has_additions {
    messages.push("New additions:")
    for change in diff.changes {
      if change.kind == Addition {
        messages.push("  + [\{change.category}] \{change.name}: \{change.description}")
      }
    }
  }

  let success = not(diff.has_breaking)

  CheckResult::{ success, suggested_bump, diff, messages }
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
    Major => "MAJOR (breaking changes)"
    Minor => "MINOR (new features)"
    Patch => "PATCH (compatible changes)"
    None => "NONE (no changes)"
  }
  lines.push("Suggested version bump: " + bump_str)

  if not(self.success) {
    lines.push("")
    lines.push("WARNING: Breaking changes detected!")
    lines.push("Consider bumping the major version or documenting the breaking changes.")
  }

  lines.iter().fold(init="", fn(acc, line) {
    if acc.is_empty() { line } else { acc + "\n" + line }
  })
}

/// Convert to bump type
pub fn SuggestedBump::to_bump_type(self : SuggestedBump) -> String? {
  match self {
    Major => Some("major")
    Minor => Some("minor")
    Patch => Some("patch")
    None => Option::None
  }
}
