#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/libimobiledevice"
BIN_DIR="$BUILD_DIR/bin"
LIB_DIR="$BUILD_DIR/lib"

echo "═══════════════════════════════════════════════════════"
echo "Verifying binary dependencies"
echo "═══════════════════════════════════════════════════════"

ERRORS=0

verify_binary() {
    local binary=$1
    local binary_name=$(basename "$binary")

    echo ""
    echo "─────────────────────────────────────────────────────"
    echo "Verifying: $binary_name"
    echo "─────────────────────────────────────────────────────"

    # Check for @rpath
    local rpath_count=$(otool -l "$binary" | grep -c "LC_RPATH" || true)
    if [ "$rpath_count" -gt 0 ]; then
        echo "✓ RPATH configured:"
        otool -l "$binary" | grep -A 2 "LC_RPATH" | grep "path" | sed 's/^/  /'
    else
        echo "✗ No RPATH found"
        ((ERRORS++))
    fi

    # Check dependencies
    echo ""
    echo "Dependencies:"
    otool -L "$binary" | grep -v "$binary_name" | sed 's/^/  /'

    # Check for problematic absolute paths
    local abs_paths=$(otool -L "$binary" | grep -v "$binary_name" | grep -v "@rpath" | grep -v "/usr/lib" | grep -v "/System" | awk '{print $1}' || true)
    if [ -n "$abs_paths" ]; then
        echo ""
        echo "⚠ Warning: Found absolute paths:"
        echo "$abs_paths" | sed 's/^/  /'
        ((ERRORS++))
    else
        echo ""
        echo "✓ No problematic absolute paths"
    fi
}

# Verify all binaries
if [ -d "$BIN_DIR" ]; then
    for binary in "$BIN_DIR"/*; do
        if [ -f "$binary" ] && [ -x "$binary" ]; then
            verify_binary "$binary"
        fi
    done
else
    echo "Error: Binary directory not found: $BIN_DIR"
    exit 1
fi

# Test execution
echo ""
echo "═══════════════════════════════════════════════════════"
echo "Testing binary execution"
echo "═══════════════════════════════════════════════════════"

# Clear DYLD_LIBRARY_PATH to test @rpath
unset DYLD_LIBRARY_PATH

if [ -f "$BIN_DIR/idevice_id" ]; then
    echo ""
    echo "Testing idevice_id --help..."
    if "$BIN_DIR/idevice_id" --help &>/dev/null; then
        echo "✓ idevice_id runs successfully without DYLD_LIBRARY_PATH"
    else
        echo "✗ idevice_id failed to run"
        ((ERRORS++))
    fi
fi

echo ""
echo "═══════════════════════════════════════════════════════"
if [ $ERRORS -eq 0 ]; then
    echo "✅ Verification passed!"
    echo "═══════════════════════════════════════════════════════"
    exit 0
else
    echo "❌ Verification failed with $ERRORS error(s)"
    echo "═══════════════════════════════════════════════════════"
    exit 1
fi
