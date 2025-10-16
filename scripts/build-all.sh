#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "════════════════════════════════════════════════════════"
echo "Building all iOS automation dependencies..."
echo "════════════════════════════════════════════════════════"

# Build libimobiledevice
echo ""
echo "Step 1/2: Building libimobiledevice..."
bash "$SCRIPT_DIR/build-libimobiledevice.sh"

# Build ios-deploy
echo ""
echo "Step 2/2: Building ios-deploy..."
bash "$SCRIPT_DIR/build-ios-deploy.sh"

echo ""
echo "════════════════════════════════════════════════════════"
echo "✅ All tools built successfully!"
echo "════════════════════════════════════════════════════════"
