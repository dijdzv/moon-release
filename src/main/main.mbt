/// moon-release CLI
/// リリース自動化ツール

/// バージョン
let version : String = "0.1.0"

/// CLI パーサーを作成
fn create_parser() -> @clap.Parser {
  @clap.Parser::new(
    prog="moon-release",
    description="Automated release management tool for MoonBit",
    args={
      "dry-run": @clap.Arg::flag(
        short='n',
        global=true,
        help="Show what would be done without making changes",
      ),
      "verbose": @clap.Arg::flag(
        short='v',
        global=true,
        help="Enable verbose output",
      ),
      "config": @clap.Arg::named(
        short='c',
        nargs=@clap.One,
        defaults=["release.json"],
        global=true,
        help="Path to config file",
      ),
    },
    subcmds={
      "update": @clap.SubCommand::new(
        help="Update version locally (no commit/push)",
        args={
          "dry-run": @clap.Arg::flag(
            short='n',
            help="Show what would be done without making changes",
          ),
          "bump": @clap.Arg::named(
            short='b',
            nargs=@clap.AtMost(1),
            help="Force a specific version bump (major, minor, patch)",
          ),
          "packages": @clap.Arg::flag(
            short='p',
            help="Update all packages in monorepo mode",
          ),
          "output": @clap.Arg::named(
            short='o',
            nargs=@clap.One,
            defaults=["text"],
            help="Output format (text, json)",
          ),
        },
      ),
      "release-pr": @clap.SubCommand::new(
        help="Create a release pull request",
        args={
          "dry-run": @clap.Arg::flag(
            short='n',
            help="Show what would be done without making changes",
          ),
          "bump": @clap.Arg::named(
            short='b',
            nargs=@clap.AtMost(1),
            help="Force a specific version bump (major, minor, patch)",
          ),
        },
      ),
      "release": @clap.SubCommand::new(
        help="Create a release (tag and GitHub release)",
        args={
          "dry-run": @clap.Arg::flag(
            short='n',
            help="Show what would be done without making changes",
          ),
          "bump": @clap.Arg::named(
            short='b',
            nargs=@clap.AtMost(1),
            help="Force a specific version bump (major, minor, patch)",
          ),
          "prerelease": @clap.Arg::named(
            short='p',
            nargs=@clap.AtMost(1),
            help="Create a prerelease with the given identifier (e.g., alpha, beta, rc)",
          ),
        },
      ),
      "init": @clap.SubCommand::new(
        help="Initialize release configuration",
        args={
          "force": @clap.Arg::flag(
            short='f',
            help="Overwrite existing configuration",
          ),
        },
      ),
      "version": @clap.SubCommand::new(help="Show version information"),
      "check": @clap.SubCommand::new(
        help="Check the current state without making changes",
        args={
          "output": @clap.Arg::named(
            short='o',
            nargs=@clap.One,
            defaults=["text"],
            help="Output format (text, json)",
          ),
        },
      ),
      "set-version": @clap.SubCommand::new(
        help="Set the package version manually",
        args={
          "dry-run": @clap.Arg::flag(
            short='n',
            help="Show what would be done without making changes",
          ),
          "version": @clap.Arg::positional(
            nargs=@clap.One,
            help="The version to set (e.g., 1.2.3)",
          ),
        },
      ),
      "generate-completions": @clap.SubCommand::new(
        help="Generate shell completion script",
        args={
          "shell": @clap.Arg::positional(
            nargs=@clap.One,
            help="Shell to generate completions for (bash, zsh, fish)",
          ),
        },
      ),
      "generate-schema": @clap.SubCommand::new(
        help="Generate JSON Schema for release.json configuration",
      ),
    },
  )
}

/// メイン関数 (async)
async fn main {
  let parser = create_parser()
  let value = @clap.SimpleValue::new("moon-release")

  // コマンドライン引数を取得（プログラム名をスキップ）
  let all_args = @env.args()
  let args : Array[String] = []
  for i = 1; i < all_args.length(); i = i + 1 {
    args.push(all_args[i])
  }

  // パース
  let help_message = try {
    parser.parse(value, args[:])
  } catch {
    e => {
      println("Error: " + e.to_string())
      return
    }
  }

  // ヘルプメッセージが返された場合は表示して終了
  match help_message {
    Some(msg) => {
      println(msg)
      return
    }
    None => ()
  }

  // グローバルオプション
  let dry_run = match value.get_flag("dry-run") {
    Some(v) => v
    None => false
  }
  let verbose = match value.get_flag("verbose") {
    Some(v) => v
    None => false
  }
  let config_path : String = try {
    value.get_one("config")
  } catch {
    _ => "release.json"
  }

  // サブコマンドの処理
  match value.subcmd {
    Some(subcmd) =>
      match subcmd.name {
        "update" => cmd_update(subcmd, dry_run, verbose, config_path)
        "release-pr" => cmd_release_pr(subcmd, dry_run, verbose, config_path)
        "release" => cmd_release(subcmd, dry_run, verbose, config_path)
        "init" => cmd_init(subcmd, dry_run, verbose)
        "version" => cmd_version()
        "check" => cmd_check(subcmd, dry_run, verbose, config_path)
        "set-version" => cmd_set_version(subcmd, dry_run, verbose)
        "generate-completions" => cmd_generate_completions(subcmd)
        "generate-schema" => cmd_generate_schema()
        _ => println("Unknown command: " + subcmd.name)
      }
    None => {
      println("moon-release v" + version)
      println("")
      println("Use --help for usage information")
    }
  }
}

