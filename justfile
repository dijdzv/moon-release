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
    moon run src {{ARGS}}

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

# === CI/CD Secrets ===

# Register mooncakes credentials as GitHub Secrets (reads from ~/.moon/credentials.json)
setup-mooncakes-secrets:
    #!/usr/bin/env bash
    set -euo pipefail
    CREDS="$HOME/.moon/credentials.json"
    if [ ! -f "$CREDS" ]; then
        echo "Error: $CREDS not found. Run 'moon login' first."
        exit 1
    fi
    TOKEN=$(jq -r '.token' "$CREDS")
    USERNAME=$(jq -r '.username' "$CREDS")
    if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        echo "Error: token not found in $CREDS"
        exit 1
    fi
    if [ -z "$USERNAME" ] || [ "$USERNAME" = "null" ]; then
        echo "Error: username not found in $CREDS"
        exit 1
    fi
    echo "Setting MOONCAKES_TOKEN..."
    echo "$TOKEN" | gh secret set MOONCAKES_TOKEN
    echo "Setting MOONCAKES_USERNAME..."
    echo "$USERNAME" | gh secret set MOONCAKES_USERNAME
    echo "Done! Mooncakes credentials registered as GitHub Secrets."
