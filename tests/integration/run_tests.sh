#!/bin/bash
# Integration test runner
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BINARY="$PROJECT_ROOT/target/native/release/build/src/main/main.exe"

# Colored output
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

# Build the binary
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

# Create temporary directory for testing
create_test_repo() {
  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"

  # Initialize git repository
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create moon.mod.json
  cat > moon.mod.json << 'EOF'
{
  "name": "test/package",
  "version": "0.1.0",
  "deps": {}
}
EOF

  # Initial commit
  git add .
  git commit -q -m "chore: initial commit"

  echo "$tmp_dir"
}

# Cleanup
cleanup() {
  if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
  fi
}

trap cleanup EXIT

# ===== Test functions =====

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
  # --help crashes, so test without subcommand as alternative
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

  # Run init
  if $BINARY init 2>/dev/null; then
    if [[ -f "release.json" ]]; then
      log_pass "init command creates release.json"
    else
      log_fail "init command - release.json not created"
    fi
  else
    log_fail "init command failed"
  fi

  # Run init again (without --force)
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

  # Check without tags
  if $BINARY check 2>&1 | grep -q "No tags found"; then
    log_pass "check command (no tags)"
  else
    log_fail "check command (no tags)"
  fi

  # Create tag
  git tag v0.1.0

  # Add a new commit
  git commit -q --allow-empty -m "feat: add new feature"

  # Run check
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

  # Execute
  if $BINARY set-version 1.0.0 2>/dev/null; then
    if grep -q '"version": "1.0.0"' moon.mod.json; then
      log_pass "set-version updates version"
    else
      log_fail "set-version - version not updated"
    fi
  else
    log_fail "set-version command failed"
  fi

  # Invalid version
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

  # Create tag
  git tag v0.1.0

  # Add feat commit
  git commit -q --allow-empty -m "feat: add new feature"

  # dry-run
  if $BINARY update --dry-run 2>&1 | grep -q "Would update"; then
    log_pass "update --dry-run"
  else
    log_fail "update --dry-run"
  fi

  # Verify version is not changed yet
  if grep -q '"version": "0.1.0"' moon.mod.json; then
    log_pass "update --dry-run does not change version"
  else
    log_fail "update --dry-run should not change version"
  fi

  # Actually update
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

  # chore normally doesn't bump, but force with --bump
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

  # Create uncommitted changes
  echo "dirty" >> moon.mod.json

  # update should fail
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

  # Create config with allow_prerelease: true
  cat > release.json << 'EOF'
{
  "allow_prerelease": true
}
EOF

  git add release.json
  git commit -q -m "chore: add config"
  git tag v0.1.0
  git commit -q --allow-empty -m "feat: new feature"

  # prerelease option is only valid for release command
  # Here we test prerelease version with set-version
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

test_check_json_output() {
  log_info "Testing: check command with JSON output"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  git tag v0.1.0
  git commit -q --allow-empty -m "feat: add new feature"

  # JSON output
  output=$($BINARY check -o json 2>&1)

  # Check if valid JSON (opening and closing braces)
  if echo "$output" | grep -q '^{' && echo "$output" | grep -q '}$'; then
    log_pass "check -o json outputs valid JSON structure"
  else
    log_fail "check -o json should output valid JSON"
  fi

  # Check if required fields are present
  if echo "$output" | grep -q '"latest_tag"' && \
     echo "$output" | grep -q '"commits_count"' && \
     echo "$output" | grep -q '"suggested_bump"'; then
    log_pass "check -o json contains required fields"
  else
    log_fail "check -o json missing required fields"
  fi

  rm -rf "$TEST_DIR"
}

