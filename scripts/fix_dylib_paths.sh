#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/libimobiledevice"
BIN_DIR="$BUILD_DIR/bin"
LIB_DIR="$BUILD_DIR/lib"

echo "═══════════════════════════════════════════════════════"
echo "Fixing dynamic library paths"
echo "═══════════════════════════════════════════════════════"

# Function to fix a single binary
fix_binary() {
    local binary=$1
    local binary_name=$(basename "$binary")

    echo ""
    echo "Processing binary: $binary_name"

    # Add @rpath to search in ../lib relative to binary location
    install_name_tool -add_rpath "@loader_path/../lib" "$binary" 2>/dev/null || true

    # Get all library dependencies
    otool -L "$binary" | grep -v "$binary_name" | awk '{print $1}' | while read -r dep; do
        # Skip system libraries
        if [[ "$dep" == /usr/lib/* ]] || [[ "$dep" == /System/* ]]; then
            continue
        fi

        local lib_name=$(basename "$dep")

        # Check if this library exists in our lib directory
        if [ -f "$LIB_DIR/$lib_name" ]; then
            echo "  Fixing: $dep -> @rpath/$lib_name"
            install_name_tool -change "$dep" "@rpath/$lib_name" "$binary"
        fi
    done

    echo "  ✓ Binary fixed"
}

# Function to fix a dylib's internal references
fix_dylib() {
    local dylib=$1
    local lib_name=$(basename "$dylib")

    echo ""
    echo "Processing dylib: $lib_name"

    # Fix the dylib's own install name
    install_name_tool -id "@rpath/$lib_name" "$dylib"
    echo "  Set install name: @rpath/$lib_name"

    # Add @rpath to search in same directory (for dylib-to-dylib dependencies)
    install_name_tool -add_rpath "@loader_path" "$dylib" 2>/dev/null || true
    echo "  Added rpath: @loader_path"

    # Fix references to other dylibs
    otool -L "$dylib" | grep -v "$lib_name" | awk '{print $1}' | while read -r dep; do
        # Skip system libraries
        if [[ "$dep" == /usr/lib/* ]] || [[ "$dep" == /System/* ]]; then
            continue
        fi

        local dep_name=$(basename "$dep")

        if [ -f "$LIB_DIR/$dep_name" ]; then
            echo "  Fixing: $dep -> @rpath/$dep_name"
            install_name_tool -change "$dep" "@rpath/$dep_name" "$dylib"
        fi
    done

    echo "  ✓ Dylib fixed"
}

# Process all binaries
if [ -d "$BIN_DIR" ]; then
    echo ""
    echo "─────────────────────────────────────────────────────"
    echo "Fixing Binaries"
    echo "─────────────────────────────────────────────────────"

    for binary in "$BIN_DIR"/*; do
        if [ -f "$binary" ] && [ -x "$binary" ]; then
            fix_binary "$binary"
        fi
    done
else
    echo "Warning: Binary directory not found: $BIN_DIR"
fi

# Process all dylibs
if [ -d "$LIB_DIR" ]; then
    echo ""
    echo "─────────────────────────────────────────────────────"
    echo "Fixing Dynamic Libraries"
    echo "─────────────────────────────────────────────────────"

    for dylib in "$LIB_DIR"/*.dylib; do
        if [ -f "$dylib" ]; then
            fix_dylib "$dylib"
        fi
    done
else
    echo "Warning: Library directory not found: $LIB_DIR"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "✅ All paths fixed successfully"
echo "═══════════════════════════════════════════════════════"
