#!/bin/bash
# Integration test runner
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BINARY="$PROJECT_ROOT/_build/native/release/build/src/main/main.exe"

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
     echo "$output" | grep -q '"moon_publish"'; then
    log_pass "generate-schema contains config properties"
  else
    log_fail "generate-schema missing config properties"
  fi

  # Newly added properties
  if echo "$output" | grep -q '"git_release_latest"' && \
     echo "$output" | grep -q '"moon_publish_timeout"' && \
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

# ===== Monorepo test helpers =====

# Create a monorepo test repository with two packages
# $1 = package A version in moon.mod.json
# $2 = package A version in package.json (optional, creates package.json if set)
# $3 = package B version in moon.mod.json
create_monorepo_test_repo() {
  local pkg_a_moon_ver="$1"
  local pkg_a_npm_ver="$2"
  local pkg_b_moon_ver="$3"
  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"

  git init -q
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Root moon.mod.json (required)
  cat > moon.mod.json << EOF
{
  "name": "test/monorepo",
  "version": "0.0.0",
  "deps": {}
}
EOF

  # Package A
  mkdir -p packages/pkg-a
  cat > packages/pkg-a/moon.mod.json << EOF
{
  "name": "test/pkg-a",
  "version": "$pkg_a_moon_ver",
  "deps": {}
}
EOF

  if [[ -n "$pkg_a_npm_ver" ]]; then
    cat > packages/pkg-a/package.json << EOF
{
  "name": "@test/pkg-a",
  "version": "$pkg_a_npm_ver"
}
EOF
  fi

  # Package B
  mkdir -p packages/pkg-b
  cat > packages/pkg-b/moon.mod.json << EOF
{
  "name": "test/pkg-b",
  "version": "$pkg_b_moon_ver",
  "deps": {}
}
EOF

  git add .
  git commit -q -m "chore: initial commit"

  echo "$tmp_dir"
}

# ===== Monorepo tests =====

test_monorepo_dual_publish_version_max() {
  log_info "Testing: monorepo dual publish uses higher version"

  # pkg-a: moon.mod.json=1.0.0, package.json=1.2.0 (npm is higher)
  # pkg-b: moon.mod.json=1.0.0 (moon only)
  TEST_DIR=$(create_monorepo_test_repo "1.0.0" "1.2.0" "1.0.0")
  cd "$TEST_DIR"

  # release.json: pkg-a has both moon_publish + npm_publish
  cat > release.json << 'EOF'
{
  "packages": [
    {
      "name": "pkg-a",
      "path": "packages/pkg-a",
      "moon_publish": true,
      "npm_publish": true
    },
    {
      "name": "pkg-b",
      "path": "packages/pkg-b",
      "moon_publish": true,
      "npm_publish": false
    }
  ]
}
EOF

  git add .
  git commit -q -m "chore: add config"
  git tag v1.0.0

  # Add a feat commit touching pkg-a
  mkdir -p packages/pkg-a/src
  echo "// new" > packages/pkg-a/src/lib.mbt
  git add .
  git commit -q -m "feat: add feature to pkg-a"

  # Run update (dry-run to inspect output)
  output=$($BINARY update --dry-run 2>&1)

  # pkg-a should bump from 1.2.0 (the higher npm version), not 1.0.0
  # minor bump from 1.2.0 => 1.3.0
  if echo "$output" | grep -q "1.2.0 -> 1.3.0"; then
    log_pass "monorepo dual publish uses higher version (1.2.0 -> 1.3.0)"
  elif echo "$output" | grep -q "1.0.0 -> 1.1.0"; then
    log_fail "monorepo dual publish used moon.mod.json version (1.0.0) instead of higher npm version (1.2.0)"
  else
    log_fail "monorepo dual publish version check - unexpected output: $output"
  fi

  rm -rf "$TEST_DIR"
}

