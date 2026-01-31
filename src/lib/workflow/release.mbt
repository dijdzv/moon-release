/// update コマンド: ローカル更新のみ
pub async fn run_update(ctx : ReleaseContext) -> Unit raise WorkflowError {
  if ctx.verbose {
    println("Running update workflow...")
    println("  Current version: \{ctx.current_version.to_string()}")
    println("  New version: \{ctx.new_version.to_string()}")
    println("  Commits: \{ctx.commits.length()}")
  }

  if ctx.dry_run {
    println("[dry-run] Would update moon.mod.json to version \{ctx.new_version.to_string()}")
    return
  }

  // moon.mod.json を更新
  let moon_mod_content = try {
    @fs.read_file("moon.mod.json").text()
  } catch {
    _ => raise WorkflowError("Failed to read moon.mod.json")
  }

  let updated_content = try {
    @moon_mod.update_version(moon_mod_content, ctx.new_version)
  } catch {
    e => raise WorkflowError("Failed to update version: " + e.to_string())
  }

  try {
    @fs.write_file("moon.mod.json", updated_content, create=0o644)
  } catch {
    _ => raise WorkflowError("Failed to write moon.mod.json")
  }

  println("Updated moon.mod.json to version \{ctx.new_version.to_string()}")
}

/// release-pr コマンド: PR 作成または更新
pub async fn run_release_pr(
  ctx : ReleaseContext,
  github : @github.GitHubClient
) -> Unit raise WorkflowError {
  if ctx.verbose {
    println("Running release-pr workflow...")
  }

  let branch_name = ctx.config.pr_branch_prefix + "v\{ctx.new_version.to_string()}"
  let base_branch = ctx.config.base_branch

  // 既存のリリース PR をチェック
  let existing_pr = find_existing_release_pr(github, ctx.config.pr_branch_prefix)

  if ctx.dry_run {
    match existing_pr {
      Some((pr_num, _)) => {
        println("[dry-run] Would update existing PR #\{pr_num}")
        println("[dry-run] Would update branch: " + branch_name)
      }
      None => {
        println("[dry-run] Would create release branch: " + branch_name)
        println("[dry-run] Would commit changes")
        println("[dry-run] Would create pull request")
      }
    }
    return
  }

  // 既存のブランチがあるかチェック
  let branch_exists = try {
    check_branch_exists(ctx.repo, branch_name)
  } catch {
    _ => false
  }

  if branch_exists {
    // 既存ブランチに切り替え
    let checkout_result = try {
      @executor.run_git(ctx.repo, ["checkout", branch_name])
    } catch {
      e => raise WorkflowError("Failed to checkout branch: " + e.to_string())
    }
    if not(checkout_result.is_success()) {
      raise WorkflowError("Failed to checkout branch: " + checkout_result.stderr)
    }

    // リモートから最新を取得
    let pull_result = try {
      @executor.run_git(ctx.repo, ["pull", "origin", branch_name])
    } catch {
      _ => @executor.CommandResult::failed("pull command failed")
    }
    if not(pull_result.is_success()) && ctx.verbose {
      println("[WARN] Failed to pull from remote: " + pull_result.stderr)
      println("[WARN] Continuing with local branch state...")
    }
  } else {
    // 新しいブランチを作成
    let create_branch_result = try {
      @executor.run_git(ctx.repo, ["checkout", "-b", branch_name])
    } catch {
      e => raise WorkflowError("Failed to create branch: " + e.to_string())
    }
    if not(create_branch_result.is_success()) {
      raise WorkflowError(
        "Failed to create branch: " + create_branch_result.stderr,
      )
    }
  }

  // update を実行（ファイル更新）
  run_update(ctx)

  // 変更をステージング
  let stage_result = try {
    @executor.run_git(ctx.repo, ["add", "moon.mod.json"])
  } catch {
    e => raise WorkflowError("Failed to stage files: " + e.to_string())
  }
  if not(stage_result.is_success()) {
    raise WorkflowError("Failed to stage files: " + stage_result.stderr)
  }

  // 変更があるかチェック
  let diff_result = try {
    @executor.run_git(ctx.repo, ["diff", "--cached", "--quiet"])
  } catch {
    _ => @executor.CommandResult::failed("")
  }

  if diff_result.is_success() {
    println("No changes to commit. Release PR is up to date.")
    // 元のブランチに戻る
    let _ = try {
      @executor.run_git(ctx.repo, ["checkout", base_branch])
    } catch {
      _ => @executor.CommandResult::failed("")
    }
    return
  }

  // コミット
  let commit_msg = ctx.config.apply_version_template(ctx.new_version.to_string())
  let commit_result = try {
    @executor.run_git(ctx.repo, ["commit", "-m", commit_msg])
  } catch {
    e => raise WorkflowError("Failed to commit: " + e.to_string())
  }
  if not(commit_result.is_success()) {
    raise WorkflowError("Failed to commit: " + commit_result.stderr)
  }

  // Push（force push で更新）
  let push_result = try {
    @executor.run_git(ctx.repo, ["push", "-u", "--force-with-lease", "origin", branch_name])
  } catch {
    e => raise WorkflowError("Failed to push: " + e.to_string())
  }
  if not(push_result.is_success()) {
    raise WorkflowError("Failed to push: " + push_result.stderr)
  }

  // 元のブランチに戻る
  let _ = try {
    @executor.run_git(ctx.repo, ["checkout", base_branch])
  } catch {
    _ => @executor.CommandResult::failed("")
  }

  match existing_pr {
    Some((pr_num, _)) => {
      // 既存 PR を更新
      let pr_body = build_pr_body(ctx)
      let update_result = try {
        @executor.run_gh(["pr", "edit", pr_num.to_string(), "--body", pr_body])
      } catch {
        e => raise WorkflowError("Failed to update PR: " + e.to_string())
      }
      if not(update_result.is_success()) {
        println("Warning: Failed to update PR body: " + update_result.stderr)
      }
      println("Updated pull request #\{pr_num}")
    }
    None => {
      // 新しい PR を作成
      let pr_title = commit_msg
      let pr_body = build_pr_body(ctx)
      let pr_cmd = github.create_pull_request_command(
        pr_title,
        pr_body,
        branch_name,
        base_branch,
        draft=ctx.config.pr_draft,
        labels=ctx.config.pr_labels,
      )

      // gh コマンドの引数を抽出
      let gh_args : Array[String] = []
      for i = 1; i < pr_cmd.length(); i = i + 1 {
        gh_args.push(pr_cmd[i])
      }

      let pr_result = try {
        @executor.run_gh(gh_args)
      } catch {
        e => raise WorkflowError("Failed to create PR: " + e.to_string())
      }
      if not(pr_result.is_success()) {
        raise WorkflowError("Failed to create PR: " + pr_result.stderr)
      }

      println("Created pull request: " + pr_result.stdout_trimmed())
    }
  }
}

