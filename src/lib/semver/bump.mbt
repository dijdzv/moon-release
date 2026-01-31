/// Bump type
pub(all) enum BumpType {
  Major
  Minor
  Patch
} derive(Show, Eq)

/// Bump version
pub fn bump(version : Version, typ : BumpType) -> Version {
  bump_with_prerelease(version, typ, None)
}

/// Bump version (with optional prerelease)
pub fn bump_with_prerelease(
  version : Version,
  typ : BumpType,
  prerelease : String?
) -> Version {
  match typ {
    Major =>
      Version::{
        major: version.major + 1,
        minor: 0,
        patch: 0,
        prerelease,
        build_metadata: None,
      }
    Minor =>
      Version::{
        major: version.major,
        minor: version.minor + 1,
        patch: 0,
        prerelease,
        build_metadata: None,
      }
    Patch =>
      Version::{
        major: version.major,
        minor: version.minor,
        patch: version.patch + 1,
        prerelease,
        build_metadata: None,
      }
  }
}

/// Determine bump type from commits
pub fn determine_bump(commits : Array[@conventional.ConventionalCommit]) -> BumpType? {
  determine_bump_with_custom(commits, None, None)
}

/// Determine bump type with custom rules
pub fn determine_bump_with_custom(
  commits : Array[@conventional.ConventionalCommit],
  custom_major_pattern : String?,
  custom_minor_pattern : String?
) -> BumpType? {
  let mut has_feat = false
  let mut has_fix = false

  for commit in commits {
    // Breaking change is always major
    if commit.breaking {
      return Some(Major)
    }

    // Check custom major pattern
    match custom_major_pattern {
      Some(pattern) =>
        if commit.description.contains(pattern) {
          return Some(Major)
        }
      None => ()
    }

    // Check custom minor pattern
    match custom_minor_pattern {
      Some(pattern) =>
        if commit.description.contains(pattern) {
          has_feat = true
        }
      None => ()
    }

    // Standard Conventional Commits rules
    match commit.typ {
      Feat => has_feat = true
      Fix | Perf => has_fix = true
      _ => ()
    }
  }

  if has_feat {
    Some(Minor)
  } else if has_fix {
    Some(Patch)
  } else {
    None
  }
}
