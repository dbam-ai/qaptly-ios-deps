#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/libimobiledevice"
LIB_DIR="$BUILD_DIR/lib"

echo "═══════════════════════════════════════════════════════"
echo "Bundling OpenSSL dependencies"
echo "═══════════════════════════════════════════════════════"

mkdir -p "$LIB_DIR"

# Possible OpenSSL locations (check in order)
OPENSSL_PATHS=(
    "/opt/homebrew/opt/openssl@3/lib"      # Homebrew on Apple Silicon
    "/usr/local/opt/openssl@3/lib"         # Homebrew on Intel
    "/opt/homebrew/Cellar/openssl@3"       # Homebrew Cellar
    "/usr/local/Cellar/openssl@3"          # Homebrew Cellar (Intel)
)

find_and_copy_openssl() {
    for path in "${OPENSSL_PATHS[@]}"; do
        if [ -d "$path" ]; then
            echo "Found OpenSSL at: $path"

            # Find and copy libssl and libcrypto
            if find "$path" -name "libssl.3.dylib" -exec cp {} "$LIB_DIR/" \; 2>/dev/null; then
                echo "  ✓ Copied libssl.3.dylib"
            fi

            if find "$path" -name "libcrypto.3.dylib" -exec cp {} "$LIB_DIR/" \; 2>/dev/null; then
                echo "  ✓ Copied libcrypto.3.dylib"
            fi

            if [ -f "$LIB_DIR/libssl.3.dylib" ] && [ -f "$LIB_DIR/libcrypto.3.dylib" ]; then
                echo ""
                echo "✅ OpenSSL libraries bundled successfully"
                return 0
            fi
        fi
    done

    echo ""
    echo "❌ Error: OpenSSL not found in standard locations"
    echo "Please ensure OpenSSL is installed:"
    echo "  brew install openssl@3"
    return 1
}

find_and_copy_openssl
