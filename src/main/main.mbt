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
          "bump": @clap.Arg::named(
            short='b',
            nargs=@clap.One,
            help="Force a specific version bump (major, minor, patch)",
          ),
          "packages": @clap.Arg::flag(
            short='p',
            help="Update all packages in monorepo mode",
          ),
        },
      ),
      "release-pr": @clap.SubCommand::new(
        help="Create a release pull request",
        args={
          "bump": @clap.Arg::named(
            short='b',
            nargs=@clap.One,
            help="Force a specific version bump (major, minor, patch)",
          ),
        },
      ),
      "release": @clap.SubCommand::new(
        help="Create a release (tag and GitHub release)",
        args={
          "bump": @clap.Arg::named(
            short='b',
            nargs=@clap.One,
            help="Force a specific version bump (major, minor, patch)",
          ),
          "prerelease": @clap.Arg::named(
            short='p',
            nargs=@clap.One,
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
          "from": @clap.Arg::named(
            nargs=@clap.One,
            help="Start from a specific tag or commit",
          ),
        },
      ),
      "set-version": @clap.SubCommand::new(
        help="Set the package version manually",
        args={
          "version": @clap.Arg::positional(
            nargs=@clap.One,
            help="The version to set (e.g., 1.2.3)",
          ),
        },
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
  dry_run : Bool,
  verbose : Bool,
  config_path : String
) -> Unit {
  if verbose {
    println("Running update command...")
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

  // モノレポモードかチェック
  let packages_mode = match subcmd.get_flag("packages") {
    Some(v) => v
    None => false
  }

  // モノレポモードの場合は各パッケージを個別に更新
  if packages_mode || not(config.packages.is_empty()) {
    try {
      @workflow.run_update_packages(config, repo, dry_run, verbose)
    } catch {
      e => println("Error: " + e.to_string())
    }
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
      return
    }
  }

  // コミットを解析
  let commits = try {
    get_commits_since_last_tag(repo)
  } catch {
    e => {
      println("Error getting commits: " + e.to_string())
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
          println("No releasable commits found (no feat, fix, or breaking changes)")
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
        if verbose {
          println("Warning: Registry check failed: " + e.to_string())
        }
        true // エラーの場合はリリースを続行
      }
    }

    if not(should_rel) {
      println(
        "Version \{new_version.to_string()} is not newer than registry version. Nothing to update.",
      )
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
  } catch {
    e => println("Error: " + e.to_string())
  }
}

/// release-pr コマンド
async fn cmd_release_pr(
  subcmd : @clap.SimpleValue,
  dry_run : Bool,
  verbose : Bool,
  config_path : String
) -> Unit {
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
      return
    }
  }

  // コミットを解析
  let commits = try {
    get_commits_since_last_tag(repo)
  } catch {
    e => {
      println("Error getting commits: " + e.to_string())
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
  dry_run : Bool,
  verbose : Bool,
  config_path : String
) -> Unit {
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
      return
    }
  }

  // コミットを解析
  let commits = try {
    get_commits_since_last_tag(repo)
  } catch {
    e => {
      println("Error getting commits: " + e.to_string())
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
  println("  github_release: " + config.github_release.to_string())
  println("  publish: " + config.publish.to_string())
  println("  release_branch_prefix: " + config.release_branch_prefix)
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
    #|  "github_release": true,
    #|  "git_release_draft": false,
    #|  "git_release_name": "Release v{{ version }}",
    #|  "git_tag_name": "v{{ version }}",
    #|  "publish": true,
    #|  "release_branch_prefix": "release/",
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
  dry_run : Bool,
  verbose : Bool
) -> Unit {
  // バージョン引数を取得
  let version_str : String = match subcmd.args.get("version") {
    Some(arr) if arr.length() > 0 => arr[0]
    _ => {
      println("Error: Version argument is required")
      println("Usage: moon-release set-version <version>")
      return
    }
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

  println("Checking current state...")
  println("")

  match from_tag {
    Some(tag) => println("Analyzing commits since: " + tag)
    None => println("Analyzing commits since last tag...")
  }

  // Git リポジトリを取得
  let repo = @git.Repository::current()

  // 最新タグを取得
  let latest_tag = try {
    get_latest_tag(repo)
  } catch {
    _ => None
  }

  match latest_tag {
    Some(tag) => println("Latest tag: " + tag)
    None => println("No tags found")
  }

  // コミットを取得
  let commits = try {
    get_commits_since_last_tag(repo)
  } catch {
    e => {
      println("Error getting commits: " + e.to_string())
      return
    }
  }

  println("Commits since last tag: \{commits.length()}")

  if verbose && commits.length() > 0 {
    println("")
    println("Commits:")
    for i = 0; i < commits.length() && i < 10; i = i + 1 {
      let (cc, hash) = commits[i]
      let typ_str = match cc.typ {
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

  // バンプタイプを決定
  if commits.length() > 0 {
    let bump_type = @semver.determine_bump(commits.map(fn(c) { c.0 }))
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
  repo : @git.Repository
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
      @executor.run_command(cmd)
    }
    None => {
      let cmd = repo.get_all_commits_command()
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
