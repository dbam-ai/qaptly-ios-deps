#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
DIST_DIR="$PROJECT_ROOT/dist"

# Read version from argument or use default
VERSION="${1:-1.0.0}"
PACKAGE_NAME="qaptly-ios-deps-macos-v$VERSION"
PACKAGE_DIR="$DIST_DIR/$PACKAGE_NAME"

echo "Packaging iOS dependencies v$VERSION..."

# Check if build directory exists
if [ ! -d "$BUILD_DIR/libimobiledevice" ] || [ ! -d "$BUILD_DIR/ios-deploy" ]; then
    echo "Error: Build directory not found. Please run build-all.sh first."
    exit 1
fi

# Clean and create directories
rm -rf "$DIST_DIR"
mkdir -p "$PACKAGE_DIR"

# Copy libimobiledevice binaries and libraries
echo "Copying libimobiledevice..."
mkdir -p "$PACKAGE_DIR/libimobiledevice"
if [ -d "$BUILD_DIR/libimobiledevice/bin" ]; then
    cp -R "$BUILD_DIR/libimobiledevice/bin" "$PACKAGE_DIR/libimobiledevice/"
fi
if [ -d "$BUILD_DIR/libimobiledevice/lib" ]; then
    mkdir -p "$PACKAGE_DIR/libimobiledevice/lib"
    # Copy only dylib files
    find "$BUILD_DIR/libimobiledevice/lib" -name "*.dylib" -exec cp {} "$PACKAGE_DIR/libimobiledevice/lib/" \;
fi

# Copy ios-deploy binary
echo "Copying ios-deploy..."
mkdir -p "$PACKAGE_DIR/ios-deploy"
if [ -f "$BUILD_DIR/ios-deploy/ios-deploy" ]; then
    cp "$BUILD_DIR/ios-deploy/ios-deploy" "$PACKAGE_DIR/ios-deploy/"
else
    echo "Error: ios-deploy binary not found"
    exit 1
fi

# Copy license and documentation files
echo "Copying license and documentation files..."
for file in LICENSE-GPL-v2 LICENSE-GPL-v3 NOTICE SOURCE.txt README.md; do
    if [ -f "$PROJECT_ROOT/$file" ]; then
        cp "$PROJECT_ROOT/$file" "$PACKAGE_DIR/"
    else
        echo "Warning: $file not found"
    fi
done

# Generate version.txt
echo "Generating version.txt..."
cat > "$PACKAGE_DIR/version.txt" <<EOF
PackageVersion: $VERSION
BuildDate: $(date +%Y-%m-%d)
BuildPlatform: macOS $(sw_vers -productVersion) ($(uname -m))

Components:
  libimobiledevice:
    Version: 1.3.0
    License: GPL v2+
    SourceURL: https://github.com/libimobiledevice/libimobiledevice

  ios-deploy:
    Version: 1.12.2
    License: GPLv3
    SourceURL: https://github.com/ios-control/ios-deploy

Architecture: $(lipo -info "$PACKAGE_DIR/ios-deploy/ios-deploy" | cut -d: -f3)

BuildInfo:
  Compiler: $(clang --version | head -n1)
  MinOSVersion: 12.0
EOF

# Calculate checksum
echo "Calculating checksum..."
cd "$DIST_DIR"
CHECKSUM=$(find "$PACKAGE_NAME" -type f -exec shasum -a 256 {} \; | sort | shasum -a 256 | cut -d' ' -f1)
echo "  SHA256: $CHECKSUM" >> "$PACKAGE_DIR/version.txt"

# Create tar.gz
echo "Creating archive..."
tar czf "$PACKAGE_NAME.tar.gz" "$PACKAGE_NAME"

# Calculate archive checksum
ARCHIVE_CHECKSUM=$(shasum -a 256 "$PACKAGE_NAME.tar.gz" | cut -d' ' -f1)

echo ""
echo "════════════════════════════════════════════════════════"
echo "✅ Package created successfully!"
echo "════════════════════════════════════════════════════════"
echo "Package: $DIST_DIR/$PACKAGE_NAME.tar.gz"
echo "SHA256: $ARCHIVE_CHECKSUM"
echo ""
echo "To verify:"
echo "  echo '$ARCHIVE_CHECKSUM  $PACKAGE_NAME.tar.gz' | shasum -a 256 -c"
