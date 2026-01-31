/// semver チェックエラー
pub suberror SemverCheckError {
  SemverCheckError(String)
}

/// 複数の package_data.json を読み込んでマージ
pub fn merge_package_apis(apis : Array[PackageApi]) -> PackageApi {
  let merged = PackageApi::{
    name: "",
    types: [],
    errors: [],
    traits: [],
    values: [],
  }

  for api in apis {
    for t in api.types {
      merged.types.push(t)
    }
    for e in api.errors {
      merged.errors.push(e)
    }
    for t in api.traits {
      merged.traits.push(t)
    }
    for v in api.values {
      merged.values.push(v)
    }
  }

  merged
}

/// API 差分から推奨バンプタイプを取得
pub fn get_suggested_bump_from_diff(diff : ApiDiff) -> String? {
  if diff.has_breaking {
    Some("major")
  } else if diff.has_additions {
    Some("minor")
  } else if not(diff.changes.is_empty()) {
    Some("patch")
  } else {
    None
  }
}

/// チェック結果を簡潔なサマリーで出力
pub fn format_summary(result : CheckResult) -> String {
  let lines : Array[String] = []

  let breaking_count = result.diff.changes.iter().filter(fn(c) {
    c.kind == Breaking
  }).count()
  let addition_count = result.diff.changes.iter().filter(fn(c) {
    c.kind == Addition
  }).count()

  if breaking_count > 0 {
    lines.push("Breaking changes: \{breaking_count}")
  }
  if addition_count > 0 {
    lines.push("Additions: \{addition_count}")
  }

  if lines.is_empty() {
    "No API changes detected."
  } else {
    lines.iter().fold(init="", fn(acc, line) {
      if acc.is_empty() { line } else { acc + ", " + line }
    })
  }
}
