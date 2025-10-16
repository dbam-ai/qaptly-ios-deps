#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/libimobiledevice"
SOURCES_DIR="$PROJECT_ROOT/sources"

# Use libimobiledevice 1.4.0 release
LIBIMOBILEDEVICE_VERSION="1.4.0"
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

# Function to clone or update git repo with specific tag
clone_or_checkout() {
    local name=$1
    local url=$2
    local tag=$3

    if [ ! -d "$SOURCES_DIR/$name" ]; then
        echo ""
        echo "Cloning $name..."
        cd "$SOURCES_DIR"
        git clone "$url" "$name"
        cd "$name"
        if [ -n "$tag" ]; then
            git checkout "$tag"
        fi
    else
        echo ""
        echo "$name already exists, checking out $tag..."
        cd "$SOURCES_DIR/$name"
        git fetch
        if [ -n "$tag" ]; then
            git checkout "$tag"
        else
            git pull
        fi
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
    make distclean || true

    # Generate configure
    ./autogen.sh

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

# 1. Build libplist (use latest)
clone_or_checkout "libplist" "https://github.com/libimobiledevice/libplist.git" ""
build_component "libplist" "--without-cython"

# Update PKG_CONFIG_PATH to include our build
export PKG_CONFIG_PATH="$INSTALL_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"

# 2. Build libimobiledevice-glue (use latest)
clone_or_checkout "libimobiledevice-glue" "https://github.com/libimobiledevice/libimobiledevice-glue.git" ""
build_component "libimobiledevice-glue" ""

# 3. Build libusbmuxd (use latest)
clone_or_checkout "libusbmuxd" "https://github.com/libimobiledevice/libusbmuxd.git" ""
build_component "libusbmuxd" ""

# 4. Build libtatsu (new dependency for libimobiledevice 1.4.0)
clone_or_checkout "libtatsu" "https://github.com/libimobiledevice/libtatsu.git" ""
build_component "libtatsu" ""

# 5. Build libimobiledevice 1.4.0
clone_or_checkout "libimobiledevice" "https://github.com/libimobiledevice/libimobiledevice.git" "$LIBIMOBILEDEVICE_VERSION"
build_component "libimobiledevice" "--without-cython"

echo ""
echo "════════════════════════════════════════════════════════"
echo "✅ libimobiledevice $LIBIMOBILEDEVICE_VERSION built successfully!"
echo "════════════════════════════════════════════════════════"
echo "Install location: $INSTALL_PREFIX"
echo ""
echo "Binaries:"
ls -la "$INSTALL_PREFIX/bin/" 2>/dev/null || echo "No binaries found"
echo ""
echo "Libraries:"
ls -la "$INSTALL_PREFIX/lib/"*.dylib 2>/dev/null || echo "No libraries found"