/// 既存のリリース PR を検索
async fn find_existing_release_pr(
  github : @github.GitHubClient,
  branch_prefix : String
) -> (UInt, String)? raise WorkflowError {
  let list_cmd = github.list_pull_requests_command(state="open")

  // gh コマンドの引数を抽出
  let gh_args : Array[String] = []
  for i = 1; i < list_cmd.length(); i = i + 1 {
    gh_args.push(list_cmd[i])
  }

  let result = try {
    @executor.run_gh(gh_args)
  } catch {
    _ => return None
  }

  if not(result.is_success()) {
    return None
  }

  // PR リストをパース
  let prs = try {
    @github.parse_pull_request_list_json(result.stdout)
  } catch {
    _ => return None
  }

  // release/ で始まるブランチの PR を探す
  for pr in prs {
    if pr.head.has_prefix(branch_prefix) {
      return Some((pr.number, pr.head))
    }
  }

  None
}

/// ブランチが存在するかチェック
async fn check_branch_exists(
  repo : @git.Repository,
  branch_name : String
) -> Bool {
  let result = try {
    @executor.run_git(repo, ["rev-parse", "--verify", branch_name])
  } catch {
    _ => return false
  }
  result.is_success()
}

/// release コマンド: タグ・リリース作成
pub async fn run_release(
  ctx : ReleaseContext,
  github : @github.GitHubClient
) -> Unit raise WorkflowError {
  if ctx.verbose {
    println("Running release workflow...")
  }

  // テンプレートからタグ名とリリース名を生成
  let tag_name = ctx.config.git_tag_name.replace(
    old="{{ version }}",
    new=ctx.new_version.to_string(),
  )
  let release_title = ctx.config.git_release_name.replace(
    old="{{ version }}",
    new=ctx.new_version.to_string(),
  )

  if ctx.dry_run {
    if ctx.config.git_tag_enable {
      println("[dry-run] Would create tag: " + tag_name)
    }
    if ctx.config.git_release_enable {
      println("[dry-run] Would create GitHub release: " + release_title)
    }
    if ctx.config.publish {
      println("[dry-run] Would publish to mooncakes.io")
    }
    return
  }

  // タグを作成（git_tag_enable が true の場合のみ）
  if ctx.config.git_tag_enable {
    let tag_msg = release_title
    let tag_result = try {
      @executor.run_git(ctx.repo, ["tag", "-a", tag_name, "-m", tag_msg])
    } catch {
      e => raise WorkflowError("Failed to create tag: " + e.to_string())
    }
    if not(tag_result.is_success()) {
      raise WorkflowError("Failed to create tag: " + tag_result.stderr)
    }

    // タグを Push
    let push_result = try {
      @executor.run_git(ctx.repo, ["push", "origin", tag_name])
    } catch {
      e => raise WorkflowError("Failed to push tag: " + e.to_string())
    }
    if not(push_result.is_success()) {
      raise WorkflowError("Failed to push tag: " + push_result.stderr)
    }

    println("Created and pushed tag: " + tag_name)
  }

  // GitHub Release を作成
  if ctx.config.git_release_enable {
    // リリースノート: カスタムテンプレートがあればそれを使用、なければ自動生成
    let release_notes = match ctx.config.git_release_body {
      Some(template) =>
        template
        .replace(old="{{ version }}", new=ctx.new_version.to_string())
        .replace(old="{{ changelog }}", new=generate_release_notes(ctx.commits))
      None => generate_release_notes(ctx.commits)
    }
    let release_cmd = github.create_release_command(
      tag_name,
      release_title,
      release_notes,
      draft=ctx.config.git_release_draft,
      latest=ctx.config.git_release_latest,
    )

    // gh コマンドの引数を抽出
    let gh_args : Array[String] = []
    for i = 1; i < release_cmd.length(); i = i + 1 {
      gh_args.push(release_cmd[i])
    }

    let release_result = try {
      @executor.run_gh(gh_args)
    } catch {
      e => raise WorkflowError("Failed to create release: " + e.to_string())
    }
    if not(release_result.is_success()) {
      raise WorkflowError(
        "Failed to create release: " + release_result.stderr,
      )
    }

    println("Created GitHub release: " + tag_name)
  }

  // mooncakes.io に公開
  if ctx.config.publish {
    run_publish(ctx)
  }
}

