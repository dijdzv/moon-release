///|
test "parse simple feat commit" {
  let msg = "feat: add new feature"
  let result = parse(msg)
  match result {
    Some(commit) => {
      assert_eq(commit.typ, Feat)
      assert_eq(commit.scope, None)
      assert_eq(commit.description, "add new feature")
      assert_eq(commit.body, None)
      assert_eq(commit.breaking, false)
      assert_eq(commit.footers, [])
    }
    None => fail("Expected Some, got None")
  }
}

///|
test "parse commit with scope" {
  let msg = "feat(parser): add new feature"
  let result = parse(msg)
  match result {
    Some(commit) => {
      assert_eq(commit.typ, Feat)
      assert_eq(commit.scope, Some("parser"))
      assert_eq(commit.description, "add new feature")
    }
    None => fail("Expected Some, got None")
  }
}

///|
test "parse breaking change with !" {
  let msg = "feat!: breaking change"
  let result = parse(msg)
  match result {
    Some(commit) => {
      assert_eq(commit.typ, Feat)
      assert_eq(commit.breaking, true)
    }
    None => fail("Expected Some, got None")
  }
}

///|
test "parse breaking change with scope and !" {
  let msg = "feat(api)!: breaking change"
  let result = parse(msg)
  match result {
    Some(commit) => {
      assert_eq(commit.typ, Feat)
      assert_eq(commit.scope, Some("api"))
      assert_eq(commit.breaking, true)
    }
    None => fail("Expected Some, got None")
  }
}

///|
test "parse fix commit" {
  let msg = "fix: correct bug"
  let result = parse(msg)
  match result {
    Some(commit) => {
      assert_eq(commit.typ, Fix)
      assert_eq(commit.description, "correct bug")
    }
    None => fail("Expected Some, got None")
  }
}

///|
test "parse various commit types" {
  let test_cases : Array[(String, CommitType)] = [
    ("docs: update readme", Docs),
    ("style: format code", Style),
    ("refactor: simplify logic", Refactor),
    ("perf: optimize query", Perf),
    ("test: add unit tests", Test),
    ("build: update deps", Build),
    ("ci: fix pipeline", Ci),
    ("chore: cleanup", Chore),
    ("revert: undo change", Revert),
  ]
  for i = 0; i < test_cases.length(); i = i + 1 {
    let (msg, expected_type) = test_cases[i]
    let result = parse(msg)
    match result {
      Some(commit) => assert_eq(commit.typ, expected_type)
      None => fail("Expected Some, got None for: " + msg)
    }
  }
}

///|
test "parse custom commit type" {
  let msg = "wip: work in progress"
  let result = parse(msg)
  match result {
    Some(commit) =>
      match commit.typ {
        Custom(t) => assert_eq(t, "wip")
        _ => fail("Expected Custom type")
      }
    None => fail("Expected Some, got None")
  }
}

///|
test "parse commit with body" {
  let msg = "feat: add feature\n\nThis is the body text.\nIt can span multiple lines."
  let result = parse(msg)
  match result {
    Some(commit) =>
      assert_eq(
        commit.body,
        Some("This is the body text.\nIt can span multiple lines."),
      )
    None => fail("Expected Some, got None")
  }
}

///|
test "parse commit with BREAKING CHANGE footer" {
  let msg = "feat: add feature\n\nSome body.\n\nBREAKING CHANGE: API changed"
  let result = parse(msg)
  match result {
    Some(commit) => {
      assert_eq(commit.breaking, true)
      assert_eq(commit.footers.length(), 1)
      assert_eq(commit.footers[0], ("BREAKING CHANGE", "API changed"))
    }
    None => fail("Expected Some, got None")
  }
}

///|
test "parse commit with multiple footers" {
  let msg = "fix: correct issue\n\nBody text.\n\nFixes #123\nReviewed-by: John"
  let result = parse(msg)
  match result {
    Some(commit) => assert_eq(commit.footers.length(), 2)
    None => fail("Expected Some, got None")
  }
}

///|
test "parse invalid - empty message" {
  let msg = ""
  let result = parse(msg)
  assert_eq(result, None)
}

///|
test "parse invalid - no colon" {
  let msg = "feat add feature"
  let result = parse(msg)
  assert_eq(result, None)
}

///|
test "parse invalid - no description" {
  let msg = "feat: "
  let result = parse(msg)
  assert_eq(result, None)
}

// M-5: Empty type string should return None

///|
test "parse invalid - empty type" {
  let msg = ": some description"
  let result = parse(msg)
  assert_eq(result, None)
}

// H-3: Multibyte character support

///|
test "parse commit with multibyte description" {
  let msg = "feat: 日本語の説明"
  let result = parse(msg)
  match result {
    Some(commit) => {
      assert_eq(commit.typ, Feat)
      assert_eq(commit.description, "日本語の説明")
    }
    None => fail("Expected Some, got None")
  }
}

///|
test "parse commit with multibyte scope" {
  let msg = "feat(コア): add feature"
  let result = parse(msg)
  match result {
    Some(commit) => {
      assert_eq(commit.typ, Feat)
      assert_eq(commit.scope, Some("コア"))
      assert_eq(commit.description, "add feature")
    }
    None => fail("Expected Some, got None")
  }
}

// L-6: Trailing empty lines in body should be trimmed

///|
test "parse commit with trailing empty lines in body" {
  let msg = "feat: add feature\n\nThis is the body.\n\n\n"
  let result = parse(msg)
  match result {
    Some(commit) => assert_eq(commit.body, Some("This is the body."))
    None => fail("Expected Some, got None")
  }
}

///|
test "parse commit with trailing empty lines before footer" {
  let msg = "feat: add feature\n\nBody text.\n\n\n\nFixes #123"
  let result = parse(msg)
  match result {
    Some(commit) => {
      assert_eq(commit.body, Some("Body text."))
      assert_eq(commit.footers.length(), 1)
    }
    None => fail("Expected Some, got None")
  }
}