/// update コマンド
async fn cmd_update(
  subcmd : @clap.SimpleValue,
  global_dry_run : Bool,
  verbose : Bool,
  config_path : String
) -> Unit {
  // サブコマンドのフラグも確認
  let subcmd_dry_run = match subcmd.get_flag("dry-run") {
    Some(v) => v
    None => false
  }
  let dry_run = global_dry_run || subcmd_dry_run
  let output_format : String = try {
    subcmd.get_one("output")
  } catch {
    _ => "text"
  }
  let json_output = output_format == "json"

  if verbose && not(json_output) {
    println("Running update command...")
    println("  Config: " + config_path)
    println("  Dry run: " + dry_run.to_string())
  }

  // 設定を読み込む
  let config = load_config(config_path)
  let repo = @git.Repository::current()

  // dirty チェック
  if should_abort_dirty(config, repo, verbose) {
    if json_output {
      println("{\"error\": \"uncommitted changes in working directory\"}")
    }
    return
  }

  // モノレポモードかチェック
  let packages_mode = match subcmd.get_flag("packages") {
    Some(v) => v
    None => false
  }

  // モノレポモードの場合は各パッケージを個別に更新（JSON未対応）
  if packages_mode || not(config.packages.is_empty()) {
    try {
      @workflow.run_update_packages(config, repo, dry_run, verbose)
    } catch {
      e => {
        if json_output {
          println("{\"error\": \"" + escape_json_string(e.to_string()) + "\"}")
        } else {
          println("Error: " + e.to_string())
        }
      }
    }
    return
  }

  // 現在のバージョンを取得
  let moon_mod = try {
    load_moon_mod("moon.mod.json")
  } catch {
    e => {
      if json_output {
        println("{\"error\": \"" + escape_json_string(e.to_string()) + "\"}")
      } else {
        println("Error: " + e.to_string())
      }
      return
    }
  }

  let current_version = match @semver.Version::parse(moon_mod.version) {
    Some(v) => v
    None => {
      if json_output {
        println("{\"error\": \"invalid version in moon.mod.json\"}")
      } else {
        println("Error: Invalid version in moon.mod.json: " + moon_mod.version)
        println("Hint: Version should follow semver format (e.g., 1.2.3 or 1.2.3-alpha)")
      }
      return
    }
  }

  // コミットを解析
  let commits = try {
    get_commits_since_last_tag(repo, max_commits=config.max_analyze_commits)
  } catch {
    e => {
      if json_output {
        println("{\"error\": \"" + escape_json_string(e.to_string()) + "\"}")
      } else {
        println("Error getting commits: " + e.to_string())
        println("Hint: Make sure you are in a git repository with at least one commit")
      }
      return
    }
  }

  if commits.is_empty() {
    if json_output {
      println("{\"error\": \"no commits found since last tag\"}")
    } else {
      println("No commits found since last tag. Nothing to release.")
      println("Hint: Create new commits or use 'moon-release set-version' to set version manually")
    }
    return
  }

  // バンプタイプを決定
  let forced_bump = get_bump_type(subcmd)
  let bump_type = match forced_bump {
    Some(t) => t
    None =>
      match @semver.determine_bump_with_custom(
        commits.map(fn(c) { c.0 }),
        config.custom_major_increment_regex,
        config.custom_minor_increment_regex,
      ) {
        Some(t) => t
        None => {
          if json_output {
            println("{\"error\": \"no releasable commits found\"}")
          } else {
            println("No releasable commits found (no feat, fix, or breaking changes)")
            println("Hint: Use Conventional Commits (feat:, fix:) or --bump to force a version bump")
          }
          return
        }
      }
  }

  // 新しいバージョンを計算
  let new_version = @semver.bump(current_version, bump_type)

  // レジストリチェック（有効な場合）
  if config.registry_check {
    let should_rel = try {
      @workflow.should_release(new_version, moon_mod.name, verbose)
    } catch {
      e => {
        if verbose && not(json_output) {
          println("Warning: Registry check failed: " + e.to_string())
        }
        true // エラーの場合はリリースを続行
      }
    }

    if not(should_rel) {
      if json_output {
        println("{\"error\": \"version not newer than registry\"}")
      } else {
        println(
          "Version \{new_version.to_string()} is not newer than registry version. Nothing to update.",
        )
      }
      return
    }
  }

  // コンテキストを作成
  let ctx = @workflow.ReleaseContext::new(
    config,
    repo,
    current_version,
    new_version,
    commits,
    dry_run~,
    verbose~,
  )

  // ワークフローを実行
  try {
    @workflow.run_update(ctx)
    // JSON 出力
    if json_output {
      let bump_str = match bump_type {
        @semver.Major => "major"
        @semver.Minor => "minor"
        @semver.Patch => "patch"
      }
      let json_str = build_json_object([
        ("old_version", json_string(current_version.to_string())),
        ("new_version", json_string(new_version.to_string())),
        ("bump_type", json_string(bump_str)),
        ("commits_count", commits.length().to_string()),
        ("dry_run", dry_run.to_string()),
        ("updated_files", "[\"moon.mod.json\"]"),
      ])
      println(json_str)
    }
  } catch {
    e => {
      if json_output {
        println("{\"error\": " + json_string(e.to_string()) + "}")
      } else {
        println("Error: " + e.to_string())
      }
    }
  }
}

