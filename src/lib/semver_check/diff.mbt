///|
/// API change kind
// Suppress: Compatible is kept for semantic completeness (Breaking/Addition/Compatible triad)
// even though current implementation only tracks actual changes, not "no change" status.
#warnings("-unused_constructor")
pub enum ChangeKind {
  /// Breaking change (Major)
  Breaking
  /// Addition (Minor)
  Addition
  /// No change (compatible)
  Compatible
} derive(Show, Eq)

///|
/// API change
pub struct ApiChange {
  kind : ChangeKind
  category : String
  name : String
  description : String
} derive(Show)

///|
/// API diff result
pub struct ApiDiff {
  changes : Array[ApiChange]
} derive(Show)

///|
/// Create empty ApiDiff
pub fn ApiDiff::empty() -> ApiDiff {
  ApiDiff::{ changes: [] }
}

///|
/// Check if diff contains any breaking changes
pub fn ApiDiff::has_breaking(self : ApiDiff) -> Bool {
  self.changes.iter().any(fn(c) { c.kind == Breaking })
}

///|
/// Check if diff contains any additions
pub fn ApiDiff::has_additions(self : ApiDiff) -> Bool {
  self.changes.iter().any(fn(c) { c.kind == Addition })
}

///|
/// Compare two APIs and detect differences
pub fn diff_api(old_api : PackageApi, new_api : PackageApi) -> ApiDiff {
  let changes : Array[ApiChange] = []

  // Compare types
  diff_types(old_api.types, new_api.types, changes)

  // Compare error types
  diff_errors(old_api.errors, new_api.errors, changes)

  // Compare traits
  diff_traits(old_api.traits, new_api.traits, changes)

  // Compare values
  diff_values(old_api.values, new_api.values, changes)

  ApiDiff::{ changes, }
}