/// publish コマンド: mooncakes.io に公開
pub async fn run_publish(ctx : ReleaseContext) -> Unit raise WorkflowError {
  if ctx.verbose {
    println("Publishing to mooncakes.io...")
  }

  // semver_check が有効な場合は API 互換性チェックを実行
  if ctx.config.semver_check {
    if ctx.verbose {
      println("Running API compatibility check...")
    }

    let check_result = try {
      run_semver_check(ctx.repo, ctx.verbose)
    } catch {
      e => {
        println("Warning: Semver check failed: " + e.to_string())
        println("Continuing with publish...")
        @semver_check.CheckResult::new(@semver_check.ApiDiff::empty())
      }
    }

    if check_result.diff.has_breaking {
      println("")
      println("WARNING: Breaking API changes detected!")
      println(@semver_check.format_summary(check_result))
      println("")
      println("Consider:")
      println("  1. Bumping the major version")
      println("  2. Using BREAKING CHANGE: in your commit messages")
      println("")
    } else if ctx.verbose {
      println("Semver check passed: " + @semver_check.format_summary(check_result))
    }
  }

  // publish コマンドを構築
  let publish_cmd : Array[String] = if ctx.config.publish_frozen {
    ["moon", "publish", "--frozen"]
  } else {
    ["moon", "publish"]
  }

  if ctx.dry_run {
    println("[dry-run] Would run: " + publish_cmd.iter().fold(init="", fn(acc, s) {
      if acc.is_empty() { s } else { acc + " " + s }
    }))
    return
  }

  let publish_result = try {
    @executor.run_command(publish_cmd)
  } catch {
    e => raise WorkflowError("Failed to publish: " + e.to_string())
  }

  if not(publish_result.is_success()) {
    // publish 失敗は警告として扱う（タグは既に作成されているため）
    println("Warning: Failed to publish to mooncakes.io: " + publish_result.stderr)
    println("You can manually publish with: moon publish")
    return
  }

  println("Published to mooncakes.io")
}