/// release-pr コマンド
async fn cmd_release_pr(
  subcmd : @clap.SimpleValue,
  global_dry_run : Bool,
  verbose : Bool,
  config_path : String
) -> Unit {
  // サブコマンドのフラグも確認
  let subcmd_dry_run = match subcmd.get_flag("dry-run") {
    Some(v) => v
    None => false
  }
  let dry_run = global_dry_run || subcmd_dry_run

  if verbose {
    println("Running release-pr command...")
    println("  Config: " + config_path)
    println("  Dry run: " + dry_run.to_string())
  }

  // 設定を読み込む
  let config = load_config(config_path)
  let repo = @git.Repository::current()

  // dirty チェック
  if should_abort_dirty(config, repo, verbose) {
    return
  }

  // 現在のバージョンを取得
  let moon_mod = try {
    load_moon_mod("moon.mod.json")
  } catch {
    e => {
      println("Error: " + e.to_string())
      return
    }
  }

  let current_version = match @semver.Version::parse(moon_mod.version) {
    Some(v) => v
    None => {
      println("Error: Invalid version in moon.mod.json: " + moon_mod.version)
      println("Hint: Version should follow semver format (e.g., 1.2.3)")
      return
    }
  }

  // コミットを解析
  let commits = try {
    get_commits_since_last_tag(repo, max_commits=config.max_analyze_commits)
  } catch {
    e => {
      println("Error getting commits: " + e.to_string())
      println("Hint: Make sure you are in a git repository with at least one commit")
      return
    }
  }

  if commits.is_empty() {
    println("No commits found since last tag. Nothing to release.")
    return
  }

  // バンプタイプを決定
  let forced_bump = get_bump_type(subcmd)
  let bump_type = match forced_bump {
    Some(t) => t
    None =>
      match @semver.determine_bump_with_custom(
        commits.map(fn(c) { c.0 }),
        config.custom_major_increment_regex,
        config.custom_minor_increment_regex,
      ) {
        Some(t) => t
        None => {
          println("No releasable commits found")
          println("Hint: Use Conventional Commits or --bump to force a version bump")
          return
        }
      }
  }

  // 新しいバージョンを計算
  let new_version = @semver.bump(current_version, bump_type)

  // コンテキストを作成
  let ctx = @workflow.ReleaseContext::new(
    config,
    repo,
    current_version,
    new_version,
    commits,
    dry_run~,
    verbose~,
  )

  // GitHub クライアントを取得
  let github = try {
    get_github_client()
  } catch {
    e => {
      println("Error: " + e.to_string())
      println("Hint: Make sure gh CLI is installed and you're logged in (gh auth login)")
      return
    }
  }

  // ワークフローを実行
  try {
    @workflow.run_release_pr(ctx, github)
  } catch {
    e => println("Error: " + e.to_string())
  }
}

/// release コマンド
async fn cmd_release(
  subcmd : @clap.SimpleValue,
  global_dry_run : Bool,
  verbose : Bool,
  config_path : String
) -> Unit {
  // サブコマンドのフラグも確認
  let subcmd_dry_run = match subcmd.get_flag("dry-run") {
    Some(v) => v
    None => false
  }
  let dry_run = global_dry_run || subcmd_dry_run

  if verbose {
    println("Running release command...")
    println("  Config: " + config_path)
    println("  Dry run: " + dry_run.to_string())
  }

  // 設定を読み込む
  let config = load_config(config_path)
  let repo = @git.Repository::current()

  // dirty チェック
  if should_abort_dirty(config, repo, verbose) {
    return
  }

  // 現在のバージョンを取得
  let moon_mod = try {
    load_moon_mod("moon.mod.json")
  } catch {
    e => {
      println("Error: " + e.to_string())
      return
    }
  }

  let current_version = match @semver.Version::parse(moon_mod.version) {
    Some(v) => v
    None => {
      println("Error: Invalid version in moon.mod.json: " + moon_mod.version)
      println("Hint: Version should follow semver format (e.g., 1.2.3)")
      return
    }
  }

  // コミットを解析
  let commits = try {
    get_commits_since_last_tag(repo, max_commits=config.max_analyze_commits)
  } catch {
    e => {
      println("Error getting commits: " + e.to_string())
      println("Hint: Make sure you are in a git repository")
      return
    }
  }

  // バンプタイプを決定
  let forced_bump = get_bump_type(subcmd)
  let bump_type = match forced_bump {
    Some(t) => t
    None =>
      match @semver.determine_bump_with_custom(
        commits.map(fn(c) { c.0 }),
        config.custom_major_increment_regex,
        config.custom_minor_increment_regex,
      ) {
        Some(t) => t
        None => @semver.Patch // デフォルトは patch
      }
  }

  // prerelease 識別子を取得
  let prerelease : String? = try {
    Some(subcmd.get_one("prerelease"))
  } catch {
    _ => None
  }

  // prerelease が指定されているが、config で許可されていない場合はエラー
  if prerelease is Some(_) && not(config.allow_prerelease) {
    println("Error: Prerelease is not allowed in configuration.")
    println("Hint: Set 'allow_prerelease: true' in release.json to enable prereleases")
    return
  }

  // 新しいバージョンを計算
  let new_version = @semver.bump_with_prerelease(current_version, bump_type, prerelease)

  // コンテキストを作成
  let ctx = @workflow.ReleaseContext::new(
    config,
    repo,
    current_version,
    new_version,
    commits,
    dry_run~,
    verbose~,
  )

  // GitHub クライアントを取得
  let github = try {
    get_github_client()
  } catch {
    e => {
      println("Error: " + e.to_string())
      println("Hint: Make sure gh CLI is installed and you're logged in (gh auth login)")
      return
    }
  }

  // ワークフローを実行
  try {
    @workflow.run_release(ctx, github)
  } catch {
    e => println("Error: " + e.to_string())
  }
}

/// init コマンド
async fn cmd_init(
  subcmd : @clap.SimpleValue,
  dry_run : Bool,
  _verbose : Bool
) -> Unit {
  let force = match subcmd.get_flag("force") {
    Some(v) => v
    None => false
  }

  println("Initializing release configuration...")

  // ファイルが既に存在するかチェック
  let file_exists = try {
    let _ = @fs.read_file("release.json")
    true
  } catch {
    _ => false
  }

  if file_exists && not(force) {
    println("release.json already exists. Use --force to overwrite.")
    return
  }

  if dry_run {
    println("Would create: release.json")
    return
  }

  // デフォルト設定を JSON として書き込む
  let config_json = generate_default_config_json()

  try {
    @fs.write_file("release.json", config_json, create=0o644)
  } catch {
    e => {
      println("Error: Failed to write release.json: " + e.to_string())
      return
    }
  }

  let config = @config.Config::default()
  println("Created release.json with defaults:")
  println("  pr_title: " + config.pr_title)
  println("  allow_prerelease: " + config.allow_prerelease.to_string())
  println("  git_tag_enable: " + config.git_tag_enable.to_string())
  println("  git_release_enable: " + config.git_release_enable.to_string())
  println("  publish: " + config.publish.to_string())
  println("  publish_frozen: " + config.publish_frozen.to_string())
  println("  semver_check: " + config.semver_check.to_string())
  println("  pr_branch_prefix: " + config.pr_branch_prefix)
  println("  base_branch: " + config.base_branch)
}

