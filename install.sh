#!/bin/bash
# moon-release installer for Linux and macOS
# Usage: curl -fsSL https://raw.githubusercontent.com/dijdzv/moon-release/main/install.sh | bash

set -e

REPO="dijdzv/moon-release"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
BINARY_NAME="moon-release"

# Detect OS and architecture
detect_platform() {
    local os arch

    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Linux)
            case "$arch" in
                x86_64|amd64)
                    echo "linux-x86_64"
                    ;;
                *)
                    echo "Error: Unsupported architecture: $arch" >&2
                    echo "Supported: x86_64" >&2
                    exit 1
                    ;;
            esac
            ;;
        Darwin)
            case "$arch" in
                arm64|aarch64)
                    echo "macos-arm64"
                    ;;
                x86_64)
                    echo "Error: macOS Intel is not supported. Please use macOS ARM (Apple Silicon)." >&2
                    exit 1
                    ;;
                *)
                    echo "Error: Unsupported architecture: $arch" >&2
                    exit 1
                    ;;
            esac
            ;;
        *)
            echo "Error: Unsupported OS: $os" >&2
            echo "Supported: Linux, macOS (ARM)" >&2
            exit 1
            ;;
    esac
}

# Get latest release version
get_latest_version() {
    curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | \
        grep '"tag_name"' | \
        sed 's/.*"tag_name": *"v\([^"]*\)".*/\1/'
}

# Main installation
main() {
    echo "Installing moon-release..."
    echo ""

    # Detect platform
    local platform
    platform="$(detect_platform)"
    echo "Detected platform: $platform"

    # Get latest version
    local version
    version="$(get_latest_version)"
    if [ -z "$version" ]; then
        echo "Error: Could not determine latest version" >&2
        exit 1
    fi
    echo "Latest version: v$version"

    # Construct download URL
    local artifact_name="moon-release-$platform"
    local url="https://github.com/$REPO/releases/download/v$version/$artifact_name"
    echo "Download URL: $url"

    # Create install directory
    mkdir -p "$INSTALL_DIR"

    # Download binary
    echo ""
    echo "Downloading..."
    local tmp_file
    tmp_file="$(mktemp)"
    if ! curl -fsSL "$url" -o "$tmp_file"; then
        echo "Error: Failed to download binary" >&2
        rm -f "$tmp_file"
        exit 1
    fi

    # Install binary
    chmod +x "$tmp_file"
    mv "$tmp_file" "$INSTALL_DIR/$BINARY_NAME"

    echo ""
    echo "Installed to: $INSTALL_DIR/$BINARY_NAME"

    # Check if install dir is in PATH
    if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
        echo ""
        echo "WARNING: $INSTALL_DIR is not in your PATH"
        echo ""
        echo "Add it to your shell profile:"
        echo "  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.bashrc"
        echo "  # or for zsh:"
        echo "  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.zshrc"
    fi

    echo ""
    echo "Installation complete!"
    echo "Run 'moon-release --help' to get started."
}

main "$@"
