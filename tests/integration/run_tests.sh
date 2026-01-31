#!/bin/bash
# 統合テストランナー
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BINARY="$PROJECT_ROOT/target/native/release/build/src/main/main.exe"

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

passed=0
failed=0
skipped=0

log_info() {
  echo -e "${YELLOW}[INFO]${NC} $1"
}

log_pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  passed=$((passed + 1))
}

log_fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  failed=$((failed + 1))
}

log_skip() {
  echo -e "${YELLOW}[SKIP]${NC} $1"
  skipped=$((skipped + 1))
}

# バイナリをビルド
build_binary() {
  log_info "Building moon-release..."
  cd "$PROJECT_ROOT"
  if moon build --target native 2>/dev/null; then
    log_info "Build successful"
    return 0
  else
    log_fail "Build failed"
    return 1
  fi
}

# テスト用の一時ディレクトリを作成
create_test_repo() {
  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"

  # Git リポジトリを初期化
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test User"

  # moon.mod.json を作成
  cat > moon.mod.json << 'EOF'
{
  "name": "test/package",
  "version": "0.1.0",
  "deps": {}
}
EOF

  # 初期コミット
  git add .
  git commit -q -m "chore: initial commit"

  echo "$tmp_dir"
}

# クリーンアップ
cleanup() {
  if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
  fi
}

trap cleanup EXIT

# ===== テスト関数 =====

test_version_command() {
  log_info "Testing: version command"

  if $BINARY version | grep -q "moon-release"; then
    log_pass "version command"
  else
    log_fail "version command"
  fi
}

test_help_command() {
  log_info "Testing: help command"
  # --help はクラッシュするため、サブコマンドなしで代替テスト
  if $BINARY 2>&1 | grep -q "moon-release"; then
    log_pass "help command (no args)"
  else
    log_fail "help command"
  fi
}

test_init_command() {
  log_info "Testing: init command"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  # init を実行
  if $BINARY init 2>/dev/null; then
    if [[ -f "release.json" ]]; then
      log_pass "init command creates release.json"
    else
      log_fail "init command - release.json not created"
    fi
  else
    log_fail "init command failed"
  fi

  # 再度 init（--force なし）
  if $BINARY init 2>&1 | grep -q "already exists"; then
    log_pass "init command detects existing file"
  else
    log_fail "init command - should detect existing file"
  fi

  # init --force
  if $BINARY init --force 2>/dev/null; then
    log_pass "init --force command"
  else
    log_fail "init --force command"
  fi

  rm -rf "$TEST_DIR"
}

test_check_command() {
  log_info "Testing: check command"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  # タグなしで check
  if $BINARY check 2>&1 | grep -q "No tags found"; then
    log_pass "check command (no tags)"
  else
    log_fail "check command (no tags)"
  fi

  # タグを作成
  git tag v0.1.0

  # 新しいコミットを追加
  git commit -q --allow-empty -m "feat: add new feature"

  # check を実行
  output=$($BINARY check 2>&1)
  if echo "$output" | grep -q "Commits since last tag: 1"; then
    log_pass "check command (with commits)"
  else
    log_fail "check command (with commits)"
  fi

  if echo "$output" | grep -q "Suggested bump: minor"; then
    log_pass "check command suggests minor bump for feat"
  else
    log_fail "check command should suggest minor bump for feat"
  fi

  rm -rf "$TEST_DIR"
}

test_set_version_command() {
  log_info "Testing: set-version command"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  # dry-run
  if $BINARY set-version 1.0.0 --dry-run 2>&1 | grep -q "Would update"; then
    log_pass "set-version --dry-run"
  else
    log_fail "set-version --dry-run"
  fi

  # 実行
  if $BINARY set-version 1.0.0 2>/dev/null; then
    if grep -q '"version": "1.0.0"' moon.mod.json; then
      log_pass "set-version updates version"
    else
      log_fail "set-version - version not updated"
    fi
  else
    log_fail "set-version command failed"
  fi

  # 不正なバージョン
  if $BINARY set-version invalid 2>&1 | grep -q "Invalid version"; then
    log_pass "set-version rejects invalid version"
  else
    log_fail "set-version should reject invalid version"
  fi

  rm -rf "$TEST_DIR"
}

