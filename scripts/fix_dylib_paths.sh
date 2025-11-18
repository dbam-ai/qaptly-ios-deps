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

# Build a map of dylib filenames to their install names
INSTALL_NAME_MAP_FILE=$(mktemp)
trap "rm -f $INSTALL_NAME_MAP_FILE" EXIT
if [ -d "$LIB_DIR" ]; then
    for dylib in "$LIB_DIR"/*.dylib; do
        if [ -f "$dylib" ] && [ ! -L "$dylib" ]; then
            install_name=$(otool -D "$dylib" | tail -1)
            install_basename=$(basename "$install_name")
            file_basename=$(basename "$dylib")
            echo "$file_basename=$install_basename" >> "$INSTALL_NAME_MAP_FILE"
        fi
    done
fi

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
            # Use the install name from the map if available, otherwise use filename
            local install_name=$(grep "^$lib_name=" "$INSTALL_NAME_MAP_FILE" | cut -d= -f2)
            if [ -z "$install_name" ]; then
                install_name="$lib_name"
            fi
            echo "  Fixing: $dep -> @rpath/$install_name"
            install_name_tool -change "$dep" "@rpath/$install_name" "$binary"
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

    # Get current install name and preserve the base name (without path)
    local current_id=$(otool -D "$dylib" | tail -1)
    local install_basename=$(basename "$current_id")

    # Fix the dylib's own install name (preserve the original name, just change path to @rpath)
    install_name_tool -id "@rpath/$install_basename" "$dylib"
    echo "  Set install name: @rpath/$install_basename"

    # Add @rpath to search in same directory (for dylib-to-dylib dependencies)
    install_name_tool -add_rpath "@loader_path" "$dylib" 2>/dev/null || true
    echo "  Added rpath: @loader_path"

    # Fix references to other dylibs (skip the install name line)
    otool -L "$dylib" | tail -n +2 | awk '{print $1}' | while read -r dep; do
        # Skip system libraries
        if [[ "$dep" == /usr/lib/* ]] || [[ "$dep" == /System/* ]]; then
            continue
        fi

        # Skip if this is a self-reference (install name)
        local dep_basename=$(basename "$dep")
        if [[ "$dep_basename" == "$install_basename" ]]; then
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

# Re-sign all binaries and dylibs (install_name_tool invalidates signatures)
echo ""
echo "─────────────────────────────────────────────────────"
echo "Re-signing Binaries and Libraries"
echo "─────────────────────────────────────────────────────"

if [ -d "$BIN_DIR" ]; then
    for binary in "$BIN_DIR"/*; do
        if [ -f "$binary" ] && [ -x "$binary" ]; then
            codesign --force --sign - "$binary" 2>/dev/null && echo "  ✓ Signed $(basename "$binary")"
        fi
    done
fi

if [ -d "$LIB_DIR" ]; then
    for dylib in "$LIB_DIR"/*.dylib; do
        if [ -f "$dylib" ] && [ ! -L "$dylib" ]; then
            codesign --force --sign - "$dylib" 2>/dev/null && echo "  ✓ Signed $(basename "$dylib")"
        fi
    done
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "✅ All paths fixed and binaries re-signed successfully"
echo "═══════════════════════════════════════════════════════"