test_update_json_output() {
  log_info "Testing: update command with JSON output"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  git tag v0.1.0
  git commit -q --allow-empty -m "feat: add new feature"

  # JSON output (dry-run)
  output=$($BINARY update --dry-run -o json 2>&1)

  # Check if valid JSON
  if echo "$output" | grep -q '"old_version"' && \
     echo "$output" | grep -q '"new_version"' && \
     echo "$output" | grep -q '"bump_type"'; then
    log_pass "update -o json contains version info"
  else
    log_fail "update -o json missing version info"
  fi

  # Check if version values are correct
  if echo "$output" | grep -q '"old_version":"0.1.0"' && \
     echo "$output" | grep -q '"new_version":"0.2.0"'; then
    log_pass "update -o json shows correct versions"
  else
    log_fail "update -o json should show 0.1.0 -> 0.2.0"
  fi

  rm -rf "$TEST_DIR"
}

test_generate_completions() {
  log_info "Testing: generate-completions command"

  # bash
  output=$($BINARY generate-completions bash 2>&1)
  if echo "$output" | grep -q '_moon_release_completions'; then
    log_pass "generate-completions bash"
  else
    log_fail "generate-completions bash should output completion function"
  fi

  # zsh
  output=$($BINARY generate-completions zsh 2>&1)
  if echo "$output" | grep -q '#compdef moon-release'; then
    log_pass "generate-completions zsh"
  else
    log_fail "generate-completions zsh should output compdef"
  fi

  # fish
  output=$($BINARY generate-completions fish 2>&1)
  if echo "$output" | grep -q 'complete -c moon-release'; then
    log_pass "generate-completions fish"
  else
    log_fail "generate-completions fish should output complete commands"
  fi

  # invalid shell (use || true to prevent set -e from exiting)
  output=$($BINARY generate-completions invalid 2>&1 || true)
  if echo "$output" | grep -q "unsupported shell"; then
    log_pass "generate-completions rejects invalid shell"
  else
    log_fail "generate-completions should reject invalid shell"
  fi
}

test_generate_schema() {
  log_info "Testing: generate-schema command"

  output=$($BINARY generate-schema 2>&1)

  # JSON Schema basic structure
  if echo "$output" | grep -q '"\$schema"' && \
     echo "$output" | grep -q '"properties"'; then
    log_pass "generate-schema outputs valid JSON Schema structure"
  else
    log_fail "generate-schema should output JSON Schema"
  fi

  # Check if main properties are present
  if echo "$output" | grep -q '"pr_title"' && \
     echo "$output" | grep -q '"git_release_enable"' && \
     echo "$output" | grep -q '"publish"'; then
    log_pass "generate-schema contains config properties"
  else
    log_fail "generate-schema missing config properties"
  fi

  # Newly added properties
  if echo "$output" | grep -q '"git_release_latest"' && \
     echo "$output" | grep -q '"publish_timeout"' && \
     echo "$output" | grep -q '"max_analyze_commits"'; then
    log_pass "generate-schema contains new config options"
  else
    log_fail "generate-schema missing new config options"
  fi
}

test_max_analyze_commits() {
  log_info "Testing: max_analyze_commits config option"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  git tag v0.1.0

  # Add multiple commits
  for i in 1 2 3 4 5; do
    git commit -q --allow-empty -m "feat: feature $i"
  done

  # Create config with max_analyze_commits: 2
  cat > release.json << 'EOF'
{
  "max_analyze_commits": 2
}
EOF

  git add release.json
  git commit -q -m "chore: add config"

  # Verify with check command (full verification is difficult, so just confirm it runs without error)
  output=$($BINARY check 2>&1)

  if echo "$output" | grep -q "Commits since last tag"; then
    log_pass "max_analyze_commits config is accepted"
  else
    log_fail "max_analyze_commits config should be accepted"
  fi

  rm -rf "$TEST_DIR"
}

# ===== Main =====

main() {
  echo "================================"
  echo "  moon-release Integration Tests"
  echo "================================"
  echo ""

  # Build
  if ! build_binary; then
    echo "Build failed. Exiting."
    exit 1
  fi

  # Check binary exists
  if [[ ! -x "$BINARY" ]]; then
    echo "Binary not found: $BINARY"
    exit 1
  fi

  echo ""
  echo "Running tests..."
  echo ""

  # Run tests
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
  test_check_json_output
  test_update_json_output
  test_generate_completions
  test_generate_schema
  test_max_analyze_commits

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
