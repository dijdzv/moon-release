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
