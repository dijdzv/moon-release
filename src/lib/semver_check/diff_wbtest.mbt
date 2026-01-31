test "detect removed type as breaking" {
  let old_api = PackageApi::{
    name: "test",
    types: [TypeInfo::{ name: "Foo", signature: "pub struct Foo {}", methods: [] }],
    errors: [],
    traits: [],
    values: [],
  }
  let new_api = PackageApi::{
    name: "test",
    types: [],
    errors: [],
    traits: [],
    values: [],
  }

  let diff = diff_api(old_api, new_api)
  assert_true(diff.has_breaking)
  assert_eq(diff.changes.length(), 1)
  assert_eq(diff.changes[0].kind, Breaking)
  assert_eq(diff.changes[0].name, "Foo")
}

test "detect added type as addition" {
  let old_api = PackageApi::{
    name: "test",
    types: [],
    errors: [],
    traits: [],
    values: [],
  }
  let new_api = PackageApi::{
    name: "test",
    types: [TypeInfo::{ name: "Bar", signature: "pub struct Bar {}", methods: [] }],
    errors: [],
    traits: [],
    values: [],
  }

  let diff = diff_api(old_api, new_api)
  assert_true(diff.has_additions)
  assert_false(diff.has_breaking)
  assert_eq(diff.changes[0].kind, Addition)
}

test "detect signature change as breaking" {
  let old_api = PackageApi::{
    name: "test",
    types: [
      TypeInfo::{
        name: "Config",
        signature: "pub struct Config { x : Int }",
        methods: [],
      },
    ],
    errors: [],
    traits: [],
    values: [],
  }
  let new_api = PackageApi::{
    name: "test",
    types: [
      TypeInfo::{
        name: "Config",
        signature: "pub struct Config { x : String }",
        methods: [],
      },
    ],
    errors: [],
    traits: [],
    values: [],
  }

  let diff = diff_api(old_api, new_api)
  assert_true(diff.has_breaking)
  assert_eq(diff.changes[0].description, "Type signature changed")
}

test "detect removed method as breaking" {
  let old_api = PackageApi::{
    name: "test",
    types: [
      TypeInfo::{
        name: "Foo",
        signature: "pub struct Foo {}",
        methods: [MethodInfo::{ name: "bar", signature: "fn Foo::bar() -> Int" }],
      },
    ],
    errors: [],
    traits: [],
    values: [],
  }
  let new_api = PackageApi::{
    name: "test",
    types: [TypeInfo::{ name: "Foo", signature: "pub struct Foo {}", methods: [] }],
    errors: [],
    traits: [],
    values: [],
  }

  let diff = diff_api(old_api, new_api)
  assert_true(diff.has_breaking)
  assert_eq(diff.changes[0].name, "Foo::bar")
}

test "no changes detected for identical APIs" {
  let api = PackageApi::{
    name: "test",
    types: [TypeInfo::{ name: "Foo", signature: "pub struct Foo {}", methods: [] }],
    errors: [],
    traits: [],
    values: [],
  }

  let diff = diff_api(api, api)
  assert_false(diff.has_breaking)
  assert_false(diff.has_additions)
  assert_eq(diff.changes.length(), 0)
}