///|
/// Detect type differences
fn diff_types(
  old_types : Array[TypeInfo],
  new_types : Array[TypeInfo],
  changes : Array[ApiChange],
) -> Unit {
  // Index by name
  let old_map : @hashmap.HashMap[String, TypeInfo] = @hashmap.new()
  for t in old_types {
    old_map.set(t.name, t)
  }

  let new_map : @hashmap.HashMap[String, TypeInfo] = @hashmap.new()
  for t in new_types {
    new_map.set(t.name, t)
  }

  // Detect removed types
  for t in old_types {
    if new_map.get(t.name) is None {
      changes.push(ApiChange::{
        kind: Breaking,
        category: "type",
        name: t.name,
        description: "Type removed",
      })
    }
  }

  // Detect added types
  for t in new_types {
    if old_map.get(t.name) is None {
      changes.push(ApiChange::{
        kind: Addition,
        category: "type",
        name: t.name,
        description: "Type added",
      })
    }
  }

  // Detect signature changes
  for new_type in new_types {
    match old_map.get(new_type.name) {
      Some(old_type) => {
        // Compare struct/enum signature
        if old_type.signature != new_type.signature {
          changes.push(ApiChange::{
            kind: Breaking,
            category: "type",
            name: new_type.name,
            description: "Type signature changed",
          })
        }

        // Compare methods
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

///|
/// Detect error type differences
fn diff_errors(
  old_errors : Array[ErrorInfo],
  new_errors : Array[ErrorInfo],
  changes : Array[ApiChange],
) -> Unit {
  let old_map : @hashmap.HashMap[String, ErrorInfo] = @hashmap.new()
  for e in old_errors {
    old_map.set(e.name, e)
  }

  let new_map : @hashmap.HashMap[String, ErrorInfo] = @hashmap.new()
  for e in new_errors {
    new_map.set(e.name, e)
  }

  // Removed error types
  for e in old_errors {
    if new_map.get(e.name) is None {
      changes.push(ApiChange::{
        kind: Breaking,
        category: "error",
        name: e.name,
        description: "Error type removed",
      })
    }
  }

  // Added error types
  for e in new_errors {
    if old_map.get(e.name) is None {
      changes.push(ApiChange::{
        kind: Addition,
        category: "error",
        name: e.name,
        description: "Error type added",
      })
    }
  }

  // Signature changes
  for new_err in new_errors {
    match old_map.get(new_err.name) {
      Some(old_err) => {
        if old_err.signature != new_err.signature {
          changes.push(ApiChange::{
            kind: Breaking,
            category: "error",
            name: new_err.name,
            description: "Error type signature changed",
          })
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

///|
/// Detect trait differences
fn diff_traits(
  old_traits : Array[TraitInfo],
  new_traits : Array[TraitInfo],
  changes : Array[ApiChange],
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
      changes.push(ApiChange::{
        kind: Breaking,
        category: "trait",
        name: t.name,
        description: "Trait removed",
      })
    }
  }

  for t in new_traits {
    if old_map.get(t.name) is None {
      changes.push(ApiChange::{
        kind: Addition,
        category: "trait",
        name: t.name,
        description: "Trait added",
      })
    }
  }

  for new_trait in new_traits {
    match old_map.get(new_trait.name) {
      Some(old_trait) => {
        if old_trait.signature != new_trait.signature {
          changes.push(ApiChange::{
            kind: Breaking,
            category: "trait",
            name: new_trait.name,
            description: "Trait signature changed",
          })
        }
        diff_methods(
          old_trait.methods,
          new_trait.methods,
          new_trait.name,
          "trait",
          changes,
          is_trait=true,
        )
      }
      None => ()
    }
  }
}

///|
/// Detect value (top-level function) differences
fn diff_values(
  old_values : Array[ValueInfo],
  new_values : Array[ValueInfo],
  changes : Array[ApiChange],
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
      changes.push(ApiChange::{
        kind: Breaking,
        category: "value",
        name: v.name,
        description: "Value/function removed",
      })
    }
  }

  for v in new_values {
    if old_map.get(v.name) is None {
      changes.push(ApiChange::{
        kind: Addition,
        category: "value",
        name: v.name,
        description: "Value/function added",
      })
    }
  }

  for new_val in new_values {
    match old_map.get(new_val.name) {
      Some(old_val) =>
        if old_val.signature != new_val.signature {
          changes.push(ApiChange::{
            kind: Breaking,
            category: "value",
            name: new_val.name,
            description: "Value/function signature changed",
          })
        }
      None => ()
    }
  }
}

///|
/// Detect method differences
/// When is_trait is true, adding a method is a breaking change
/// (all implementors must provide the new method)
fn diff_methods(
  old_methods : Array[MethodInfo],
  new_methods : Array[MethodInfo],
  parent_name : String,
  parent_category : String,
  changes : Array[ApiChange],
  is_trait? : Bool = false,
) -> Unit {
  let old_map : @hashmap.HashMap[String, MethodInfo] = @hashmap.new()
  for m in old_methods {
    old_map.set(m.name, m)
  }

  let new_map : @hashmap.HashMap[String, MethodInfo] = @hashmap.new()
  for m in new_methods {
    new_map.set(m.name, m)
  }

  // Removed methods
  for m in old_methods {
    if new_map.get(m.name) is None {
      changes.push(ApiChange::{
        kind: Breaking,
        category: parent_category,
        name: parent_name + "::" + m.name,
        description: "Method removed",
      })
    }
  }

  // Added methods
  // For traits, adding a method is breaking (existing implementors must update)
  // Note: Adding a method with a default implementation to a trait is not actually
  // breaking, but we cannot distinguish this case without additional metadata.
  for m in new_methods {
    if old_map.get(m.name) is None {
      changes.push(ApiChange::{
        kind: if is_trait {
          Breaking
        } else {
          Addition
        },
        category: parent_category,
        name: parent_name + "::" + m.name,
        description: if is_trait {
          "Trait method added (breaking: implementors must update)"
        } else {
          "Method added"
        },
      })
    }
  }

  // Signature changes
  for new_method in new_methods {
    match old_map.get(new_method.name) {
      Some(old_method) =>
        if old_method.signature != new_method.signature {
          changes.push(ApiChange::{
            kind: Breaking,
            category: parent_category,
            name: parent_name + "::" + new_method.name,
            description: "Method signature changed",
          })
        }
      None => ()
    }
  }
}
