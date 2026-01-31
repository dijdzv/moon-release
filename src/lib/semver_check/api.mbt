/// API 情報（package_data.json から抽出）
pub struct PackageApi {
  name : String
  types : Array[TypeInfo]
  errors : Array[ErrorInfo]
  traits : Array[TraitInfo]
  values : Array[ValueInfo]
} derive(Show)

/// 空の PackageApi を作成
pub fn PackageApi::empty() -> PackageApi {
  PackageApi::{ name: "", types: [], errors: [], traits: [], values: [] }
}

/// 型情報
pub struct TypeInfo {
  name : String
  signature : String
  methods : Array[MethodInfo]
} derive(Show, Eq)

/// エラー型情報
pub struct ErrorInfo {
  name : String
  signature : String
  methods : Array[MethodInfo]
} derive(Show, Eq)

/// トレイト情報
pub struct TraitInfo {
  name : String
  signature : String
  methods : Array[MethodInfo]
} derive(Show, Eq)

/// メソッド情報
pub struct MethodInfo {
  name : String
  signature : String
} derive(Show, Eq)

/// 値（トップレベル関数など）情報
pub struct ValueInfo {
  name : String
  signature : String
} derive(Show, Eq)

/// パースエラー
pub suberror ParseError {
  ParseError(String)
}

/// シグネチャから HTML タグを除去
fn strip_html_tags(s : String) -> String {
  let result = StringBuilder::new()
  let mut in_tag = false
  for c in s {
    if c == '<' {
      in_tag = true
    } else if c == '>' {
      in_tag = false
    } else if not(in_tag) {
      result.write_char(c)
    }
  }
  result.to_string()
}

/// package_data.json をパース
pub fn parse_package_data(content : String) -> PackageApi raise ParseError {
  let json = try {
    @json.parse(content)
  } catch {
    e => raise ParseError("JSON parse error: " + e.to_string())
  }

  let obj = match json {
    Object(o) => o
    _ => raise ParseError("Expected JSON object")
  }

  let name = match obj.get("name") {
    Some(String(s)) => s
    _ => ""
  }

  let types = parse_types(obj)
  let errors = parse_errors(obj)
  let traits = parse_traits(obj)
  let values = parse_values(obj)

  PackageApi::{ name, types, errors, traits, values }
}

/// types 配列をパース
fn parse_types(obj : Map[String, Json]) -> Array[TypeInfo] raise ParseError {
  let result : Array[TypeInfo] = []
  match obj.get("types") {
    Some(Array(arr)) => {
      for item in arr {
        match item {
          Object(type_obj) => {
            let name = match type_obj.get("name") {
              Some(String(s)) => s
              _ => continue
            }
            let signature = match type_obj.get("signature") {
              Some(String(s)) => strip_html_tags(s)
              _ => ""
            }
            let methods = parse_methods(type_obj)
            result.push(TypeInfo::{ name, signature, methods })
          }
          _ => continue
        }
      }
    }
    _ => ()
  }
  result
}

/// errors 配列をパース
fn parse_errors(obj : Map[String, Json]) -> Array[ErrorInfo] raise ParseError {
  let result : Array[ErrorInfo] = []
  match obj.get("errors") {
    Some(Array(arr)) => {
      for item in arr {
        match item {
          Object(err_obj) => {
            let name = match err_obj.get("name") {
              Some(String(s)) => s
              _ => continue
            }
            let signature = match err_obj.get("signature") {
              Some(String(s)) => strip_html_tags(s)
              _ => ""
            }
            let methods = parse_methods(err_obj)
            result.push(ErrorInfo::{ name, signature, methods })
          }
          _ => continue
        }
      }
    }
    _ => ()
  }
  result
}

/// traits 配列をパース
fn parse_traits(obj : Map[String, Json]) -> Array[TraitInfo] raise ParseError {
  let result : Array[TraitInfo] = []
  match obj.get("traits") {
    Some(Array(arr)) => {
      for item in arr {
        match item {
          Object(trait_obj) => {
            let name = match trait_obj.get("name") {
              Some(String(s)) => s
              _ => continue
            }
            let signature = match trait_obj.get("signature") {
              Some(String(s)) => strip_html_tags(s)
              _ => ""
            }
            let methods = parse_methods(trait_obj)
            result.push(TraitInfo::{ name, signature, methods })
          }
          _ => continue
        }
      }
    }
    _ => ()
  }
  result
}

/// values 配列をパース
fn parse_values(obj : Map[String, Json]) -> Array[ValueInfo] raise ParseError {
  let result : Array[ValueInfo] = []
  match obj.get("values") {
    Some(Array(arr)) => {
      for item in arr {
        match item {
          Object(val_obj) => {
            let name = match val_obj.get("name") {
              Some(String(s)) => s
              _ => continue
            }
            let signature = match val_obj.get("signature") {
              Some(String(s)) => strip_html_tags(s)
              _ => ""
            }
            result.push(ValueInfo::{ name, signature })
          }
          _ => continue
        }
      }
    }
    _ => ()
  }
  result
}

/// methods 配列をパース
fn parse_methods(obj : Map[String, Json]) -> Array[MethodInfo] {
  let result : Array[MethodInfo] = []
  match obj.get("methods") {
    Some(Array(arr)) => {
      for item in arr {
        match item {
          Object(method_obj) => {
            let name = match method_obj.get("name") {
              Some(String(s)) => s
              _ => continue
            }
            let signature = match method_obj.get("signature") {
              Some(String(s)) => strip_html_tags(s)
              _ => ""
            }
            result.push(MethodInfo::{ name, signature })
          }
          _ => continue
        }
      }
    }
    _ => ()
  }
  result
}
