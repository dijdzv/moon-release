/// API 変更の種類
pub enum ChangeKind {
  /// 破壊的変更（Major）
  Breaking
  /// 機能追加（Minor）
  Addition
  /// 変更なし
  Compatible
} derive(Show, Eq)

/// API 変更
pub struct ApiChange {
  kind : ChangeKind
  category : String
  name : String
  description : String
} derive(Show)

/// API 差分結果
pub struct ApiDiff {
  changes : Array[ApiChange]
  has_breaking : Bool
  has_additions : Bool
} derive(Show)

/// 空の ApiDiff を作成
pub fn ApiDiff::empty() -> ApiDiff {
  ApiDiff::{ changes: [], has_breaking: false, has_additions: false }
}

/// 2つの API を比較して差分を検出
pub fn diff_api(old_api : PackageApi, new_api : PackageApi) -> ApiDiff {
  let changes : Array[ApiChange] = []

  // 型の比較
  diff_types(old_api.types, new_api.types, changes)

  // エラー型の比較
  diff_errors(old_api.errors, new_api.errors, changes)

  // トレイトの比較
  diff_traits(old_api.traits, new_api.traits, changes)

  // 値の比較
  diff_values(old_api.values, new_api.values, changes)

  let has_breaking = changes.iter().any(fn(c) { c.kind == Breaking })
  let has_additions = changes.iter().any(fn(c) { c.kind == Addition })

  ApiDiff::{ changes, has_breaking, has_additions }
}

/// 型の差分を検出
fn diff_types(
  old_types : Array[TypeInfo],
  new_types : Array[TypeInfo],
  changes : Array[ApiChange]
) -> Unit {
  // 名前でインデックス化
  let old_map : @hashmap.HashMap[String, TypeInfo] = @hashmap.new()
  for t in old_types {
    old_map.set(t.name, t)
  }

  let new_map : @hashmap.HashMap[String, TypeInfo] = @hashmap.new()
  for t in new_types {
    new_map.set(t.name, t)
  }

  // 削除された型を検出
  for t in old_types {
    if new_map.get(t.name) is None {
      changes.push(
        ApiChange::{
          kind: Breaking,
          category: "type",
          name: t.name,
          description: "Type removed",
        },
      )
    }
  }

  // 追加された型を検出
  for t in new_types {
    if old_map.get(t.name) is None {
      changes.push(
        ApiChange::{
          kind: Addition,
          category: "type",
          name: t.name,
          description: "Type added",
        },
      )
    }
  }

  // シグネチャの変更を検出
  for new_type in new_types {
    match old_map.get(new_type.name) {
      Some(old_type) => {
        // 構造体/enum のシグネチャ比較
        if old_type.signature != new_type.signature {
          changes.push(
            ApiChange::{
              kind: Breaking,
              category: "type",
              name: new_type.name,
              description: "Type signature changed",
            },
          )
        }

        // メソッドの比較
        diff_methods(
          old_type.methods,
          new_type.methods,
          new_type.name,
          "type",
          changes,
        )
      }
      None => ()
    }
  }
}

/// エラー型の差分を検出
fn diff_errors(
  old_errors : Array[ErrorInfo],
  new_errors : Array[ErrorInfo],
  changes : Array[ApiChange]
) -> Unit {
  let old_map : @hashmap.HashMap[String, ErrorInfo] = @hashmap.new()
  for e in old_errors {
    old_map.set(e.name, e)
  }

  let new_map : @hashmap.HashMap[String, ErrorInfo] = @hashmap.new()
  for e in new_errors {
    new_map.set(e.name, e)
  }

  // 削除されたエラー型
  for e in old_errors {
    if new_map.get(e.name) is None {
      changes.push(
        ApiChange::{
          kind: Breaking,
          category: "error",
          name: e.name,
          description: "Error type removed",
        },
      )
    }
  }

  // 追加されたエラー型
  for e in new_errors {
    if old_map.get(e.name) is None {
      changes.push(
        ApiChange::{
          kind: Addition,
          category: "error",
          name: e.name,
          description: "Error type added",
        },
      )
    }
  }

  // シグネチャの変更
  for new_err in new_errors {
    match old_map.get(new_err.name) {
      Some(old_err) => {
        if old_err.signature != new_err.signature {
          changes.push(
            ApiChange::{
              kind: Breaking,
              category: "error",
              name: new_err.name,
              description: "Error type signature changed",
            },
          )
        }
        diff_methods(
          old_err.methods,
          new_err.methods,
          new_err.name,
          "error",
          changes,
        )
      }
      None => ()
    }
  }
}

