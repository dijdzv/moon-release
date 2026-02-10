///|
/// Conventional Commits type
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

///|
/// Structured representation of Conventional Commits
pub struct ConventionalCommit {
  typ : CommitType
  scope : String?
  description : String
  body : String?
  breaking : Bool
  footers : Array[(String, String)]
} derive(Show, Eq)
