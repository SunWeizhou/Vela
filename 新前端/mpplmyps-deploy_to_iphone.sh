#!/bin/bash
set -e

PROJECT_DIR="/Users/sunweizhou/Desktop/AI Project/Vela"
DEVICE_NAME="Weizhou的iPhone"
DEVICE_ID="00008140-00164DE022C3801C"

echo "🔨 Building Vela..."
cd "$PROJECT_DIR"

xcodebuild \
  -project Vela.xcodeproj \
  -scheme Vela \
  -configuration Debug \
  -destination "platform=iOS,name=$DEVICE_NAME" \
  -allowProvisioningUpdates \
  build

echo ""
echo "✅ Build complete! Deploying to iPhone..."
echo ""

# Install to device
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Vela-*/Build/Products/Debug-iphoneos -name "Vela.app" 2>/dev/null | head -1)

if [ -n "$APP_PATH" ]; then
    echo "Installing $APP_PATH to device..."
    xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
    echo "✅ Vela installed on iPhone!"
else
    echo "⚠️  Could not find built .app. Xcode should have it open — press Cmd+R to run."
fi