/// デフォルト設定の JSON を生成
fn generate_default_config_json() -> String {
  let json =
    #|{
    #|  "pr_title": "chore: release v{{ version }}",
    #|  "pr_draft": false,
    #|  "pr_labels": [],
    #|  "pr_body": "## Release v{{ version }}\n\n---\n*This PR was automatically created by moon-release.*",
    #|  "allow_prerelease": false,
    #|  "git_tag_enable": true,
    #|  "git_tag_name": "v{{ version }}",
    #|  "git_release_enable": true,
    #|  "git_release_draft": false,
    #|  "git_release_name": "Release v{{ version }}",
    #|  "publish": true,
    #|  "publish_frozen": false,
    #|  "semver_check": false,
    #|  "pr_branch_prefix": "release/",
    #|  "base_branch": "main",
    #|  "registry_check": false,
    #|  "allow_dirty": false,
    #|  "packages": []
    #|}
  json
}

/// version コマンド
fn cmd_version() -> Unit {
  println("moon-release v" + version)
  println("")
  println("A release automation tool for MoonBit projects.")
  println("Similar to release-plz, but designed for MoonBit.")
  println("")
  println("Features:")
  println("  - Conventional Commits parsing")
  println("  - Semantic Versioning")
  println("  - moon.mod.json version management")
  println("  - Git tag creation")
  println("  - GitHub release creation")
  println("  - mooncakes.io publishing")
}

/// set-version コマンド
async fn cmd_set_version(
  subcmd : @clap.SimpleValue,
  global_dry_run : Bool,
  verbose : Bool
) -> Unit {
  // サブコマンドのフラグも確認
  let subcmd_dry_run = match subcmd.get_flag("dry-run") {
    Some(v) => v
    None => false
  }
  let dry_run = global_dry_run || subcmd_dry_run

  // バージョン引数を取得（positional 引数）
  let version_str : String = if subcmd.positional_args.length() > 0 {
    subcmd.positional_args[0]
  } else {
    println("Error: Version argument is required")
    println("Usage: moon-release set-version <version>")
    return
  }

  // バージョンをパース
  let new_version = match @semver.Version::parse(version_str) {
    Some(v) => v
    None => {
      println("Error: Invalid version format: " + version_str)
      println("Expected format: major.minor.patch (e.g., 1.2.3)")
      return
    }
  }

  if verbose {
    println("Setting version to: " + new_version.to_string())
  }

  // 現在の moon.mod.json を読み込む
  let moon_mod_content = try {
    @fs.read_file("moon.mod.json").text()
  } catch {
    e => {
      println("Error: Failed to read moon.mod.json: " + e.to_string())
      return
    }
  }

  // 現在のバージョンを取得
  let moon_mod = try {
    @moon_mod.parse(moon_mod_content)
  } catch {
    e => {
      println("Error: Failed to parse moon.mod.json: " + e.to_string())
      return
    }
  }

  if dry_run {
    println("[dry-run] Would update moon.mod.json:")
    println("  Current version: " + moon_mod.version)
    println("  New version: " + new_version.to_string())
    return
  }

  // バージョンを更新
  let updated_content = try {
    @moon_mod.update_version(moon_mod_content, new_version)
  } catch {
    e => {
      println("Error: Failed to update version: " + e.to_string())
      return
    }
  }

  try {
    @fs.write_file("moon.mod.json", updated_content, create=0o644)
  } catch {
    e => {
      println("Error: Failed to write moon.mod.json: " + e.to_string())
      return
    }
  }

  println("Updated moon.mod.json:")
  println("  " + moon_mod.version + " -> " + new_version.to_string())
}