/// パッケージ更新情報
priv struct PackageUpdateInfo {
  pkg : @config.PackageConfig
  moon_mod_path : String
  moon_mod_content : String
  current_version : @semver.Version
  bump_type : @semver.BumpType
  commits : Array[(@conventional.ConventionalCommit, String)]
}

/// モノレポ用: 複数パッケージの更新
pub async fn run_update_packages(
  config : @config.Config,
  repo : @git.Repository,
  dry_run : Bool,
  verbose : Bool
) -> Unit raise WorkflowError {
  if config.packages.is_empty() {
    if verbose {
      println("No packages configured. Using single-package mode.")
    }
    return
  }

  if verbose {
    println("Updating \{config.packages.length()} packages...")
  }

  // Phase 1: 各パッケージの情報を収集
  let updates : Array[PackageUpdateInfo] = []

  for pkg in config.packages {
    if verbose {
      println("  Analyzing package: " + pkg.name)
    }

    // パス検証（ディレクトリトラバーサル防止）
    if not(validate_path(pkg.path)) {
      println("  Warning: Invalid path for " + pkg.name + ": " + pkg.path)
      continue
    }

    let pkg_path = if pkg.path == "." { "" } else { pkg.path + "/" }
    let moon_mod_path = pkg_path + "moon.mod.json"

    // moon.mod.json を読み込む
    let moon_mod_content = try {
      @fs.read_file(moon_mod_path).text()
    } catch {
      _ => {
        println("  Warning: Could not read " + moon_mod_path)
        continue
      }
    }

    let moon_mod = try {
      @moon_mod.parse(moon_mod_content)
    } catch {
      e => {
        println("  Warning: Could not parse " + moon_mod_path + ": " + e.to_string())
        continue
      }
    }

    let current_version = match @semver.Version::parse(moon_mod.version) {
      Some(v) => v
      None => {
        println("  Warning: Invalid version in " + moon_mod_path)
        continue
      }
    }

    // パッケージのコミットを取得（パスフィルター付き）
    let commits = try {
      get_package_commits(repo, pkg.path)
    } catch {
      e => {
        println("  Warning: Could not get commits for " + pkg.name + ": " + e.to_string())
        continue
      }
    }

    if commits.is_empty() {
      if verbose {
        println("    No changes in " + pkg.name)
      }
      continue
    }

    // バンプタイプを決定
    let bump_type = match @semver.determine_bump(commits.map(fn(c) { c.0 })) {
      Some(t) => t
      None => {
        if verbose {
          println("    No releasable changes in " + pkg.name)
        }
        continue
      }
    }

    updates.push(
      PackageUpdateInfo::{
        pkg,
        moon_mod_path,
        moon_mod_content,
        current_version,
        bump_type,
        commits,
      },
    )
  }

  // Phase 2: version_group のバンプタイプを統合
  let group_bumps : @hashmap.HashMap[String, @semver.BumpType] = @hashmap.new()

  for update in updates {
    match update.pkg.version_group {
      Some(group) => {
        let current_group_bump = group_bumps.get(group)
        let should_update = match current_group_bump {
          None => true
          Some(existing) => bump_priority(update.bump_type) > bump_priority(existing)
        }
        if should_update {
          group_bumps.set(group, update.bump_type)
        }
      }
      None => ()
    }
  }

  // Phase 3: 更新を実行
  for update in updates {
    // version_group がある場合はグループのバンプタイプを使用
    let final_bump_type = match update.pkg.version_group {
      Some(group) =>
        match group_bumps.get(group) {
          Some(group_bump) => group_bump
          None => update.bump_type
        }
      None => update.bump_type
    }

    let new_version = @semver.bump(update.current_version, final_bump_type)

    if dry_run {
      let group_info = match update.pkg.version_group {
        Some(g) => " (group: " + g + ")"
        None => ""
      }
      println("  [dry-run] Would update \{update.pkg.name}\{group_info}: \{update.current_version.to_string()} -> \{new_version.to_string()}")
      continue
    }

    // バージョン更新
    let updated_content = try {
      @moon_mod.update_version(update.moon_mod_content, new_version)
    } catch {
      e => {
        println("  Warning: Could not update version: " + e.to_string())
        continue
      }
    }

    try {
      @fs.write_file(update.moon_mod_path, updated_content, create=0o644)
    } catch {
      _ => {
        println("  Warning: Could not write " + update.moon_mod_path)
        continue
      }
    }

    let group_info = match update.pkg.version_group {
      Some(g) => " (group: " + g + ")"
      None => ""
    }
    println("  Updated \{update.pkg.name}\{group_info}: \{update.current_version.to_string()} -> \{new_version.to_string()}")
  }
}

