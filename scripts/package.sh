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
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

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

echo "4) Preparing DMG staging..."
ln -s /Applications "${STAGING_DIR}/Applications"

echo "5) Creating DMG..."
hdiutil create -quiet -volname "${APP_NAME}" -srcfolder "${STAGING_DIR}" -ov -format UDRW -fs HFS+ "${TMP_DMG}"

ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "${TMP_DMG}")"
DEVICE="$(echo "${ATTACH_OUTPUT}" | awk '/Apple_HFS|Apple_APFS/ {print $1; exit}')"
MOUNT_POINT="$(echo "${ATTACH_OUTPUT}" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"

if [[ -n "${MOUNT_POINT}" && -d "${MOUNT_POINT}" ]]; then
  osascript <<EOF || true
tell application "Finder"
  tell disk "${APP_NAME}"
    open
    tell container window
      set current view to icon view
      set toolbar visible to false
      set statusbar visible to false
      set bounds to {200, 120, 820, 520}
    end tell
    tell icon view options of container window
      set arrangement to not arranged
      set icon size to 128
      set text size to 13
    end tell
    set position of item "${APP_NAME}.app" of container window to {180, 210}
    set position of item "Applications" of container window to {460, 210}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF
fi

sync
if [[ -n "${DEVICE}" ]]; then
  hdiutil detach "${DEVICE}" -quiet || hdiutil detach "${DEVICE}" -force -quiet
fi

hdiutil convert -quiet "${TMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG_PATH}"
rm -f "${TMP_DMG}"
rm -rf "${ICONSET_TMP}"

echo "6) Verifying DMG..."
hdiutil verify "${DMG_PATH}" > /dev/null

echo "Done: ${DMG_PATH}"
echo "Build log: ${BUILD_LOG}"