/// check コマンド
async fn cmd_check(
  subcmd : @clap.SimpleValue,
  _dry_run : Bool,
  verbose : Bool,
  _config_path : String
) -> Unit {
  let from_tag : String? = match subcmd.args.get("from") {
    Some(arr) if arr.length() > 0 => Some(arr[0])
    _ => None
  }
  let output_format : String = try {
    subcmd.get_one("output")
  } catch {
    _ => "text"
  }
  let json_output = output_format == "json"

  if not(json_output) {
    println("Checking current state...")
    println("")
    match from_tag {
      Some(tag) => println("Analyzing commits since: " + tag)
      None => println("Analyzing commits since last tag...")
    }
  }

  // Git リポジトリを取得
  let repo = @git.Repository::current()

  // 最新タグを取得
  let latest_tag = try {
    get_latest_tag(repo)
  } catch {
    _ => None
  }

  if not(json_output) {
    match latest_tag {
      Some(tag) => println("Latest tag: " + tag)
      None => println("No tags found")
    }
  }

  // コミットを取得
  let commits = try {
    get_commits_since_last_tag(repo)
  } catch {
    e => {
      if json_output {
        println("{\"error\": \"" + escape_json_string(e.to_string()) + "\"}")
      } else {
        println("Error getting commits: " + e.to_string())
      }
      return
    }
  }

  // バンプタイプを決定
  let bump_type = if commits.length() > 0 {
    @semver.determine_bump(commits.map(fn(c) { c.0 }))
  } else {
    None
  }

  // JSON 出力
  if json_output {
    // latest_tag
    let latest_tag_json = match latest_tag {
      Some(tag) => json_string(tag)
      None => "null"
    }
    // suggested_bump
    let bump_json = match bump_type {
      Some(@semver.Major) => "\"major\""
      Some(@semver.Minor) => "\"minor\""
      Some(@semver.Patch) => "\"patch\""
      None => "null"
    }
    // commits 配列
    let commits_json_arr : Array[String] = []
    for i = 0; i < commits.length(); i = i + 1 {
      let (cc, hash) = commits[i]
      let scope_json = match cc.scope {
        Some(s) => json_string(s)
        None => "null"
      }
      let commit_json = build_json_object([
        ("hash", json_string(hash)),
        ("type", json_string(commit_type_to_string(cc.typ))),
        ("scope", scope_json),
        ("description", json_string(cc.description)),
        ("breaking", cc.breaking.to_string()),
      ])
      commits_json_arr.push(commit_json)
    }
    let commits_json = "[" + commits_json_arr.iter().fold(init="", fn(acc, s) {
      if acc.is_empty() { s } else { acc + "," + s }
    }) + "]"

    let json_str = build_json_object([
      ("latest_tag", latest_tag_json),
      ("commits_count", commits.length().to_string()),
      ("suggested_bump", bump_json),
      ("commits", commits_json),
    ])
    println(json_str)
    return
  }

  // テキスト出力
  println("Commits since last tag: \{commits.length()}")

  if verbose && commits.length() > 0 {
    println("")
    println("Commits:")
    for i = 0; i < commits.length() && i < 10; i = i + 1 {
      let (cc, hash) = commits[i]
      let typ_str = commit_type_to_string(cc.typ)
      let scope_str = match cc.scope {
        Some(s) => "(" + s + ")"
        None => ""
      }
      let breaking_str = if cc.breaking { "!" } else { "" }
      let short_hash = substr_hash(hash, 7)
      println("  \{short_hash} \{typ_str}\{scope_str}\{breaking_str}: \{cc.description}")
    }
    if commits.length() > 10 {
      println("  ... and \{commits.length() - 10} more")
    }
  }

  // バンプタイプを表示
  if commits.length() > 0 {
    println("")
    match bump_type {
      Some(@semver.Major) => println("Suggested bump: major (breaking changes)")
      Some(@semver.Minor) => println("Suggested bump: minor (new features)")
      Some(@semver.Patch) => println("Suggested bump: patch (bug fixes)")
      None => println("No releasable changes")
    }
  }

  println("")
  println("Status: Ready for release analysis")
  println("")
  println("To perform a release, run:")
  println("  moon-release update --dry-run  # Preview changes")
  println("  moon-release update            # Update files locally")
  println("  moon-release release-pr        # Create release PR")
  println("  moon-release release           # Create release")
}

/// コミットタイプを文字列に変換
fn commit_type_to_string(typ : @conventional.CommitType) -> String {
  match typ {
    @conventional.Feat => "feat"
    @conventional.Fix => "fix"
    @conventional.Docs => "docs"
    @conventional.Style => "style"
    @conventional.Refactor => "refactor"
    @conventional.Perf => "perf"
    @conventional.Test => "test"
    @conventional.Build => "build"
    @conventional.Ci => "ci"
    @conventional.Chore => "chore"
    @conventional.Revert => "revert"
    @conventional.Custom(s) => s
  }
}

/// JSON 文字列をエスケープ
fn escape_json_string(s : String) -> String {
  let result = StringBuilder::new()
  for c in s {
    match c {
      '"' => result.write_string("\\\"")
      '\\' => result.write_string("\\\\")
      '\n' => result.write_string("\\n")
      '\r' => result.write_string("\\r")
      '\t' => result.write_string("\\t")
      _ => result.write_char(c)
    }
  }
  result.to_string()
}

/// JSON 文字列リテラルを作成（クォート付き）
fn json_string(s : String) -> String {
  "\"" + escape_json_string(s) + "\""
}

/// JSON オブジェクトを構築
fn build_json_object(pairs : Array[(String, String)]) -> String {
  let result = StringBuilder::new()
  result.write_string("{")
  for i = 0; i < pairs.length(); i = i + 1 {
    let (key, value) = pairs[i]
    if i > 0 {
      result.write_string(",")
    }
    result.write_string("\"")
    result.write_string(key)
    result.write_string("\":")
    result.write_string(value)
  }
  result.write_string("}")
  result.to_string()
}

// ======== Helper functions ========

/// 設定を読み込む
async fn load_config(path : String) -> @config.Config {
  // ファイルが存在するか確認
  let content = try {
    @fs.read_file(path).text()
  } catch {
    _ => return @config.Config::default()
  }

  // パース
  try {
    @config.Config::parse(content)
  } catch {
    e => {
      println("Warning: Failed to parse config file: " + e.to_string())
      println("Using default configuration.")
      @config.Config::default()
    }
  }
}

/// moon.mod.json を読み込む
async fn load_moon_mod(path : String) -> @moon_mod.MoonMod raise {
  let content = @fs.read_file(path).text()
  @moon_mod.parse(content)
}

/// 最新タグから現在までのコミットを取得
async fn get_commits_since_last_tag(
  repo : @git.Repository,
  max_commits~ : UInt? = None
) -> Array[(@conventional.ConventionalCommit, String)] raise {
  // 最新タグを取得
  let latest_tag = try {
    get_latest_tag(repo)
  } catch {
    _ => None
  }

  // コミットログを取得
  let log_result = match latest_tag {
    Some(tag) => {
      let cmd = repo.get_commits_since_tag_command(tag)
      // max_commits が指定されていれば追加
      match max_commits {
        Some(n) => {
          cmd.push("-n")
          cmd.push(n.to_string())
        }
        None => ()
      }
      @executor.run_command(cmd)
    }
    None => {
      let cmd = repo.get_all_commits_command()
      // max_commits が指定されていれば追加
      match max_commits {
        Some(n) => {
          cmd.push("-n")
          cmd.push(n.to_string())
        }
        None => ()
      }
      @executor.run_command(cmd)
    }
  }

  // パース
  let git_commits = @git.parse_commit_log(log_result.stdout)
  @git.parse_conventional_commits(git_commits)
}

/// 最新タグを取得
async fn get_latest_tag(repo : @git.Repository) -> String? raise {
  let cmd = repo.get_latest_tag_command()
  let result = @executor.run_command(cmd)
  if result.is_success() {
    let tag = result.stdout_trimmed()
    if tag.is_empty() { None } else { Some(tag) }
  } else {
    None
  }
}

