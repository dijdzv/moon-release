/// JSON 文字列をエスケープ
/// RFC 8259 に準拠したエスケープ処理
pub fn escape_json_string(s : String) -> String {
  let result = StringBuilder::new()
  for c in s {
    match c {
      '"' => result.write_string("\\\"")
      '\\' => result.write_string("\\\\")
      '\n' => result.write_string("\\n")
      '\r' => result.write_string("\\r")
      '\t' => result.write_string("\\t")
      '\u0008' => result.write_string("\\b")  // バックスペース
      '\u000C' => result.write_string("\\f")  // フォームフィード
      _ =>
        // 制御文字 (U+0000 - U+001F) は \uXXXX 形式でエスケープ
        if c.to_uint() < 0x20 {
          result.write_string("\\u00")
          let code = c.to_uint()
          let high = (code >> 4) & 0xF
          let low = code & 0xF
          result.write_char(hex_digit(high))
          result.write_char(hex_digit(low))
        } else {
          result.write_char(c)
        }
    }
  }
  result.to_string()
}

/// 数値を16進数の文字に変換
fn hex_digit(n : UInt) -> Char {
  match n {
    0 => '0'
    1 => '1'
    2 => '2'
    3 => '3'
    4 => '4'
    5 => '5'
    6 => '6'
    7 => '7'
    8 => '8'
    9 => '9'
    10 => 'a'
    11 => 'b'
    12 => 'c'
    13 => 'd'
    14 => 'e'
    _ => 'f'
  }
}

/// JSON 文字列リテラルを作成（クォート付き）
pub fn json_string(s : String) -> String {
  "\"" + escape_json_string(s) + "\""
}

/// JSON オブジェクトを構築
/// Keys are escaped to prevent injection attacks
pub fn build_json_object(pairs : Array[(String, String)]) -> String {
  let result = StringBuilder::new()
  result.write_string("{")
  for i = 0; i < pairs.length(); i = i + 1 {
    let (key, value) = pairs[i]
    if i > 0 {
      result.write_string(",")
    }
    result.write_string("\"")
    result.write_string(escape_json_string(key))
    result.write_string("\":")
    result.write_string(value)
  }
  result.write_string("}")
  result.to_string()
}

/// JSON 配列を構築
pub fn build_json_array(items : Array[String]) -> String {
  let result = StringBuilder::new()
  result.write_string("[")
  for i = 0; i < items.length(); i = i + 1 {
    if i > 0 {
      result.write_string(",")
    }
    result.write_string(items[i])
  }
  result.write_string("]")
  result.to_string()
}