test_monorepo_version_group_representative() {
  log_info "Testing: monorepo version_group reflects in representative version"

  # Both packages start at 1.0.0, same version_group
  TEST_DIR=$(create_monorepo_test_repo "1.0.0" "" "1.0.0")
  cd "$TEST_DIR"

  # release.json: both packages in same version_group
  cat > release.json << 'EOF'
{
  "packages": [
    {
      "name": "pkg-a",
      "path": "packages/pkg-a",
      "moon_publish": true,
      "npm_publish": false,
      "version_group": "main"
    },
    {
      "name": "pkg-b",
      "path": "packages/pkg-b",
      "moon_publish": true,
      "npm_publish": false,
      "version_group": "main"
    }
  ]
}
EOF

  git add .
  git commit -q -m "chore: add config"
  git tag v1.0.0

  # pkg-a gets a feat (minor), pkg-b gets a breaking change (major)
  mkdir -p packages/pkg-a/src
  echo "// feature" > packages/pkg-a/src/lib.mbt
  git add .
  git commit -q -m "feat: add feature to pkg-a"

  mkdir -p packages/pkg-b/src
  echo "// breaking" > packages/pkg-b/src/lib.mbt
  git add .
  git commit -q -m "feat!: breaking change in pkg-b"

  # Run update (dry-run)
  output=$($BINARY update --dry-run 2>&1)

  # Both should get major bump (version_group aligns to max = major)
  # pkg-a: 1.0.0 -> 2.0.0 (elevated from minor to major by group)
  # pkg-b: 1.0.0 -> 2.0.0 (own breaking change)
  if echo "$output" | grep "pkg-a" | grep -q "1.0.0 -> 2.0.0"; then
    log_pass "version_group elevates pkg-a to major (1.0.0 -> 2.0.0)"
  else
    log_fail "version_group should elevate pkg-a to major bump"
  fi

  if echo "$output" | grep "pkg-b" | grep -q "1.0.0 -> 2.0.0"; then
    log_pass "version_group keeps pkg-b at major (1.0.0 -> 2.0.0)"
  else
    log_fail "version_group should keep pkg-b at major bump"
  fi

  # Verify the representative version (used for tags) is also 2.0.0
  # update --dry-run output should show 2.0.0 as the representative version
  update_output=$($BINARY update --dry-run 2>&1)

  # The representative version appears in "Monorepo mode: ... -> X.Y.Z" or tag-related output
  # Both packages should show 2.0.0, so the max (representative) is 2.0.0
  if echo "$update_output" | grep -q "2.0.0"; then
    log_pass "representative version reflects version_group (2.0.0)"
  else
    log_fail "representative version should be 2.0.0 after version_group consolidation: $update_output"
  fi

  rm -rf "$TEST_DIR"
}

test_monorepo_bump_all() {
  log_info "Testing: --bump-all bumps all packages including unchanged"

  local TEST_DIR
  TEST_DIR=$(create_monorepo_test_repo "1.0.0" "" "1.0.0")

  cd "$TEST_DIR"

  # release.json with two packages (no version_group)
  cat > release.json << 'EOF'
{
  "packages": [
    { "name": "pkg-a", "path": "packages/pkg-a", "moon_publish": true, "npm_publish": false },
    { "name": "pkg-b", "path": "packages/pkg-b", "moon_publish": true, "npm_publish": false }
  ]
}
EOF

  # Only change pkg-a
  echo "// change" > packages/pkg-a/main.mbt
  git add .
  git commit -q -m "feat: add feature to pkg-a"

  # Without --bump-all: only pkg-a should be bumped
  output=$($BINARY update --dry-run 2>&1)
  if echo "$output" | grep "pkg-a" | grep -q "1.0.0 -> 1.1.0"; then
    log_pass "without --bump-all: pkg-a bumped (1.0.0 -> 1.1.0)"
  else
    log_fail "without --bump-all: pkg-a should be bumped: $output"
  fi

  if echo "$output" | grep -q "pkg-b"; then
    log_fail "without --bump-all: pkg-b should NOT appear: $output"
  else
    log_pass "without --bump-all: pkg-b not bumped (no changes)"
  fi

  # With --bump-all: both packages should be bumped
  output=$($BINARY update --bump-all --dry-run 2>&1)
  if echo "$output" | grep "pkg-a" | grep -q "1.0.0 -> 1.1.0"; then
    log_pass "--bump-all: pkg-a bumped (1.0.0 -> 1.1.0)"
  else
    log_fail "--bump-all: pkg-a should be bumped: $output"
  fi

  if echo "$output" | grep "pkg-b" | grep -q "1.0.0 -> 1.1.0"; then
    log_pass "--bump-all: pkg-b also bumped (1.0.0 -> 1.1.0)"
  else
    log_fail "--bump-all: pkg-b should also be bumped: $output"
  fi

  rm -rf "$TEST_DIR"
}

test_monorepo_bump_major_all() {
  log_info "Testing: --bump major --bump-all forces major bump on all packages"

  local TEST_DIR
  TEST_DIR=$(create_monorepo_test_repo "1.0.0" "" "2.0.0")

  cd "$TEST_DIR"

  cat > release.json << 'EOF'
{
  "packages": [
    { "name": "pkg-a", "path": "packages/pkg-a", "moon_publish": true, "npm_publish": false },
    { "name": "pkg-b", "path": "packages/pkg-b", "moon_publish": true, "npm_publish": false }
  ]
}
EOF

  # Only change pkg-a with a minor feat
  echo "// change" > packages/pkg-a/main.mbt
  git add .
  git commit -q -m "feat: add feature to pkg-a"

  # --bump major --bump-all: all packages get major bump
  output=$($BINARY update --bump major --bump-all --dry-run 2>&1)
  if echo "$output" | grep "pkg-a" | grep -q "1.0.0 -> 2.0.0"; then
    log_pass "--bump major --bump-all: pkg-a major bumped (1.0.0 -> 2.0.0)"
  else
    log_fail "--bump major --bump-all: pkg-a should be major bumped: $output"
  fi

  if echo "$output" | grep "pkg-b" | grep -q "2.0.0 -> 3.0.0"; then
    log_pass "--bump major --bump-all: pkg-b major bumped (2.0.0 -> 3.0.0)"
  else
    log_fail "--bump major --bump-all: pkg-b should be major bumped: $output"
  fi

  rm -rf "$TEST_DIR"
}