/// パッケージのコミットを取得（パスフィルター付き）
async fn get_package_commits(
  repo : @git.Repository,
  path : String
) -> Array[(@conventional.ConventionalCommit, String)] raise WorkflowError {
  // 最新タグを取得
  let tag_result = try {
    @executor.run_git(repo, ["describe", "--tags", "--abbrev=0"])
  } catch {
    _ => @executor.CommandResult::failed("")
  }

  let log_cmd = if tag_result.is_success() {
    let tag = tag_result.stdout_trimmed()
    ["log", "--pretty=format:%H|%s|%an|%aI", tag + "..HEAD", "--", path]
  } else {
    ["log", "--pretty=format:%H|%s|%an|%aI", "--", path]
  }

  let log_result = try {
    @executor.run_git(repo, log_cmd)
  } catch {
    e => raise WorkflowError("Failed to get commits: " + e.to_string())
  }

  let git_commits = @git.parse_commit_log(log_result.stdout)
  @git.parse_conventional_commits(git_commits)
}

/// モノレポ用: 複数パッケージの公開
pub async fn run_publish_packages(
  config : @config.Config,
  dry_run : Bool,
  verbose : Bool
) -> Unit raise WorkflowError {
  if config.packages.is_empty() {
    if verbose {
      println("No packages configured. Using single-package mode.")
    }
    return
  }

  for pkg in config.packages {
    if not(pkg.publish) {
      if verbose {
        println("  Skipping " + pkg.name + " (publish: false)")
      }
      continue
    }

    // パス検証（ディレクトリトラバーサル防止）
    if not(validate_path(pkg.path)) {
      println("  Warning: Invalid path for " + pkg.name + ": " + pkg.path)
      continue
    }

    if dry_run {
      println("[dry-run] Would publish " + pkg.name)
      continue
    }

    if verbose {
      println("Publishing " + pkg.name + "...")
    }

    let publish_result = if pkg.path == "." {
      try {
        @executor.run_command(["moon", "publish"])
      } catch {
        e => {
          println("  Warning: Failed to publish " + pkg.name + ": " + e.to_string())
          continue
        }
      }
    } else {
      try {
        @executor.run_command(["moon", "publish", "-C", pkg.path])
      } catch {
        e => {
          println("  Warning: Failed to publish " + pkg.name + ": " + e.to_string())
          continue
        }
      }
    }

    if not(publish_result.is_success()) {
      println("  Warning: Failed to publish " + pkg.name + ": " + publish_result.stderr)
      continue
    }

    println("  Published " + pkg.name)
  }
}

