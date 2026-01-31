/// semver チェック結果
pub struct CheckResult {
  success : Bool
  suggested_bump : SuggestedBump
  diff : ApiDiff
  messages : Array[String]
} derive(Show)

/// 推奨されるバージョンバンプ
pub enum SuggestedBump {
  /// 破壊的変更あり → Major
  Major
  /// 新機能追加あり → Minor
  Minor
  /// 変更なし or 互換性のある変更のみ → Patch
  Patch
  /// API 変更なし
  None
} derive(Show, Eq)

/// チェック結果を作成
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

  // メッセージを生成
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

/// 結果を表示用文字列に変換
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

/// バンプタイプに変換
pub fn SuggestedBump::to_bump_type(self : SuggestedBump) -> String? {
  match self {
    Major => Some("major")
    Minor => Some("minor")
    Patch => Some("patch")
    None => Option::None
  }
}
