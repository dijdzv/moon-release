test "parse simple package_data.json" {
  let json =
    #|{
    #|  "name": "test/pkg",
    #|  "types": [
    #|    {
    #|      "name": "Foo",
    #|      "signature": "pub struct Foo { x : Int }",
    #|      "methods": [
    #|        { "name": "new", "signature": "fn Foo::new() -> Foo" }
    #|      ]
    #|    }
    #|  ],
    #|  "errors": [],
    #|  "traits": [],
    #|  "values": []
    #|}
  let api = try { parse_package_data(json) } catch { _ => fail("Parse failed") }
  assert_eq(api.name, "test/pkg")
  assert_eq(api.types.length(), 1)
  assert_eq(api.types[0].name, "Foo")
  assert_eq(api.types[0].methods.length(), 1)
  assert_eq(api.types[0].methods[0].name, "new")
}

test "strip html tags from signature" {
  let json =
    #|{
    #|  "name": "test/pkg",
    #|  "types": [
    #|    {
    #|      "name": "Bar",
    #|      "signature": "pub struct Bar { items : <a href=\"builtin#Array\">Array</a>[String] }",
    #|      "methods": []
    #|    }
    #|  ],
    #|  "errors": [],
    #|  "traits": [],
    #|  "values": []
    #|}
  let api = try { parse_package_data(json) } catch { _ => fail("Parse failed") }
  assert_eq(api.types[0].signature, "pub struct Bar { items : Array[String] }")
}

test "parse errors" {
  let json =
    #|{
    #|  "name": "test/pkg",
    #|  "types": [],
    #|  "errors": [
    #|    {
    #|      "name": "ConfigError",
    #|      "signature": "pub suberror ConfigError { ConfigError(String) }"
    #|    }
    #|  ],
    #|  "traits": [],
    #|  "values": []
    #|}
  let api = try { parse_package_data(json) } catch { _ => fail("Parse failed") }
  assert_eq(api.errors.length(), 1)
  assert_eq(api.errors[0].name, "ConfigError")
  assert_true(api.errors[0].signature.contains("ConfigError"))
}

test "parse traits" {
  let json =
    #|{
    #|  "name": "test/pkg",
    #|  "types": [],
    #|  "errors": [],
    #|  "traits": [
    #|    {
    #|      "name": "Printable",
    #|      "signature": "pub trait Printable { fn to_string(Self) -> String }",
    #|      "methods": [
    #|        { "name": "to_string", "signature": "fn to_string(Self) -> String" }
    #|      ]
    #|    }
    #|  ],
    #|  "values": []
    #|}
  let api = try { parse_package_data(json) } catch { _ => fail("Parse failed") }
  assert_eq(api.traits.length(), 1)
  assert_eq(api.traits[0].name, "Printable")
  assert_eq(api.traits[0].methods.length(), 1)
}

test "parse values" {
  let json =
    #|{
    #|  "name": "test/pkg",
    #|  "types": [],
    #|  "errors": [],
    #|  "traits": [],
    #|  "values": [
    #|    {
    #|      "name": "DEFAULT_VALUE",
    #|      "signature": "pub const DEFAULT_VALUE : Int = 42"
    #|    },
    #|    {
    #|      "name": "my_function",
    #|      "signature": "pub fn my_function(x: Int) -> String"
    #|    }
    #|  ]
    #|}
  let api = try { parse_package_data(json) } catch { _ => fail("Parse failed") }
  assert_eq(api.values.length(), 2)
  assert_eq(api.values[0].name, "DEFAULT_VALUE")
  assert_eq(api.values[1].name, "my_function")
}

test "merge_package_apis combines all items with prefix" {
  let api1 = PackageApi::{
    name: "pkg1",
    types: [TypeInfo::{ name: "Type1", signature: "pub struct Type1 {}", methods: [] }],
    errors: [],
    traits: [],
    values: [],
  }
  let api2 = PackageApi::{
    name: "pkg2",
    types: [TypeInfo::{ name: "Type2", signature: "pub struct Type2 {}", methods: [] }],
    errors: [ErrorInfo::{ name: "Error1", signature: "pub suberror Error1 {}", methods: [] }],
    traits: [],
    values: [],
  }

  let merged = merge_package_apis([api1, api2])
  assert_eq(merged.types.length(), 2)
  assert_eq(merged.errors.length(), 1)
  // Names should be prefixed with package path when merging multiple packages
  assert_eq(merged.types[0].name, "pkg1.Type1")
  assert_eq(merged.types[1].name, "pkg2.Type2")
  assert_eq(merged.errors[0].name, "pkg2.Error1")
}

test "merge_package_apis single package no prefix" {
  let api = PackageApi::{
    name: "pkg1",
    types: [TypeInfo::{ name: "Type1", signature: "pub struct Type1 {}", methods: [] }],
    errors: [],
    traits: [],
    values: [ValueInfo::{ name: "foo", signature: "pub fn foo() -> Unit" }],
  }

  let merged = merge_package_apis([api])
  // Single package: names should NOT be prefixed
  assert_eq(merged.types[0].name, "Type1")
  assert_eq(merged.values[0].name, "foo")
}

test "PackageApi::empty returns empty api" {
  let api = PackageApi::empty()
  assert_eq(api.name, "")
  assert_eq(api.types.length(), 0)
  assert_eq(api.errors.length(), 0)
  assert_eq(api.traits.length(), 0)
  assert_eq(api.values.length(), 0)
}