/// バンプタイプを取得
fn get_bump_type(subcmd : @clap.SimpleValue) -> @semver.BumpType? {
  match subcmd.args.get("bump") {
    Some(arr) if arr.length() > 0 =>
      match arr[0] {
        "major" => Some(@semver.Major)
        "minor" => Some(@semver.Minor)
        "patch" => Some(@semver.Patch)
        _ => None
      }
    _ => None
  }
}

/// GitHub クライアントを取得
async fn get_github_client() -> @github.GitHubClient raise {
  // gh repo view で owner/repo を取得
  let result = @executor.run_command(
    ["gh", "repo", "view", "--json", "owner,name"],
  )
  if not(result.is_success()) {
    raise @workflow.WorkflowError(
      "Failed to get repository info. Make sure you are in a GitHub repository and have gh CLI installed.",
    )
  }

  // JSON をパース
  let json = try {
    @json.parse(result.stdout)
  } catch {
    _ => raise @workflow.WorkflowError("Failed to parse repository info")
  }

  match json {
    Object(obj) => {
      let owner = match obj.get("owner") {
        Some(Object(o)) =>
          match o.get("login") {
            Some(String(s)) => s
            _ => raise @workflow.WorkflowError("Invalid owner info")
          }
        _ => raise @workflow.WorkflowError("Invalid owner info")
      }
      let name = match obj.get("name") {
        Some(String(s)) => s
        _ => raise @workflow.WorkflowError("Invalid repo name")
      }
      @github.GitHubClient::new(owner, name)
    }
    _ => raise @workflow.WorkflowError("Invalid repository info")
  }
}

/// ハッシュを短縮
fn substr_hash(hash : String, len : Int) -> String {
  if hash.length() <= len {
    return hash
  }
  let chars : Array[Char] = hash.to_array()
  let result = StringBuilder::new()
  for i = 0; i < len; i = i + 1 {
    if i < chars.length() {
      result.write_char(chars[i])
    }
  }
  result.to_string()
}

/// 未コミット変更があるかチェック
async fn check_dirty(repo : @git.Repository) -> Bool {
  let result = try {
    @executor.run_git(repo, ["status", "--porcelain"])
  } catch {
    _ => return false
  }
  not(result.stdout.trim().is_empty())
}

/// allow_dirty チェック（dirty かつ allow_dirty=false なら true を返す）
async fn should_abort_dirty(
  config : @config.Config,
  repo : @git.Repository,
  verbose : Bool
) -> Bool {
  if config.allow_dirty {
    return false
  }

  let is_dirty = check_dirty(repo)
  if is_dirty {
    println("Error: Working directory has uncommitted changes.")
    println("Commit or stash your changes, or set 'allow_dirty: true' in config.")
    if verbose {
      let result = try {
        @executor.run_git(repo, ["status", "--short"])
      } catch {
        _ => return true
      }
      println("")
      println("Changed files:")
      println(result.stdout)
    }
    return true
  }
  false
}

/// generate-completions コマンド
fn cmd_generate_completions(subcmd : @clap.SimpleValue) -> Unit {
  let shell : String = if subcmd.positional_args.length() > 0 {
    subcmd.positional_args[0]
  } else {
    println("Error: shell argument is required")
    println("Usage: moon-release generate-completions <shell>")
    println("Supported shells: bash, zsh, fish")
    return
  }

  match shell {
    "bash" => print_bash_completion()
    "zsh" => print_zsh_completion()
    "fish" => print_fish_completion()
    _ => {
      println("Error: unsupported shell: " + shell)
      println("Supported shells: bash, zsh, fish")
    }
  }
}

/// bash 補完スクリプトを出力
fn print_bash_completion() -> Unit {
  let script =
    #|# moon-release bash completion
    #|# Add this to ~/.bashrc or source it
    #|
    #|_moon_release_completions() {
    #|    local cur prev opts commands
    #|    COMPREPLY=()
    #|    cur="${COMP_WORDS[COMP_CWORD]}"
    #|    prev="${COMP_WORDS[COMP_CWORD-1]}"
    #|
    #|    commands="update release-pr release init version check set-version generate-completions"
    #|    global_opts="-n --dry-run -v --verbose -c --config -h --help"
    #|
    #|    case "${COMP_WORDS[1]}" in
    #|        update)
    #|            opts="-n --dry-run -b --bump -p --packages -o --output"
    #|            ;;
    #|        release-pr)
    #|            opts="-n --dry-run -b --bump"
    #|            ;;
    #|        release)
    #|            opts="-n --dry-run -b --bump -p --prerelease"
    #|            ;;
    #|        init)
    #|            opts="-f --force"
    #|            ;;
    #|        check)
    #|            opts="-o --output"
    #|            ;;
    #|        set-version)
    #|            opts="-n --dry-run"
    #|            ;;
    #|        generate-completions)
    #|            if [[ ${COMP_CWORD} -eq 2 ]]; then
    #|                COMPREPLY=( $(compgen -W "bash zsh fish" -- ${cur}) )
    #|                return 0
    #|            fi
    #|            opts=""
    #|            ;;
    #|        *)
    #|            if [[ ${COMP_CWORD} -eq 1 ]]; then
    #|                COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
    #|                return 0
    #|            fi
    #|            opts="${global_opts}"
    #|            ;;
    #|    esac
    #|
    #|    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    #|    return 0
    #|}
    #|
    #|complete -F _moon_release_completions moon-release
  println(script)
}

