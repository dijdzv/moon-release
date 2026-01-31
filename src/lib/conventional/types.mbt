/// Conventional Commits の種別
pub enum CommitType {
  Feat
  Fix
  Docs
  Style
  Refactor
  Perf
  Test
  Build
  Ci
  Chore
  Revert
  Custom(String)
} derive(Show, Eq)

/// Conventional Commits の構造化表現
pub struct ConventionalCommit {
  typ : CommitType
  scope : String?
  description : String
  body : String?
  breaking : Bool
  footers : Array[(String, String)]
} derive(Show, Eq)
