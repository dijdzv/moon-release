#!/usr/bin/env python3
"""
Pre-build script for OS-specific link configuration.
Detects Windows and emits ws2_32 linker flag.
"""

import json
import sys
import platform

def main():
    # Read BuildScriptEnvironment from stdin
    try:
        env = json.load(sys.stdin)
    except:
        env = {}

    # Detect OS
    is_windows = platform.system() == "Windows"

    # Build output
    output = {
        "vars": {
            "is_windows": "true" if is_windows else "false"
        },
        "link_configs": []
    }

    # Add Windows-specific link flags
    if is_windows:
        output["link_configs"] = [
            {
                "package": "moon-release/src/main",
                "link_flags": "-lws2_32"
            }
        ]

    # Output to stdout
    print(json.dumps(output))

if __name__ == "__main__":
    main()
