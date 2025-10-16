#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/libimobiledevice"
SOURCES_DIR="$PROJECT_ROOT/sources"

# Versions
LIBPLIST_VERSION="2.3.0"
LIBIMOBILEDEVICE_GLUE_VERSION="1.0.0"
LIBUSBMUXD_VERSION="2.0.2"
LIBIMOBILEDEVICE_VERSION="1.3.0"

INSTALL_PREFIX="$BUILD_DIR"
MACOS_MIN_VERSION="12.0"
ARCH="arm64"

echo "════════════════════════════════════════════════════════"
echo "Building libimobiledevice $LIBIMOBILEDEVICE_VERSION for arm64"
echo "════════════════════════════════════════════════════════"

# Check for required tools
if ! command -v brew &> /dev/null; then
    echo "Error: Homebrew is not installed. Please install from https://brew.sh"
    exit 1
fi

# Install build dependencies
echo ""
echo "Checking build dependencies..."
brew list autoconf &>/dev/null || brew install autoconf
brew list automake &>/dev/null || brew install automake
brew list libtool &>/dev/null || brew install libtool
brew list pkg-config &>/dev/null || brew install pkg-config
brew list openssl@3 &>/dev/null || brew install openssl@3

# Setup PKG_CONFIG_PATH for Homebrew
export PKG_CONFIG_PATH="/opt/homebrew/opt/openssl@3/lib/pkgconfig:$PKG_CONFIG_PATH"
export CFLAGS="-arch $ARCH -mmacosx-version-min=$MACOS_MIN_VERSION -I/opt/homebrew/opt/openssl@3/include"
export LDFLAGS="-arch $ARCH -mmacosx-version-min=$MACOS_MIN_VERSION -L/opt/homebrew/opt/openssl@3/lib"

mkdir -p "$SOURCES_DIR"
mkdir -p "$BUILD_DIR"

# Function to download and extract source
download_source() {
    local name=$1
    local version=$2
    local url=$3

    if [ ! -d "$SOURCES_DIR/$name" ]; then
        echo ""
        echo "Downloading $name $version..."
        cd "$SOURCES_DIR"
        curl -L "$url" -o "$name.tar.gz"
        tar xzf "$name.tar.gz"
        mv "$name-$version" "$name"
        rm "$name.tar.gz"
    else
        echo ""
        echo "$name source already exists, skipping download..."
    fi
}

# Function to build a component
build_component() {
    local name=$1
    local configure_opts=$2

    echo ""
    echo "Building $name..."
    cd "$SOURCES_DIR/$name"

    # Clean previous build
    make clean || true

    # Generate configure if needed
    if [ ! -f configure ]; then
        ./autogen.sh
    fi

    # Configure
    ./configure --prefix="$INSTALL_PREFIX" \
        --enable-static=no \
        --enable-shared=yes \
        $configure_opts

    # Build
    make -j$(sysctl -n hw.ncpu)

    # Install
    make install

    echo "$name built successfully!"
}

# 1. Build libplist
download_source "libplist" "$LIBPLIST_VERSION" \
    "https://github.com/libimobiledevice/libplist/releases/download/$LIBPLIST_VERSION/libplist-$LIBPLIST_VERSION.tar.bz2"
cd "$SOURCES_DIR/libplist"
if [ ! -f Makefile ]; then
    build_component "libplist" "--without-cython"
fi

# Update PKG_CONFIG_PATH to include our build
export PKG_CONFIG_PATH="$INSTALL_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"

# 2. Build libimobiledevice-glue
download_source "libimobiledevice-glue" "$LIBIMOBILEDEVICE_GLUE_VERSION" \
    "https://github.com/libimobiledevice/libimobiledevice-glue/releases/download/$LIBIMOBILEDEVICE_GLUE_VERSION/libimobiledevice-glue-$LIBIMOBILEDEVICE_GLUE_VERSION.tar.bz2"
build_component "libimobiledevice-glue" ""

# 3. Build libusbmuxd
download_source "libusbmuxd" "$LIBUSBMUXD_VERSION" \
    "https://github.com/libimobiledevice/libusbmuxd/releases/download/$LIBUSBMUXD_VERSION/libusbmuxd-$LIBUSBMUXD_VERSION.tar.bz2"
build_component "libusbmuxd" ""

# 4. Build libimobiledevice
download_source "libimobiledevice" "$LIBIMOBILEDEVICE_VERSION" \
    "https://github.com/libimobiledevice/libimobiledevice/releases/download/$LIBIMOBILEDEVICE_VERSION/libimobiledevice-$LIBIMOBILEDEVICE_VERSION.tar.bz2"
build_component "libimobiledevice" "--without-cython"

echo ""
echo "════════════════════════════════════════════════════════"
echo "✅ libimobiledevice built successfully!"
echo "════════════════════════════════════════════════════════"
echo "Install location: $INSTALL_PREFIX"
echo ""
echo "Binaries:"
ls -la "$INSTALL_PREFIX/bin/" 2>/dev/null || echo "No binaries found"
echo ""
echo "Libraries:"
ls -la "$INSTALL_PREFIX/lib/"*.dylib 2>/dev/null || echo "No libraries found"