/// zsh 補完スクリプトを出力
fn print_zsh_completion() -> Unit {
  let script =
    #|#compdef moon-release
    #|# moon-release zsh completion
    #|# Add this to ~/.zshrc or place in your fpath
    #|
    #|_moon-release() {
    #|    local -a commands
    #|    commands=(
    #|        'update:Update version locally (no commit/push)'
    #|        'release-pr:Create a release pull request'
    #|        'release:Create a release (tag and GitHub release)'
    #|        'init:Initialize release configuration'
    #|        'version:Show version information'
    #|        'check:Check the current state without making changes'
    #|        'set-version:Set the package version manually'
    #|        'generate-completions:Generate shell completion script'
    #|    )
    #|
    #|    local -a global_opts
    #|    global_opts=(
    #|        '-n[Show what would be done without making changes]'
    #|        '--dry-run[Show what would be done without making changes]'
    #|        '-v[Enable verbose output]'
    #|        '--verbose[Enable verbose output]'
    #|        '-c[Path to config file]:config file:_files'
    #|        '--config[Path to config file]:config file:_files'
    #|        '-h[Show help]'
    #|        '--help[Show help]'
    #|    )
    #|
    #|    _arguments -C \
    #|        $global_opts \
    #|        '1:command:->command' \
    #|        '*::arg:->args'
    #|
    #|    case $state in
    #|        command)
    #|            _describe -t commands 'moon-release command' commands
    #|            ;;
    #|        args)
    #|            case $words[1] in
    #|                update)
    #|                    _arguments \
    #|                        '-n[Show what would be done]' \
    #|                        '--dry-run[Show what would be done]' \
    #|                        '-b[Force version bump]:bump:(major minor patch)' \
    #|                        '--bump[Force version bump]:bump:(major minor patch)' \
    #|                        '-p[Update all packages]' \
    #|                        '--packages[Update all packages]' \
    #|                        '-o[Output format]:format:(text json)' \
    #|                        '--output[Output format]:format:(text json)'
    #|                    ;;
    #|                release-pr)
    #|                    _arguments \
    #|                        '-n[Show what would be done]' \
    #|                        '--dry-run[Show what would be done]' \
    #|                        '-b[Force version bump]:bump:(major minor patch)' \
    #|                        '--bump[Force version bump]:bump:(major minor patch)'
    #|                    ;;
    #|                release)
    #|                    _arguments \
    #|                        '-n[Show what would be done]' \
    #|                        '--dry-run[Show what would be done]' \
    #|                        '-b[Force version bump]:bump:(major minor patch)' \
    #|                        '--bump[Force version bump]:bump:(major minor patch)' \
    #|                        '-p[Prerelease identifier]:prerelease:' \
    #|                        '--prerelease[Prerelease identifier]:prerelease:'
    #|                    ;;
    #|                init)
    #|                    _arguments \
    #|                        '-f[Overwrite existing configuration]' \
    #|                        '--force[Overwrite existing configuration]'
    #|                    ;;
    #|                check)
    #|                    _arguments \
    #|                        '-o[Output format]:format:(text json)' \
    #|                        '--output[Output format]:format:(text json)'
    #|                    ;;
    #|                set-version)
    #|                    _arguments \
    #|                        '-n[Show what would be done]' \
    #|                        '--dry-run[Show what would be done]' \
    #|                        ':version:'
    #|                    ;;
    #|                generate-completions)
    #|                    _arguments \
    #|                        ':shell:(bash zsh fish)'
    #|                    ;;
    #|            esac
    #|            ;;
    #|    esac
    #|}
    #|
    #|_moon-release "$@"
  println(script)
}

/// fish 補完スクリプトを出力
fn print_fish_completion() -> Unit {
  let script =
    #|# moon-release fish completion
    #|# Add this to ~/.config/fish/completions/moon-release.fish
    #|
    #|# Disable file completions
    #|complete -c moon-release -f
    #|
    #|# Global options
    #|complete -c moon-release -s n -l dry-run -d 'Show what would be done without making changes'
    #|complete -c moon-release -s v -l verbose -d 'Enable verbose output'
    #|complete -c moon-release -s c -l config -r -d 'Path to config file'
    #|complete -c moon-release -s h -l help -d 'Show help'
    #|
    #|# Commands
    #|complete -c moon-release -n '__fish_use_subcommand' -a update -d 'Update version locally'
    #|complete -c moon-release -n '__fish_use_subcommand' -a release-pr -d 'Create a release pull request'
    #|complete -c moon-release -n '__fish_use_subcommand' -a release -d 'Create a release'
    #|complete -c moon-release -n '__fish_use_subcommand' -a init -d 'Initialize release configuration'
    #|complete -c moon-release -n '__fish_use_subcommand' -a version -d 'Show version information'
    #|complete -c moon-release -n '__fish_use_subcommand' -a check -d 'Check the current state'
    #|complete -c moon-release -n '__fish_use_subcommand' -a set-version -d 'Set the package version manually'
    #|complete -c moon-release -n '__fish_use_subcommand' -a generate-completions -d 'Generate shell completion script'
    #|
    #|# update options
    #|complete -c moon-release -n '__fish_seen_subcommand_from update' -s n -l dry-run -d 'Show what would be done'
    #|complete -c moon-release -n '__fish_seen_subcommand_from update' -s b -l bump -r -a 'major minor patch' -d 'Force version bump'
    #|complete -c moon-release -n '__fish_seen_subcommand_from update' -s p -l packages -d 'Update all packages'
    #|complete -c moon-release -n '__fish_seen_subcommand_from update' -s o -l output -r -a 'text json' -d 'Output format'
    #|
    #|# release-pr options
    #|complete -c moon-release -n '__fish_seen_subcommand_from release-pr' -s n -l dry-run -d 'Show what would be done'
    #|complete -c moon-release -n '__fish_seen_subcommand_from release-pr' -s b -l bump -r -a 'major minor patch' -d 'Force version bump'
    #|
    #|# release options
    #|complete -c moon-release -n '__fish_seen_subcommand_from release' -s n -l dry-run -d 'Show what would be done'
    #|complete -c moon-release -n '__fish_seen_subcommand_from release' -s b -l bump -r -a 'major minor patch' -d 'Force version bump'
    #|complete -c moon-release -n '__fish_seen_subcommand_from release' -s p -l prerelease -r -d 'Prerelease identifier'
    #|
    #|# init options
    #|complete -c moon-release -n '__fish_seen_subcommand_from init' -s f -l force -d 'Overwrite existing configuration'
    #|
    #|# check options
    #|complete -c moon-release -n '__fish_seen_subcommand_from check' -s o -l output -r -a 'text json' -d 'Output format'
    #|
    #|# set-version options
    #|complete -c moon-release -n '__fish_seen_subcommand_from set-version' -s n -l dry-run -d 'Show what would be done'
    #|
    #|# generate-completions options
    #|complete -c moon-release -n '__fish_seen_subcommand_from generate-completions' -a 'bash zsh fish' -d 'Shell type'
  println(script)
}

