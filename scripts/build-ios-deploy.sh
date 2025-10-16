#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/ios-deploy"
SOURCES_DIR="$PROJECT_ROOT/sources"

VERSION="1.12.2"
MACOS_MIN_VERSION="12.0"
ARCH="arm64"

echo "════════════════════════════════════════════════════════"
echo "Building ios-deploy $VERSION for arm64"
echo "════════════════════════════════════════════════════════"

mkdir -p "$SOURCES_DIR"
mkdir -p "$BUILD_DIR"

# Download source if not exists
if [ ! -d "$SOURCES_DIR/ios-deploy" ]; then
    echo ""
    echo "Downloading ios-deploy source..."
    cd "$SOURCES_DIR"
    curl -L "https://github.com/ios-control/ios-deploy/archive/refs/tags/$VERSION.tar.gz" -o ios-deploy.tar.gz
    tar xzf ios-deploy.tar.gz
    mv "ios-deploy-$VERSION" ios-deploy
    rm ios-deploy.tar.gz
else
    echo ""
    echo "ios-deploy source already exists, skipping download..."
fi

# Build
echo ""
echo "Building ios-deploy..."
cd "$SOURCES_DIR/ios-deploy"

# Clean previous build
rm -rf build

# Build using xcodebuild with arm64 architecture
xcodebuild \
    -configuration Release \
    ARCHS="$ARCH" \
    ONLY_ACTIVE_ARCH=NO \
    MACOSX_DEPLOYMENT_TARGET="$MACOS_MIN_VERSION"

# Copy to build dir
echo ""
echo "Installing ios-deploy..."
cp build/Release/ios-deploy "$BUILD_DIR/"

# Verify architecture
echo ""
echo "Verifying architecture..."
lipo -info "$BUILD_DIR/ios-deploy"

echo ""
echo "════════════════════════════════════════════════════════"
echo "✅ ios-deploy built successfully!"
echo "════════════════════════════════════════════════════════"
echo "Install location: $BUILD_DIR"
echo ""
ls -lah "$BUILD_DIR/ios-deploy"