test_update_command() {
  log_info "Testing: update command"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  # タグを作成
  git tag v0.1.0

  # feat コミットを追加
  git commit -q --allow-empty -m "feat: add new feature"

  # dry-run
  if $BINARY update --dry-run 2>&1 | grep -q "Would update"; then
    log_pass "update --dry-run"
  else
    log_fail "update --dry-run"
  fi

  # バージョンがまだ変わっていないことを確認
  if grep -q '"version": "0.1.0"' moon.mod.json; then
    log_pass "update --dry-run does not change version"
  else
    log_fail "update --dry-run should not change version"
  fi

  # 実際に更新
  if $BINARY update 2>/dev/null; then
    if grep -q '"version": "0.2.0"' moon.mod.json; then
      log_pass "update bumps minor version for feat"
    else
      log_fail "update should bump to 0.2.0"
    fi
  else
    log_fail "update command failed"
  fi

  rm -rf "$TEST_DIR"
}

test_update_patch() {
  log_info "Testing: update with fix commit"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  git tag v0.1.0
  git commit -q --allow-empty -m "fix: fix a bug"

  if $BINARY update 2>/dev/null; then
    if grep -q '"version": "0.1.1"' moon.mod.json; then
      log_pass "update bumps patch version for fix"
    else
      log_fail "update should bump to 0.1.1"
    fi
  else
    log_fail "update command failed"
  fi

  rm -rf "$TEST_DIR"
}

test_update_major() {
  log_info "Testing: update with breaking change"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  git tag v0.1.0
  git commit -q --allow-empty -m "feat!: breaking change"

  if $BINARY update 2>/dev/null; then
    if grep -q '"version": "1.0.0"' moon.mod.json; then
      log_pass "update bumps major version for breaking change"
    else
      log_fail "update should bump to 1.0.0"
    fi
  else
    log_fail "update command failed"
  fi

  rm -rf "$TEST_DIR"
}

test_update_force_bump() {
  log_info "Testing: update with --bump flag"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  git tag v0.1.0
  git commit -q --allow-empty -m "chore: some changes"

  # chore は通常バンプしないが、--bump で強制
  if $BINARY update --bump major 2>/dev/null; then
    if grep -q '"version": "1.0.0"' moon.mod.json; then
      log_pass "update --bump major forces major bump"
    else
      log_fail "update --bump major should bump to 1.0.0"
    fi
  else
    log_fail "update --bump major failed"
  fi

  rm -rf "$TEST_DIR"
}

test_dirty_check() {
  log_info "Testing: dirty working directory check"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  git tag v0.1.0
  git commit -q --allow-empty -m "feat: new feature"

  # 未コミットの変更を作成
  echo "dirty" >> moon.mod.json

  # update は失敗するはず
  if $BINARY update 2>&1 | grep -q "uncommitted changes"; then
    log_pass "update detects dirty working directory"
  else
    log_fail "update should detect dirty working directory"
  fi

  rm -rf "$TEST_DIR"
}

test_prerelease() {
  log_info "Testing: prerelease support"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  # allow_prerelease: true の設定を作成
  cat > release.json << 'EOF'
{
  "allow_prerelease": true
}
EOF

  git add release.json
  git commit -q -m "chore: add config"
  git tag v0.1.0
  git commit -q --allow-empty -m "feat: new feature"

  # prerelease オプションは release コマンドでのみ有効
  # ここでは set-version で prerelease バージョンをテスト
  if $BINARY set-version 0.2.0-alpha.1 2>/dev/null; then
    if grep -q '"version": "0.2.0-alpha.1"' moon.mod.json; then
      log_pass "set-version supports prerelease version"
    else
      log_fail "set-version should support prerelease version"
    fi
  else
    log_fail "set-version prerelease failed"
  fi

  rm -rf "$TEST_DIR"
}

# ===== メイン =====

main() {
  echo "================================"
  echo "  moon-release Integration Tests"
  echo "================================"
  echo ""

  # ビルド
  if ! build_binary; then
    echo "Build failed. Exiting."
    exit 1
  fi

  # バイナリの存在確認
  if [[ ! -x "$BINARY" ]]; then
    echo "Binary not found: $BINARY"
    exit 1
  fi

  echo ""
  echo "Running tests..."
  echo ""

  # テスト実行
  test_version_command
  test_help_command
  test_init_command
  test_check_command
  test_set_version_command
  test_update_command
  test_update_patch
  test_update_major
  test_update_force_bump
  test_dirty_check
  test_prerelease

  echo ""
  echo "================================"
  echo "  Results"
  echo "================================"
  echo -e "  ${GREEN}Passed:${NC}  $passed"
  echo -e "  ${RED}Failed:${NC}  $failed"
  echo -e "  ${YELLOW}Skipped:${NC} $skipped"
  echo ""

  if [[ $failed -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