/// レジストリのバージョンを取得
pub async fn get_registry_version(
  package_name : String
) -> @semver.Version? raise WorkflowError {
  // moon info コマンドでパッケージ情報を取得
  let result = try {
    @executor.run_command(["moon", "info", package_name])
  } catch {
    _ => return None
  }

  if not(result.is_success()) {
    return None
  }

  // 出力からバージョンを抽出
  // 出力形式: "name: package_name\nversion: x.y.z\n..."
  let lines : Array[String] = result.stdout
    .split("\n")
    .map(fn(sv) { sv.to_string() })
    .collect()

  for line in lines {
    let trimmed = line.trim().to_string()
    if trimmed.has_prefix("version:") {
      let version_str = trimmed
        .split(":")
        .map(fn(sv) { sv.to_string() })
        .collect()
      if version_str.length() >= 2 {
        let ver = version_str[1].trim().to_string()
        return @semver.Version::parse(ver)
      }
    }
  }

  None
}

/// レジストリとローカルバージョンを比較し、リリースが必要かチェック
pub async fn should_release(
  local_version : @semver.Version,
  package_name : String,
  verbose : Bool
) -> Bool raise WorkflowError {
  let registry_version = get_registry_version(package_name)

  match registry_version {
    None => {
      if verbose {
        println("  Package not found in registry. Will publish as new package.")
      }
      true
    }
    Some(reg_ver) => {
      let cmp = local_version.compare(reg_ver)
      if cmp > 0 {
        if verbose {
          println("  Local version (\{local_version.to_string()}) > registry version (\{reg_ver.to_string()})")
        }
        true
      } else {
        if verbose {
          println("  Local version (\{local_version.to_string()}) <= registry version (\{reg_ver.to_string()}). Skipping.")
        }
        false
      }
    }
  }
}

/// BumpType の優先度を返す（Major > Minor > Patch）
pub fn bump_priority(bump : @semver.BumpType) -> Int {
  match bump {
    Major => 3
    Minor => 2
    Patch => 1
  }
}

/// PR の body を構築（テンプレート適用）
pub fn build_pr_body(ctx : ReleaseContext) -> String {
  ctx.config.pr_body.replace(old="{{ version }}", new=ctx.new_version.to_string())
}

/// リリースノートを生成（コミットサマリーから）
pub fn generate_release_notes(
  commits : Array[(@conventional.ConventionalCommit, String)]
) -> String {
  if commits.is_empty() {
    return "No changes."
  }

  let lines : Array[String] = []
  lines.push("## What's Changed\n")

  for i = 0; i < commits.length(); i = i + 1 {
    let (commit, hash) = commits[i]
    let scope_str = match commit.scope {
      Some(s) => "**\{s}**: "
      None => ""
    }
    let short_hash = if hash.length() >= 7 {
      // 先頭7文字を取得
      let chars = hash.to_array()
      let sb = StringBuilder::new()
      for k = 0; k < 7; k = k + 1 {
        sb.write_char(chars[k])
      }
      sb.to_string()
    } else {
      hash
    }
    lines.push("- \{scope_str}\{commit.description} (\{short_hash})")
  }

  lines.iter().fold(init="", fn(acc, line) { acc + line + "\n" })
}

/// semver チェックを実行
pub async fn run_semver_check(
  repo : @git.Repository,
  verbose : Bool
) -> @semver_check.CheckResult raise WorkflowError {
  if verbose {
    println("Running semver check...")
  }

  // 1. 最新タグを取得
  let tag_result = try {
    @executor.run_git(repo, ["describe", "--tags", "--abbrev=0"])
  } catch {
    _ =>
      raise WorkflowError(
        "No tags found. Cannot perform semver check without a previous version.",
      )
  }

  if not(tag_result.is_success()) {
    raise WorkflowError(
      "No tags found. Cannot perform semver check without a previous version.",
    )
  }

  let latest_tag = tag_result.stdout_trimmed()
  if verbose {
    println("  Comparing against tag: " + latest_tag)
  }

  // 2. 現在のブランチ名を保存
  let branch_result = try {
    @executor.run_git(repo, ["rev-parse", "--abbrev-ref", "HEAD"])
  } catch {
    e => raise WorkflowError("Failed to get current branch: " + e.to_string())
  }
  let current_branch = branch_result.stdout_trimmed()

  // 3. 現在のコードで moon doc を実行
  if verbose {
    println("  Generating docs for current code...")
  }
  let doc_result = try {
    @executor.run_command(["moon", "doc"])
  } catch {
    e => raise WorkflowError("Failed to run moon doc: " + e.to_string())
  }
  if not(doc_result.is_success()) {
    raise WorkflowError("Failed to generate docs: " + doc_result.stderr)
  }

  // 4. 現在の package_data.json を読み込む
  let current_apis = try {
    load_package_apis("target/doc")
  } catch {
    e => raise WorkflowError("Failed to load current API: " + e.to_string())
  }

  // 5. タグをチェックアウトして古い API を取得（安全なブランチ復帰を保証）
  let old_apis = get_old_apis_with_safe_checkout(
    repo,
    latest_tag,
    current_branch,
    verbose,
  )

  // 6. API を比較
  if verbose {
    println("  Comparing APIs...")
  }
  let diff = @semver_check.diff_api(old_apis, current_apis)
  let result = @semver_check.CheckResult::new(diff)

  if verbose {
    println(result.format())
  }

  result
}

