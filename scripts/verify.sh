#!/bin/bash
set -e

PACKAGE_PATH="$1"

if [ -z "$PACKAGE_PATH" ]; then
    echo "Usage: $0 <path-to-package.tar.gz>"
    exit 1
fi

if [ ! -f "$PACKAGE_PATH" ]; then
    echo "Error: Package file not found: $PACKAGE_PATH"
    exit 1
fi

echo "Verifying package: $PACKAGE_PATH"
echo ""

# Extract to temp directory
TEMP_DIR=$(mktemp -d)
echo "Extracting package to temporary directory..."
tar xzf "$PACKAGE_PATH" -C "$TEMP_DIR"
EXTRACTED_DIR=$(ls "$TEMP_DIR")

cd "$TEMP_DIR/$EXTRACTED_DIR"

# Check required files
REQUIRED_FILES=(
    "libimobiledevice/bin/idevice_id"
    "libimobiledevice/bin/ideviceinfo"
    "libimobiledevice/bin/iproxy"
    "ios-deploy/ios-deploy"
    "LICENSE-GPL-v2"
    "LICENSE-GPL-v3"
    "NOTICE"
    "SOURCE.txt"
    "version.txt"
    "README.md"
)

echo "Checking required files..."
MISSING_FILES=0
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ] && [ ! -e "$file" ]; then
        echo "❌ Missing: $file"
        MISSING_FILES=$((MISSING_FILES + 1))
    else
        echo "✅ Found: $file"
    fi
done

if [ $MISSING_FILES -gt 0 ]; then
    echo ""
    echo "Error: $MISSING_FILES required file(s) missing"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Check executables
echo ""
echo "Checking executables..."
chmod +x libimobiledevice/bin/* 2>/dev/null || true
chmod +x ios-deploy/ios-deploy

# Test idevice_id
echo ""
echo "Testing idevice_id..."
if ./libimobiledevice/bin/idevice_id --version 2>&1 | grep -q "idevice_id"; then
    echo "✅ idevice_id works"
else
    echo "⚠️  idevice_id version check did not return expected output"
fi

# Test ios-deploy
echo ""
echo "Testing ios-deploy..."
if ./ios-deploy/ios-deploy --version 2>&1 | grep -q "ios-deploy"; then
    echo "✅ ios-deploy works"
else
    echo "⚠️  ios-deploy version check did not return expected output"
fi

# Check dynamic libraries
echo ""
echo "Checking dynamic library dependencies..."
echo ""
echo "idevice_id dependencies:"
otool -L libimobiledevice/bin/idevice_id | grep -v ":" | sed 's/^/  /'

echo ""
echo "ios-deploy dependencies:"
otool -L ios-deploy/ios-deploy | grep -v ":" | sed 's/^/  /'

# Check architecture
echo ""
echo "Checking architecture..."
echo "idevice_id: $(lipo -info libimobiledevice/bin/idevice_id)"
echo "ios-deploy: $(lipo -info ios-deploy/ios-deploy)"

# Display version info
echo ""
echo "Package version information:"
echo "════════════════════════════════════════════════════════"
cat version.txt
echo "════════════════════════════════════════════════════════"

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "✅ Package verification completed successfully!"
