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
  assert_true(diff.has_breaking())
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
  assert_true(diff.has_additions())
  assert_false(diff.has_breaking())
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
  assert_true(diff.has_breaking())
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
  assert_true(diff.has_breaking())
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
  assert_false(diff.has_breaking())
  assert_false(diff.has_additions())
  assert_eq(diff.changes.length(), 0)
}

test "detect removed error as breaking" {
  let old_api = PackageApi::{
    name: "test",
    types: [],
    errors: [ErrorInfo::{ name: "MyError", signature: "pub suberror MyError {}", methods: [] }],
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
  assert_true(diff.has_breaking())
  assert_eq(diff.changes[0].name, "MyError")
}

test "detect added error as addition" {
  let old_api = PackageApi::empty()
  let new_api = PackageApi::{
    name: "test",
    types: [],
    errors: [ErrorInfo::{ name: "NewError", signature: "pub suberror NewError {}", methods: [] }],
    traits: [],
    values: [],
  }

  let diff = diff_api(old_api, new_api)
  assert_true(diff.has_additions())
  assert_false(diff.has_breaking())
}

test "detect removed trait as breaking" {
  let old_api = PackageApi::{
    name: "test",
    types: [],
    errors: [],
    traits: [TraitInfo::{ name: "MyTrait", signature: "pub trait MyTrait {}", methods: [] }],
    values: [],
  }
  let new_api = PackageApi::empty()

  let diff = diff_api(old_api, new_api)
  assert_true(diff.has_breaking())
  assert_eq(diff.changes[0].name, "MyTrait")
}

test "detect removed value as breaking" {
  let old_api = PackageApi::{
    name: "test",
    types: [],
    errors: [],
    traits: [],
    values: [ValueInfo::{ name: "MY_CONST", signature: "pub const MY_CONST : Int = 42" }],
  }
  let new_api = PackageApi::empty()

  let diff = diff_api(old_api, new_api)
  assert_true(diff.has_breaking())
  assert_eq(diff.changes[0].name, "MY_CONST")
}

test "detect value signature change as breaking" {
  let old_api = PackageApi::{
    name: "test",
    types: [],
    errors: [],
    traits: [],
    values: [ValueInfo::{ name: "func", signature: "pub fn func(x: Int) -> Int" }],
  }
  let new_api = PackageApi::{
    name: "test",
    types: [],
    errors: [],
    traits: [],
    values: [ValueInfo::{ name: "func", signature: "pub fn func(x: String) -> Int" }],
  }

  let diff = diff_api(old_api, new_api)
  assert_true(diff.has_breaking())
  assert_eq(diff.changes[0].description, "Value/function signature changed")
}

test "detect added method as addition" {
  let old_api = PackageApi::{
    name: "test",
    types: [TypeInfo::{ name: "Foo", signature: "pub struct Foo {}", methods: [] }],
    errors: [],
    traits: [],
    values: [],
  }
  let new_api = PackageApi::{
    name: "test",
    types: [
      TypeInfo::{
        name: "Foo",
        signature: "pub struct Foo {}",
        methods: [MethodInfo::{ name: "new_method", signature: "fn Foo::new_method() -> Int" }],
      },
    ],
    errors: [],
    traits: [],
    values: [],
  }

  let diff = diff_api(old_api, new_api)
  assert_true(diff.has_additions())
  assert_false(diff.has_breaking())
  assert_eq(diff.changes[0].name, "Foo::new_method")
}

test "detect added trait method as breaking" {
  let old_api = PackageApi::{
    name: "test",
    types: [],
    errors: [],
    traits: [
      TraitInfo::{
        name: "MyTrait",
        signature: "pub trait MyTrait {}",
        methods: [MethodInfo::{ name: "existing", signature: "fn existing() -> Int" }],
      },
    ],
    values: [],
  }
  let new_api = PackageApi::{
    name: "test",
    types: [],
    errors: [],
    traits: [
      TraitInfo::{
        name: "MyTrait",
        signature: "pub trait MyTrait {}",
        methods: [
          MethodInfo::{ name: "existing", signature: "fn existing() -> Int" },
          MethodInfo::{ name: "new_method", signature: "fn new_method() -> String" },
        ],
      },
    ],
    values: [],
  }

  let diff = diff_api(old_api, new_api)
  assert_true(diff.has_breaking())
  assert_eq(diff.changes[0].kind, Breaking)
  assert_eq(diff.changes[0].name, "MyTrait::new_method")
}

test "detect added type method as addition (not breaking)" {
  let old_api = PackageApi::{
    name: "test",
    types: [TypeInfo::{ name: "Foo", signature: "pub struct Foo {}", methods: [] }],
    errors: [],
    traits: [],
    values: [],
  }
  let new_api = PackageApi::{
    name: "test",
    types: [
      TypeInfo::{
        name: "Foo",
        signature: "pub struct Foo {}",
        methods: [MethodInfo::{ name: "new_method", signature: "fn Foo::new_method() -> Int" }],
      },
    ],
    errors: [],
    traits: [],
    values: [],
  }

  let diff = diff_api(old_api, new_api)
  assert_true(diff.has_additions())
  assert_false(diff.has_breaking())
  assert_eq(diff.changes[0].kind, Addition)
}

test "detect method signature change as breaking" {
  let old_api = PackageApi::{
    name: "test",
    types: [
      TypeInfo::{
        name: "Foo",
        signature: "pub struct Foo {}",
        methods: [MethodInfo::{ name: "bar", signature: "fn Foo::bar(x: Int) -> Int" }],
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
        name: "Foo",
        signature: "pub struct Foo {}",
        methods: [MethodInfo::{ name: "bar", signature: "fn Foo::bar(x: String) -> Int" }],
      },
    ],
    errors: [],
    traits: [],
    values: [],
  }

  let diff = diff_api(old_api, new_api)
  assert_true(diff.has_breaking())
  assert_eq(diff.changes[0].name, "Foo::bar")
  assert_eq(diff.changes[0].description, "Method signature changed")
}
