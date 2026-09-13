///|
async test "staging resolves each monorepo manifest without adding legacy files" {
  let modern = "_build/stage-manifests/modern/"
  let legacy = "_build/stage-manifests/legacy/"
  for path in [modern, legacy] {
    if !@fs.exists(path) { @fs.mkdir(path.trim_end(chars="/"), recursive=true) }
  }
  @fs.write_file(modern + "moon.mod", "name = \"x/modern\"\nversion = \"1.0.0\"\n")
  @fs.write_file(legacy + "moon.mod.json", "{\"name\":\"x/legacy\",\"version\":\"1.0.0\"}")
  let content =
    #|{"packages":[
    #| {"name":"modern","path":"_build/stage-manifests/modern","moon_publish":true,"npm_publish":false},
    #| {"name":"legacy","path":"_build/stage-manifests/legacy","moon_publish":true,"npm_publish":true}
    #|]}
  let config = @config.Config::parse(content)
  let files = resolve_files_to_stage(make_ctx(config))
  assert_eq(files, [modern + "moon.mod", legacy + "moon.mod.json", legacy + "package.json"])
  assert_true(!@fs.exists(modern + "moon.mod.json"))
  @fs.remove(modern + "moon.mod")
  @fs.remove(legacy + "moon.mod.json")
}
