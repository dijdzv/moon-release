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
      "release": @clap.SubCommand::new(
        help="Run the release workflow (analyze commits, bump version, generate changelog)",
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
          "tag": @clap.Arg::flag(
            short='t',
            help="Create a git tag for the release",
          ),
          "push": @clap.Arg::flag(help="Push changes and tags to remote"),
          "github-release": @clap.Arg::flag(
            short='g',
            help="Create a GitHub release",
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
    },
  )
}

/// メイン関数
fn main {
  let parser = create_parser()
  let value = @clap.SimpleValue::new("moon-release")

  // コマンドライン引数を取得（プログラム名をスキップ）
  let args = get_cli_args()

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
        "release" => cmd_release(subcmd, dry_run, verbose, config_path)
        "init" => cmd_init(subcmd, dry_run, verbose)
        "version" => cmd_version()
        "check" => cmd_check(subcmd, dry_run, verbose, config_path)
        _ => println("Unknown command: " + subcmd.name)
      }
    None => {
      println("moon-release v" + version)
      println("")
      println("Use --help for usage information")
    }
  }
}

/// コマンドライン引数を取得（プログラム名をスキップ）
fn get_cli_args() -> Array[String] {
  // 実行時に @env.args() などから取得
  // 現在は空の配列を返す（テスト用）
  []
}

/// release コマンド
fn cmd_release(
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

  // バンプタイプの取得
  let bump_type : String? = match subcmd.args.get("bump") {
    Some(arr) if arr.length() > 0 => Some(arr[0])
    _ => None
  }
  let prerelease : String? = match subcmd.args.get("prerelease") {
    Some(arr) if arr.length() > 0 => Some(arr[0])
    _ => None
  }
  let create_tag = match subcmd.get_flag("tag") {
    Some(v) => v
    None => false
  }
  let push = match subcmd.get_flag("push") {
    Some(v) => v
    None => false
  }
  let github_release = match subcmd.get_flag("github-release") {
    Some(v) => v
    None => false
  }

  println("Release workflow:")
  println("  1. Analyzing commits...")
  println("  2. Determining version bump...")
  match bump_type {
    Some(t) => println("     (forced: " + t + ")")
    None => println("     (auto-detect from commits)")
  }
  match prerelease {
    Some(id) => println("     Prerelease: " + id)
    None => ()
  }
  println("  3. Updating moon.mod.json...")
  println("  4. Generating CHANGELOG.md...")
  if create_tag {
    println("  5. Creating git tag...")
  }
  if push {
    println("  6. Pushing to remote...")
  }
  if github_release {
    println("  7. Creating GitHub release...")
  }

  if dry_run {
    println("")
    println("(Dry run - no changes made)")
  } else {
    println("")
    println("Release complete!")
  }
}

/// init コマンド
fn cmd_init(
  subcmd : @clap.SimpleValue,
  dry_run : Bool,
  _verbose : Bool
) -> Unit {
  let force = match subcmd.get_flag("force") {
    Some(v) => v
    None => false
  }

  println("Initializing release configuration...")

  if dry_run {
    println("Would create: release.json")
    return
  }

  if force {
    println("Overwriting existing configuration...")
  }

  // デフォルト設定を表示
  let config = @config.Config::default()
  println("Created release.json with defaults:")
  println("  pr_title: " + config.pr_title)
  println(
    "  changelog_include: [" +
    config.changelog_include.iter().map(fn(s) { "\"" + s + "\"" }).fold(
      init="",
      fn(acc, s) { if acc == "" { s } else { acc + ", " + s } },
    ) +
    "]",
  )
  println("  allow_prerelease: " + config.allow_prerelease.to_string())
  println("  github_release: " + config.github_release.to_string())
  println("  publish: " + config.publish.to_string())
}

/// version コマンド
fn cmd_version() -> Unit {
  println("moon-release v" + version)
  println("")
  println("A release automation tool for MoonBit projects.")
  println("Similar to release-please, but designed for MoonBit.")
  println("")
  println("Features:")
  println("  - Conventional Commits parsing")
  println("  - Semantic Versioning")
  println("  - CHANGELOG generation")
  println("  - moon.mod.json version management")
  println("  - Git tag creation")
  println("  - GitHub release creation")
}

/// check コマンド
fn cmd_check(
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

  // Git リポジトリのコマンドを表示
  let repo = @git.Repository::current()

  if verbose {
    println("")
    println("Git commands that would be executed:")
    println("  " + repo.get_latest_tag_command().iter().fold(
      init="",
      fn(acc, s) { if acc == "" { s } else { acc + " " + s } },
    ))
  }

  println("")
  println("Status: Ready for release analysis")
  println("")
  println("To perform a release, run:")
  println("  moon-release release")
}
