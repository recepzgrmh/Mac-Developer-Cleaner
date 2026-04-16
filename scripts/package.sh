#!/bin/bash

# DevReclaim DMG Packaging Script
# Requires: create-dmg (brew install create-dmg) or hdiutil

APP_NAME="DevReclaim"
VERSION="1.1.0"
DMG_NAME="${APP_NAME}_v${VERSION}.dmg"
STAGING_DIR="./dist"

echo "🚀 Starting packaging process for ${APP_NAME}..."

# 1. Clean staging area
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

# 2. Check if App exists (Placeholder for build step)
# In a real environment, you would run: xcodebuild ...
if [ ! -d "${APP_NAME}.app" ]; then
    echo "⚠️ Warning: ${APP_NAME}.app not found in current directory."
    echo "Make sure to run a Release build in Xcode first."
    # exit 1
fi

# 3. Optimization Check (Informational)
echo "📦 Optimization: Checking bundle size..."
# du -sh "${APP_NAME}.app"

# 4. Create DMG
# We use hdiutil as it's native to macOS
echo "💾 Creating disk image..."
hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_NAME}"

echo "✅ DMG created: ${DMG_NAME}"
echo "🔔 Next Step: Run Notarization (xcrun altool --notarize-app ...)"
