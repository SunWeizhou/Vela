#!/bin/bash
set -e

PROJECT_DIR="/Users/sunweizhou/Developer/Vela"
DEVICE_NAME="Weizhou的iPhone"
DEVICE_ID="B1B2A1DB-2B5C-5C02-A222-B051240A22EA"

echo "🔨 Building Vela..."
cd "$PROJECT_DIR"

xcodebuild \
  -project Vela.xcodeproj \
  -scheme Vela \
  -configuration Debug \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates \
  build

echo ""
echo "✅ Build complete! Deploying to iPhone..."
echo ""

# Install to device
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Vela-*/Build/Products/Debug-iphoneos -maxdepth 1 -name "Vela.app" 2>/dev/null | head -1)

if [ -n "$APP_PATH" ]; then
    echo "Installing $APP_PATH to device..."
    xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
    echo "✅ Vela installed on iPhone!"
else
    echo "⚠️  Could not find built .app. Xcode should have it open — press Cmd+R to run."
fi
