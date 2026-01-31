/// バンプの種別
pub enum BumpType {
  Major
  Minor
  Patch
} derive(Show, Eq)

/// バージョンをバンプ
pub fn bump(version : Version, typ : BumpType) -> Version {
  match typ {
    Major => { ..version, major: version.major + 1, minor: 0, patch: 0, prerelease: None }
    Minor => { ..version, minor: version.minor + 1, patch: 0, prerelease: None }
    Patch => { ..version, patch: version.patch + 1, prerelease: None }
  }
}

/// コミット群からバンプタイプを決定
pub fn determine_bump(commits : Array[@conventional.ConventionalCommit]) -> BumpType? {
  let mut has_feat = false
  let mut has_fix = false
  for commit in commits {
    if commit.breaking {
      return Some(Major)
    }
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
