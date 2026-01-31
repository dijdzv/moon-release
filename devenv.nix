{ pkgs, lib, ... }:

{
  packages = [
    pkgs.just
    pkgs.curl  # for moonup installation
    pkgs.git
  ];

  enterShell = ''
    # Add moon to PATH
    export PATH="$HOME/.moon/bin:$PATH"

    # Install MoonBit toolchain if not present
    if ! command -v moon &> /dev/null; then
      echo "Installing MoonBit toolchain..."
      curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
      export PATH="$HOME/.moon/bin:$PATH"
    fi

    echo "moon-release development environment"
    echo "  moon: $(moon version 2>/dev/null || echo 'not found')"
    echo "  just: $(just --version)"
  '';
}