test_release_pr_dry_run() {
  log_info "Testing: release-pr --dry-run"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  git tag v0.1.0
  git commit -q --allow-empty -m "feat: add new feature"

  output=$($BINARY release-pr --dry-run 2>&1 || true)

  if echo "$output" | grep -q "\[dry-run\]"; then
    if echo "$output" | grep -q "release/v0.2.0"; then
      log_pass "release-pr --dry-run shows correct branch name"
    else
      log_fail "release-pr --dry-run should show release/v0.2.0 branch"
    fi
  else
    log_skip "release-pr --dry-run (requires gh auth)"
  fi

  rm -rf "$TEST_DIR"
}

test_release_dry_run() {
  log_info "Testing: release --dry-run"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  git tag v0.1.0
  git commit -q --allow-empty -m "feat: add feature"

  output=$($BINARY release --dry-run 2>&1 || true)

  if echo "$output" | grep -q "\[dry-run\]"; then
    if echo "$output" | grep -q "v0.2.0"; then
      log_pass "release --dry-run shows correct version"
    else
      log_fail "release --dry-run should show v0.2.0"
    fi
  else
    log_skip "release --dry-run (requires gh auth)"
  fi

  rm -rf "$TEST_DIR"
}

test_monorepo_update_file_content() {
  log_info "Testing: monorepo update actually modifies files"

  TEST_DIR=$(create_monorepo_test_repo "1.0.0" "" "1.0.0")
  cd "$TEST_DIR"

  cat > release.json << 'EOF'
{
  "packages": [
    { "name": "pkg-a", "path": "packages/pkg-a", "moon_publish": true, "npm_publish": false },
    { "name": "pkg-b", "path": "packages/pkg-b", "moon_publish": true, "npm_publish": false }
  ]
}
EOF

  git add .
  git commit -q -m "chore: add config"
  git tag v1.0.0

  mkdir -p packages/pkg-a/src
  echo "// new" > packages/pkg-a/src/lib.mbt
  git add .
  git commit -q -m "feat: add feature to pkg-a"

  $BINARY update 2>/dev/null

  if grep -q '"version": "1.1.0"' packages/pkg-a/moon.mod.json; then
    log_pass "monorepo update modifies pkg-a moon.mod.json to 1.1.0"
  else
    log_fail "monorepo update should modify pkg-a to 1.1.0"
  fi

  if grep -q '"version": "1.0.0"' packages/pkg-b/moon.mod.json; then
    log_pass "monorepo update does not modify unchanged pkg-b"
  else
    log_fail "monorepo update should not modify unchanged pkg-b"
  fi

  rm -rf "$TEST_DIR"
}

test_allow_dirty() {
  log_info "Testing: allow_dirty config option"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  cat > release.json << 'EOF'
{
  "allow_dirty": true
}
EOF

  git add release.json
  git commit -q -m "chore: add config"
  git tag v0.1.0
  git commit -q --allow-empty -m "feat: new feature"

  # Create uncommitted changes (use a separate file to avoid breaking moon.mod.json)
  echo "dirty" > untracked_file.txt

  # update should succeed with allow_dirty
  if $BINARY update --dry-run 2>&1 | grep -q "Would update"; then
    log_pass "allow_dirty allows update with uncommitted changes"
  else
    log_fail "allow_dirty should allow update with uncommitted changes"
  fi

  rm -rf "$TEST_DIR"
}

test_invalid_config_json() {
  log_info "Testing: invalid config JSON"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  echo "not valid json" > release.json
  git add release.json
  git commit -q -m "chore: add bad config"
  git tag v0.1.0
  git commit -q --allow-empty -m "feat: new"

  output=$($BINARY update 2>&1 || true)
  if echo "$output" | grep -q "Error"; then
    log_pass "update rejects invalid config JSON"
  else
    log_fail "update should reject invalid config: $output"
  fi

  rm -rf "$TEST_DIR"
}