/// generate-schema コマンド
fn cmd_generate_schema() -> Unit {
  let schema =
    #|{
    #|  "$schema": "http://json-schema.org/draft-07/schema#",
    #|  "title": "moon-release configuration",
    #|  "description": "Configuration file for moon-release, a release automation tool for MoonBit projects",
    #|  "type": "object",
    #|  "properties": {
    #|    "pr_title": {
    #|      "type": "string",
    #|      "description": "Title template for release PR. Use {{ version }} placeholder.",
    #|      "default": "chore: release v{{ version }}"
    #|    },
    #|    "pr_draft": {
    #|      "type": "boolean",
    #|      "description": "Create PR as draft",
    #|      "default": false
    #|    },
    #|    "pr_labels": {
    #|      "type": "array",
    #|      "items": { "type": "string" },
    #|      "description": "Labels to add to release PR",
    #|      "default": []
    #|    },
    #|    "pr_body": {
    #|      "type": "string",
    #|      "description": "Body template for release PR. Use {{ version }} placeholder.",
    #|      "default": "## Release v{{ version }}\n\n---\n*This PR was automatically created by moon-release.*"
    #|    },
    #|    "allow_prerelease": {
    #|      "type": "boolean",
    #|      "description": "Allow prerelease versions",
    #|      "default": false
    #|    },
    #|    "git_tag_enable": {
    #|      "type": "boolean",
    #|      "description": "Create git tag on release",
    #|      "default": true
    #|    },
    #|    "git_tag_name": {
    #|      "type": "string",
    #|      "description": "Tag name template. Use {{ version }} placeholder.",
    #|      "default": "v{{ version }}"
    #|    },
    #|    "git_release_enable": {
    #|      "type": "boolean",
    #|      "description": "Create GitHub release",
    #|      "default": true
    #|    },
    #|    "git_release_draft": {
    #|      "type": "boolean",
    #|      "description": "Create GitHub release as draft",
    #|      "default": false
    #|    },
    #|    "git_release_name": {
    #|      "type": "string",
    #|      "description": "Release name template. Use {{ version }} placeholder.",
    #|      "default": "Release v{{ version }}"
    #|    },
    #|    "git_release_body": {
    #|      "type": ["string", "null"],
    #|      "description": "Release body template. Use {{ version }} and {{ changelog }} placeholders. If null, uses auto-generated changelog.",
    #|      "default": null
    #|    },
    #|    "git_release_latest": {
    #|      "type": "boolean",
    #|      "description": "Mark the GitHub release as latest",
    #|      "default": true
    #|    },
    #|    "publish": {
    #|      "type": "boolean",
    #|      "description": "Publish to mooncakes.io registry",
    #|      "default": true
    #|    },
    #|    "publish_frozen": {
    #|      "type": "boolean",
    #|      "description": "Use --frozen flag when publishing",
    #|      "default": false
    #|    },
    #|    "publish_timeout": {
    #|      "type": "integer",
    #|      "minimum": 0,
    #|      "description": "Timeout in seconds for publish command (reserved for future use)",
    #|      "default": 300
    #|    },
    #|    "semver_check": {
    #|      "type": "boolean",
    #|      "description": "Check semver compatibility before release",
    #|      "default": false
    #|    },
    #|    "pr_branch_prefix": {
    #|      "type": "string",
    #|      "description": "Prefix for release branch names",
    #|      "default": "release/"
    #|    },
    #|    "base_branch": {
    #|      "type": "string",
    #|      "description": "Base branch for release PRs",
    #|      "default": "main"
    #|    },
    #|    "packages": {
    #|      "type": "array",
    #|      "description": "Package configurations for monorepo mode",
    #|      "items": {
    #|        "type": "object",
    #|        "properties": {
    #|          "name": {
    #|            "type": "string",
    #|            "description": "Package name"
    #|          },
    #|          "path": {
    #|            "type": "string",
    #|            "description": "Path to package directory",
    #|            "default": "."
    #|          },
    #|          "publish": {
    #|            "type": "boolean",
    #|            "description": "Publish this package",
    #|            "default": true
    #|          },
    #|          "version_group": {
    #|            "type": ["string", "null"],
    #|            "description": "Version group for synchronized versioning",
    #|            "default": null
    #|          }
    #|        },
    #|        "required": ["name"]
    #|      },
    #|      "default": []
    #|    },
    #|    "registry_check": {
    #|      "type": "boolean",
    #|      "description": "Check if version already exists in registry before release",
    #|      "default": false
    #|    },
    #|    "allow_dirty": {
    #|      "type": "boolean",
    #|      "description": "Allow release with uncommitted changes",
    #|      "default": false
    #|    },
    #|    "custom_major_increment_regex": {
    #|      "type": ["string", "null"],
    #|      "description": "Custom regex pattern for major version increment commits",
    #|      "default": null
    #|    },
    #|    "custom_minor_increment_regex": {
    #|      "type": ["string", "null"],
    #|      "description": "Custom regex pattern for minor version increment commits",
    #|      "default": null
    #|    },
    #|    "max_analyze_commits": {
    #|      "type": ["integer", "null"],
    #|      "minimum": 1,
    #|      "description": "Maximum number of commits to analyze for version determination",
    #|      "default": null
    #|    }
    #|  },
    #|  "additionalProperties": false
    #|}
  println(schema)
}
