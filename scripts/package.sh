#!/usr/bin/env bash
set -euo pipefail

APP_NAME="DevReclaim"
VERSION="${1:-${VERSION:-1.1.0}}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="${ROOT_DIR}/.build-xcode"
RELEASE_DIR="${DERIVED_DATA_DIR}/Build/Products/Release"
DIST_DIR="${ROOT_DIR}/dist"
STAGING_DIR="${DIST_DIR}/staging"
APP_BUNDLE="${STAGING_DIR}/${APP_NAME}.app"
ICONSET_SRC="${ROOT_DIR}/DevReclaim/Resources/Assets.xcassets/AppIcon.appiconset"
ICONSET_TMP="${DIST_DIR}/AppIcon.iconset"
TMP_DMG="${DIST_DIR}/${APP_NAME}_temp.dmg"
DMG_PATH="${DIST_DIR}/${APP_NAME}_v${VERSION}.dmg"
BUILD_LOG="${DIST_DIR}/build.log"

echo "Starting release packaging for ${APP_NAME} v${VERSION}"

rm -rf "${STAGING_DIR}" "${ICONSET_TMP}" "${TMP_DMG}" "${DMG_PATH}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources" "${ICONSET_TMP}" "${DIST_DIR}"

echo "1) Building release binary..."
xcodebuild \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "${DERIVED_DATA_DIR}" \
  build > "${BUILD_LOG}" 2>&1

BIN_PATH="${RELEASE_DIR}/${APP_NAME}"
RESOURCE_BUNDLE_PATH="${RELEASE_DIR}/${APP_NAME}_${APP_NAME}.bundle"

if [[ ! -f "${BIN_PATH}" ]]; then
  echo "Build output missing: ${BIN_PATH}"
  echo "See build log: ${BUILD_LOG}"
  exit 1
fi

if [[ ! -d "${RESOURCE_BUNDLE_PATH}" ]]; then
  echo "Resource bundle missing: ${RESOURCE_BUNDLE_PATH}"
  echo "See build log: ${BUILD_LOG}"
  exit 1
fi

echo "2) Assembling .app bundle..."
cp "${BIN_PATH}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp -R "${RESOURCE_BUNDLE_PATH}" "${APP_BUNDLE}/Contents/Resources/"
cp "${ROOT_DIR}/DevReclaim/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Update Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon.icns" "${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIconName AppIcon" "${APP_BUNDLE}/Contents/Info.plist"

echo "3) Generating app icon (.icns)..."
cp "${ICONSET_SRC}/icon_16.png" "${ICONSET_TMP}/icon_16x16.png"
cp "${ICONSET_SRC}/icon_16@2x.png" "${ICONSET_TMP}/icon_16x16@2x.png"
cp "${ICONSET_SRC}/icon_32.png" "${ICONSET_TMP}/icon_32x32.png"
cp "${ICONSET_SRC}/icon_32@2x.png" "${ICONSET_TMP}/icon_32x32@2x.png"
cp "${ICONSET_SRC}/icon_128.png" "${ICONSET_TMP}/icon_128x128.png"
cp "${ICONSET_SRC}/icon_128@2x.png" "${ICONSET_TMP}/icon_128x128@2x.png"
cp "${ICONSET_SRC}/icon_256.png" "${ICONSET_TMP}/icon_256x256.png"
cp "${ICONSET_SRC}/icon_256@2x.png" "${ICONSET_TMP}/icon_256x256@2x.png"
cp "${ICONSET_SRC}/icon_512.png" "${ICONSET_TMP}/icon_512x512.png"
cp "${ICONSET_SRC}/icon_512@2x.png" "${ICONSET_TMP}/icon_512x512@2x.png"
iconutil -c icns "${ICONSET_TMP}" -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

echo "4) Code Signing (Ad-hoc)..."
# Ensure all files are readable by everyone
chmod -R a+r "${APP_BUNDLE}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
# Sign the bundle and all internal components
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "5) Preparing DMG staging..."
ln -s /Applications "${STAGING_DIR}/Applications"

echo "6) Creating DMG..."
# Create a temporary read-write DMG
hdiutil create -quiet -volname "${APP_NAME}" -srcfolder "${STAGING_DIR}" -ov -format UDRW -fs HFS+ "${TMP_DMG}"

# Mount it to set the layout
ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "${TMP_DMG}")"
DEVICE="$(echo "${ATTACH_OUTPUT}" | awk '/Apple_HFS|Apple_APFS/ {print $1; exit}')"
MOUNT_POINT="$(echo "${ATTACH_OUTPUT}" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"

if [[ -n "${MOUNT_POINT}" && -d "${MOUNT_POINT}" ]]; then
  echo "Setting DMG layout..."
  osascript <<EOF
tell application "Finder"
  tell disk "${APP_NAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the_bounds to {400, 100, 920, 440}
    set bounds of container window to the_bounds
    
    set the_options to icon view options of container window
    set arrangement of the_options to not arranged
    set icon size of the_options to 120
    set text size of the_options to 14
    
    set position of item "${APP_NAME}.app" of container window to {160, 150}
    set position of item "Applications" of container window to {360, 150}
    
    # Wait for Finder to write its changes
    delay 3
    
    # Enable autostart
    set the_mount to "${MOUNT_POINT}"
    # close container window
  end tell
end tell
EOF
  # Hide the DS_Store if possible
  sync
  # Use bless to ensure the window opens automatically
  bless --folder "${MOUNT_POINT}" --openfolder "${MOUNT_POINT}"
fi

sync
if [[ -n "${DEVICE}" ]]; then
  hdiutil detach "${DEVICE}" -quiet || hdiutil detach "${DEVICE}" -force -quiet
fi

# Convert to compressed DMG
hdiutil convert -quiet "${TMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG_PATH}"
rm -f "${TMP_DMG}"
rm -rf "${ICONSET_TMP}"

echo "7) Verifying DMG..."
hdiutil verify "${DMG_PATH}" > /dev/null

echo "Done: ${DMG_PATH}"
echo "--------------------------------------------------"
echo "IMPORTANT: If users still see a 'damaged' error,"
echo "it is because the app is ad-hoc signed."
echo "They must run: xattr -cr /Applications/${APP_NAME}.app"
echo "To avoid this, sign with a Developer ID and notarize."
echo "--------------------------------------------------"