/// タグをチェックアウトして古い API を取得し、必ず元のブランチに戻る
async fn get_old_apis_with_safe_checkout(
  repo : @git.Repository,
  tag : String,
  original_branch : String,
  verbose : Bool
) -> @semver_check.PackageApi raise WorkflowError {
  // タグをチェックアウト
  if verbose {
    println("  Checking out tag: " + tag)
  }
  let checkout_result = try {
    @executor.run_git(repo, ["checkout", tag])
  } catch {
    e => raise WorkflowError("Failed to checkout tag: " + e.to_string())
  }
  if not(checkout_result.is_success()) {
    raise WorkflowError("Failed to checkout tag: " + checkout_result.stderr)
  }

  // この時点からは必ず元のブランチに戻る必要がある

  // タグのコードで moon doc を実行
  if verbose {
    println("  Generating docs for previous version...")
  }
  let old_doc_result = try {
    @executor.run_command(["moon", "doc"])
  } catch {
    e => {
      let _ = try { restore_branch(repo, original_branch, verbose) } catch { _ => () }
      raise WorkflowError("Failed to run moon doc on tag: " + e.to_string())
    }
  }

  // package_data.json を読み込む
  let old_apis = if old_doc_result.is_success() {
    try {
      load_package_apis("target/doc")
    } catch {
      _ => @semver_check.PackageApi::empty()
    }
  } else {
    @semver_check.PackageApi::empty()
  }

  // 元のブランチに戻る
  let _ = try { restore_branch(repo, original_branch, verbose) } catch { _ => () }

  old_apis
}

/// 元のブランチに戻る（エラーは警告として処理）
async fn restore_branch(
  repo : @git.Repository,
  branch : String,
  verbose : Bool
) -> Unit {
  if verbose {
    println("  Restoring original branch...")
  }
  let result = try {
    @executor.run_git(repo, ["checkout", branch])
  } catch {
    e => {
      println("Warning: Failed to restore branch: " + e.to_string())
      println("You may need to manually checkout: git checkout " + branch)
      return
    }
  }
  if not(result.is_success()) {
    println("Warning: Failed to restore branch: " + result.stderr)
    println("You may need to manually checkout: git checkout " + branch)
  }
}

/// target/doc から package_data.json を読み込む
async fn load_package_apis(doc_dir : String) -> @semver_check.PackageApi raise WorkflowError {
  // find コマンドで package_data.json を探す
  let find_result = try {
    @executor.run_command(
      ["find", doc_dir, "-name", "package_data.json", "-type", "f"],
    )
  } catch {
    e => raise WorkflowError("Failed to find package_data.json files: " + e.to_string())
  }

  if not(find_result.is_success()) {
    raise WorkflowError("Failed to find package_data.json files")
  }

  let files : Array[String] = find_result.stdout
    .split("\n")
    .filter(fn(sv) { not(sv.to_string().trim().is_empty()) })
    .map(fn(sv) { sv.to_string() })
    .collect()

  let all_apis : Array[@semver_check.PackageApi] = []

  for file in files {
    let content = try {
      @fs.read_file(file).text()
    } catch {
      _ => continue
    }

    let api = try {
      @semver_check.parse_package_data(content)
    } catch {
      _ => continue
    }

    all_apis.push(api)
  }

  @semver_check.merge_package_apis(all_apis)
}