/// トレイトの差分を検出
fn diff_traits(
  old_traits : Array[TraitInfo],
  new_traits : Array[TraitInfo],
  changes : Array[ApiChange]
) -> Unit {
  let old_map : @hashmap.HashMap[String, TraitInfo] = @hashmap.new()
  for t in old_traits {
    old_map.set(t.name, t)
  }

  let new_map : @hashmap.HashMap[String, TraitInfo] = @hashmap.new()
  for t in new_traits {
    new_map.set(t.name, t)
  }

  for t in old_traits {
    if new_map.get(t.name) is None {
      changes.push(
        ApiChange::{
          kind: Breaking,
          category: "trait",
          name: t.name,
          description: "Trait removed",
        },
      )
    }
  }

  for t in new_traits {
    if old_map.get(t.name) is None {
      changes.push(
        ApiChange::{
          kind: Addition,
          category: "trait",
          name: t.name,
          description: "Trait added",
        },
      )
    }
  }

  for new_trait in new_traits {
    match old_map.get(new_trait.name) {
      Some(old_trait) => {
        if old_trait.signature != new_trait.signature {
          changes.push(
            ApiChange::{
              kind: Breaking,
              category: "trait",
              name: new_trait.name,
              description: "Trait signature changed",
            },
          )
        }
        diff_methods(
          old_trait.methods,
          new_trait.methods,
          new_trait.name,
          "trait",
          changes,
        )
      }
      None => ()
    }
  }
}

/// 値（トップレベル関数）の差分を検出
fn diff_values(
  old_values : Array[ValueInfo],
  new_values : Array[ValueInfo],
  changes : Array[ApiChange]
) -> Unit {
  let old_map : @hashmap.HashMap[String, ValueInfo] = @hashmap.new()
  for v in old_values {
    old_map.set(v.name, v)
  }

  let new_map : @hashmap.HashMap[String, ValueInfo] = @hashmap.new()
  for v in new_values {
    new_map.set(v.name, v)
  }

  for v in old_values {
    if new_map.get(v.name) is None {
      changes.push(
        ApiChange::{
          kind: Breaking,
          category: "value",
          name: v.name,
          description: "Value/function removed",
        },
      )
    }
  }

  for v in new_values {
    if old_map.get(v.name) is None {
      changes.push(
        ApiChange::{
          kind: Addition,
          category: "value",
          name: v.name,
          description: "Value/function added",
        },
      )
    }
  }

  for new_val in new_values {
    match old_map.get(new_val.name) {
      Some(old_val) => {
        if old_val.signature != new_val.signature {
          changes.push(
            ApiChange::{
              kind: Breaking,
              category: "value",
              name: new_val.name,
              description: "Value/function signature changed",
            },
          )
        }
      }
      None => ()
    }
  }
}

/// メソッドの差分を検出
fn diff_methods(
  old_methods : Array[MethodInfo],
  new_methods : Array[MethodInfo],
  parent_name : String,
  parent_category : String,
  changes : Array[ApiChange]
) -> Unit {
  let old_map : @hashmap.HashMap[String, MethodInfo] = @hashmap.new()
  for m in old_methods {
    old_map.set(m.name, m)
  }

  let new_map : @hashmap.HashMap[String, MethodInfo] = @hashmap.new()
  for m in new_methods {
    new_map.set(m.name, m)
  }

  // 削除されたメソッド
  for m in old_methods {
    if new_map.get(m.name) is None {
      changes.push(
        ApiChange::{
          kind: Breaking,
          category: parent_category,
          name: parent_name + "::" + m.name,
          description: "Method removed",
        },
      )
    }
  }

  // 追加されたメソッド
  for m in new_methods {
    if old_map.get(m.name) is None {
      changes.push(
        ApiChange::{
          kind: Addition,
          category: parent_category,
          name: parent_name + "::" + m.name,
          description: "Method added",
        },
      )
    }
  }

  // シグネチャ変更
  for new_method in new_methods {
    match old_map.get(new_method.name) {
      Some(old_method) => {
        if old_method.signature != new_method.signature {
          changes.push(
            ApiChange::{
              kind: Breaking,
              category: parent_category,
              name: parent_name + "::" + new_method.name,
              description: "Method signature changed",
            },
          )
        }
      }
      None => ()
    }
  }
}
