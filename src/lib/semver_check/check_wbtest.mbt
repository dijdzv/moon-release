// CheckResult tests

test "CheckResult::new - no changes" {
  let diff = ApiDiff::empty()
  let result = CheckResult::new(diff)
  assert_true(result.is_success())
  assert_eq(result.suggested_bump, None)
  assert_eq(result.messages.length(), 0)
}

test "CheckResult::new - breaking changes suggests Major" {
  let diff = ApiDiff::{
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
  assert_false(result.is_success())
  assert_eq(result.suggested_bump, Some(@semver.BumpType::Major))
  assert_true(result.messages.length() > 0)
}

test "CheckResult::new - additions only suggests Minor" {
  let diff = ApiDiff::{
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
  assert_true(result.is_success())
  assert_eq(result.suggested_bump, Some(@semver.BumpType::Minor))
}

test "CheckResult::new - compatible changes suggests Patch" {
  let diff = ApiDiff::{
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
  assert_true(result.is_success())
  assert_eq(result.suggested_bump, Some(@semver.BumpType::Patch))
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

// suggested_bump conversion tests

test "suggested_bump - Major converts to major string" {
  let diff = ApiDiff::{
    changes: [
      ApiChange::{
        kind: Breaking,
        category: "type",
        name: "Foo",
        description: "Type removed",
      },
    ],
  }
  assert_eq(get_suggested_bump_from_diff(diff), Some("major"))
}

test "suggested_bump - Minor converts to minor string" {
  let diff = ApiDiff::{
    changes: [
      ApiChange::{
        kind: Addition,
        category: "type",
        name: "Bar",
        description: "Type added",
      },
    ],
  }
  assert_eq(get_suggested_bump_from_diff(diff), Some("minor"))
}

test "suggested_bump - Patch converts to patch string" {
  let diff = ApiDiff::{
    changes: [
      ApiChange::{
        kind: Compatible,
        category: "type",
        name: "Baz",
        description: "Compatible change",
      },
    ],
  }
  assert_eq(get_suggested_bump_from_diff(diff), Some("patch"))
}

test "suggested_bump - None converts to None" {
  let diff = ApiDiff::empty()
  assert_eq(get_suggested_bump_from_diff(diff), Option::None)
}
