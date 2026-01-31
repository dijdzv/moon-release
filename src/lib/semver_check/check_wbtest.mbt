// CheckResult tests

test "CheckResult::new - no changes" {
  let diff = ApiDiff::empty()
  let result = CheckResult::new(diff)
  assert_true(result.success)
  assert_eq(result.suggested_bump, None)
  assert_eq(result.messages.length(), 0)
}

test "CheckResult::new - breaking changes suggests Major" {
  let diff = ApiDiff::{
    has_breaking: true,
    has_additions: false,
    changes: [
      ApiChange::{
        kind: Breaking,
        category: "type",
        name: "Foo",
        description: "Type removed",
      },
    ],
  }
  let result = CheckResult::new(diff)
  assert_false(result.success)
  assert_eq(result.suggested_bump, Major)
  assert_true(result.messages.length() > 0)
}

test "CheckResult::new - additions only suggests Minor" {
  let diff = ApiDiff::{
    has_breaking: false,
    has_additions: true,
    changes: [
      ApiChange::{
        kind: Addition,
        category: "type",
        name: "Bar",
        description: "Type added",
      },
    ],
  }
  let result = CheckResult::new(diff)
  assert_true(result.success)
  assert_eq(result.suggested_bump, Minor)
}

test "CheckResult::new - compatible changes suggests Patch" {
  let diff = ApiDiff::{
    has_breaking: false,
    has_additions: false,
    changes: [
      ApiChange::{
        kind: Compatible,
        category: "type",
        name: "Baz",
        description: "Documentation updated",
      },
    ],
  }
  let result = CheckResult::new(diff)
  assert_true(result.success)
  assert_eq(result.suggested_bump, Patch)
}

test "CheckResult::format - no changes" {
  let diff = ApiDiff::empty()
  let result = CheckResult::new(diff)
  let formatted = result.format()
  assert_true(formatted.contains("No API changes detected"))
  assert_true(formatted.contains("NONE"))
}

test "CheckResult::format - breaking changes" {
  let diff = ApiDiff::{
    has_breaking: true,
    has_additions: false,
    changes: [
      ApiChange::{
        kind: Breaking,
        category: "type",
        name: "Config",
        description: "Type removed",
      },
    ],
  }
  let result = CheckResult::new(diff)
  let formatted = result.format()
  assert_true(formatted.contains("MAJOR"))
  assert_true(formatted.contains("WARNING"))
  assert_true(formatted.contains("Breaking changes"))
}

test "CheckResult::format - additions" {
  let diff = ApiDiff::{
    has_breaking: false,
    has_additions: true,
    changes: [
      ApiChange::{
        kind: Addition,
        category: "function",
        name: "new_func",
        description: "Function added",
      },
    ],
  }
  let result = CheckResult::new(diff)
  let formatted = result.format()
  assert_true(formatted.contains("MINOR"))
  assert_true(formatted.contains("API changes: 1"))
}

// SuggestedBump tests

test "SuggestedBump::to_bump_type - Major" {
  assert_eq(Major.to_bump_type(), Some("major"))
}

test "SuggestedBump::to_bump_type - Minor" {
  assert_eq(Minor.to_bump_type(), Some("minor"))
}

test "SuggestedBump::to_bump_type - Patch" {
  assert_eq(Patch.to_bump_type(), Some("patch"))
}

test "SuggestedBump::to_bump_type - None" {
  assert_eq(SuggestedBump::None.to_bump_type(), Option::None)
}
