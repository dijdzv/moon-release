/// バンプの種別
pub(all) enum BumpType {
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
  determine_bump_with_custom(commits, None, None)
}

/// カスタムルール付きでバンプタイプを決定
pub fn determine_bump_with_custom(
  commits : Array[@conventional.ConventionalCommit],
  custom_major_pattern : String?,
  custom_minor_pattern : String?
) -> BumpType? {
  let mut has_feat = false
  let mut has_fix = false

  for commit in commits {
    // breaking change は常に major
    if commit.breaking {
      return Some(Major)
    }

    // カスタム major パターンをチェック
    match custom_major_pattern {
      Some(pattern) =>
        if commit.description.contains(pattern) {
          return Some(Major)
        }
      None => ()
    }

    // カスタム minor パターンをチェック
    match custom_minor_pattern {
      Some(pattern) =>
        if commit.description.contains(pattern) {
          has_feat = true
        }
      None => ()
    }

    // 標準の Conventional Commits ルール
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