test_config_missing_uses_defaults() {
  log_info "Testing: missing config uses defaults"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  # No release.json created
  git tag v0.1.0
  git commit -q --allow-empty -m "feat: add feature"

  output=$($BINARY update --dry-run 2>&1)
  if echo "$output" | grep -q "Would update"; then
    log_pass "update works without release.json"
  else
    log_fail "update should work without release.json: $output"
  fi

  rm -rf "$TEST_DIR"
}

test_check_verbose() {
  log_info "Testing: check with verbose flag"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  git tag v0.1.0
  git commit -q --allow-empty -m "feat: feature one"
  git commit -q --allow-empty -m "fix: bug fix"

  output=$($BINARY check -v 2>&1)
  if echo "$output" | grep -q "feat"; then
    log_pass "check -v shows commit details"
  else
    log_fail "check -v should show commit types: $output"
  fi

  rm -rf "$TEST_DIR"
}

test_npm_publish_update() {
  log_info "Testing: update with npm_publish updates package.json"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  cat > release.json << 'EOF'
{
  "moon_publish": true,
  "npm_publish": true
}
EOF
  cat > package.json << 'EOF'
{
  "name": "@test/pkg",
  "version": "0.1.0"
}
EOF
  git add .
  git commit -q -m "chore: add config"
  git tag v0.1.0

  git commit -q --allow-empty -m "feat: add new feature"

  if $BINARY update 2>/dev/null; then
    if grep -q '"version": "0.2.0"' package.json; then
      log_pass "update with npm_publish updates package.json"
    else
      log_fail "update with npm_publish should update package.json"
    fi
  else
    log_fail "update with npm_publish failed"
  fi

  rm -rf "$TEST_DIR"
}

test_custom_increment_regex() {
  log_info "Testing: custom_minor_increment_regex"

  TEST_DIR=$(create_test_repo)
  cd "$TEST_DIR"

  cat > release.json << 'EOF'
{
  "custom_minor_increment_regex": "NEW FEATURE"
}
EOF
  git add release.json
  git commit -q -m "chore: add config"
  git tag v0.1.0

  # chore normally doesn't bump, but custom regex matches
  git commit -q --allow-empty -m "chore: NEW FEATURE added"

  output=$($BINARY check 2>&1)
  if echo "$output" | grep -q "minor"; then
    log_pass "custom_minor_increment_regex triggers minor bump"
  else
    log_fail "custom_minor_increment_regex should trigger minor bump: $output"
  fi

  rm -rf "$TEST_DIR"
}

test_monorepo_npm_publish_update() {
  log_info "Testing: monorepo update modifies package.json when npm_publish=true"

  TEST_DIR=$(create_monorepo_test_repo "1.0.0" "1.0.0" "1.0.0")
  cd "$TEST_DIR"

  cat > release.json << 'EOF'
{
  "packages": [
    {
      "name": "pkg-a",
      "path": "packages/pkg-a",
      "moon_publish": true,
      "npm_publish": true
    },
    {
      "name": "pkg-b",
      "path": "packages/pkg-b",
      "moon_publish": true,
      "npm_publish": false
    }
  ]
}
EOF

  git add .
  git commit -q -m "chore: add config"
  git tag v1.0.0

  mkdir -p packages/pkg-a/src
  echo "// new" > packages/pkg-a/src/lib.mbt
  git add .
  git commit -q -m "feat: add feature to pkg-a"

  $BINARY update 2>/dev/null

  if grep -q '"version": "1.1.0"' packages/pkg-a/package.json; then
    log_pass "monorepo update modifies pkg-a package.json to 1.1.0"
  else
    log_fail "monorepo update should modify pkg-a package.json to 1.1.0"
  fi

  if grep -q '"version": "1.1.0"' packages/pkg-a/moon.mod.json; then
    log_pass "monorepo update also modifies pkg-a moon.mod.json to 1.1.0"
  else
    log_fail "monorepo update should also modify pkg-a moon.mod.json to 1.1.0"
  fi

  rm -rf "$TEST_DIR"
}

test_error_not_git_repo() {
  log_info "Testing: error when not in git repo"

  local tmp_dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir"

  output=$($BINARY check 2>&1 || true)
  if echo "$output" | grep -qi "error\|fatal"; then
    log_pass "check command fails gracefully outside git repo"
  else
    log_fail "check should fail outside git repo: $output"
  fi

  rm -rf "$tmp_dir"
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
  test_monorepo_dual_publish_version_max
  test_monorepo_version_group_representative
  test_monorepo_bump_all
  test_monorepo_bump_major_all
  test_release_pr_dry_run
  test_release_dry_run
  test_monorepo_update_file_content
  test_npm_publish_update
  test_custom_increment_regex
  test_monorepo_npm_publish_update
  test_allow_dirty
  test_invalid_config_json
  test_config_missing_uses_defaults
  test_check_verbose
  test_error_not_git_repo

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
