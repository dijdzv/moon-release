///|
async test "manifest resolution rejects ambiguity and preserves the chosen format" {
  let prefix = "_build/manifest-resolution-test/"
  if !@fs.exists(prefix) { @fs.mkdir(prefix.trim_end(chars="/"), recursive=true) }
  for name in ["moon.mod", "moon.mod.json"] {
    if @fs.exists(prefix + name) { @fs.remove(prefix + name) }
  }
  try resolve_path(prefix) catch { _ => () } noraise { _ => fail("expected missing manifest error") }
  @fs.write_file(prefix + "moon.mod.json", "{\"name\":\"x/y\",\"version\":\"1.0.0\"}")
  assert_eq(resolve_path(prefix), prefix + "moon.mod.json")
  @fs.write_file(prefix + "moon.mod", "name = \"x/y\"\nversion = \"1.0.0\"\n")
  try resolve_path(prefix) catch { _ => () } noraise { _ => fail("expected ambiguous manifest error") }
  @fs.remove(prefix + "moon.mod.json")
  let path = resolve_path(prefix)
  assert_eq(path, prefix + "moon.mod")
  let source = @fs.read_file(path).text()
  @fs.write_file(path, update_version(source, @semver.Version::parse("1.1.0").unwrap()))
  assert_eq(parse(@fs.read_file(path).text()).version, "1.1.0")
  assert_true(!@fs.exists(prefix + "moon.mod.json"))
  @fs.remove(path)
}
