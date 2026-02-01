# moon-release Justfile
# MoonBit release automation tool

# Default recipe
default:
    @just --list

# Claude Code
claude *args:
    claude --dangerously-skip-permissions {{args}}

# === Build ===

# Build all packages
build:
    moon build

# Build for release
build-release:
    moon build --release

# Build native target
build-native:
    moon build --target native

# === Test ===

# Run all tests
test:
    moon test

# Run tests with verbose output
test-verbose:
    moon test --verbose

# Run integration tests
test-integration:
    ./tests/integration/run_tests.sh

# Run all tests (unit + integration)
test-all: test test-integration

# === Development ===

# Check code without building
check:
    moon check

# Format code
fmt:
    moon fmt

# Update dependencies
update:
    moon update

# === Run ===

# Run the CLI (native target)
run *ARGS:
    moon run src/main {{ARGS}}

# === Cleaning ===

# Clean build artifacts
clean:
    moon clean

# === Documentation ===

# Generate documentation
doc:
    moon doc

# === Package Management ===

# Publish to mooncakes.io (dry-run)
publish-dry:
    moon publish --dry-run

# Publish to mooncakes.io
publish:
    moon publish
