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
ENTITLEMENTS="${ROOT_DIR}/DevReclaim/DevReclaim.entitlements"

# Developer ID signing & notarization (set via env vars or leave empty for ad-hoc)
SIGN_IDENTITY="${SIGN_IDENTITY:-}"          # e.g. "Developer ID Application: ..."
NOTARY_PROFILE="${NOTARY_PROFILE:-}"        # keychain profile name set via notarytool store-credentials

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

echo "4) Code Signing..."
chmod -R a+r "${APP_BUNDLE}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

if [[ -n "${SIGN_IDENTITY}" ]]; then
  echo "   Using Developer ID: ${SIGN_IDENTITY}"
  codesign --force --deep --options runtime --timestamp \
    --entitlements "${ENTITLEMENTS}" \
    --sign "${SIGN_IDENTITY}" \
    "${APP_BUNDLE}"
else
  echo "   No SIGN_IDENTITY set — using ad-hoc signature."
  codesign --force --deep --sign - "${APP_BUNDLE}"
fi

echo "5) Preparing DMG staging..."
ln -s /Applications "${STAGING_DIR}/Applications"

# Add open instructions (only needed for ad-hoc builds)
if [[ -z "${SIGN_IDENTITY}" ]]; then
cat > "${STAGING_DIR}/How to Open.txt" <<'INSTRUCTIONS'
If macOS says the app "cannot be opened" or is "damaged":

Option 1 (easiest):
  Right-click DevReclaim.app → Open → Open

Option 2 (Terminal):
  xattr -cr /Applications/DevReclaim.app

This is normal for apps not distributed via the Mac App Store.
INSTRUCTIONS
fi

echo "6) Creating DMG..."
hdiutil create -quiet -volname "${APP_NAME}" -srcfolder "${STAGING_DIR}" -ov -format UDRW -fs HFS+ "${TMP_DMG}"

ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "${TMP_DMG}")"
DEVICE="$(echo "${ATTACH_OUTPUT}" | awk '/Apple_HFS|Apple_APFS/ {print $1; exit}')"
MOUNT_POINT="$(echo "${ATTACH_OUTPUT}" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"

if [[ -n "${MOUNT_POINT}" && -d "${MOUNT_POINT}" ]]; then
  echo "Setting DMG layout..."
  # Wait for Finder to register the newly mounted volume
  sleep 2
  osascript 2>/dev/null <<EOF || echo "  (Finder layout skipped — will still work)"
tell application "Finder"
  tell disk "${APP_NAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {400, 100, 940, 460}
    set the_options to icon view options of container window
    set arrangement of the_options to not arranged
    set icon size of the_options to 120
    set text size of the_options to 13
    set position of item "${APP_NAME}.app" of container window to {150, 170}
    set position of item "Applications" of container window to {390, 170}
    set position of item "How to Open.txt" of container window to {270, 330}
    close
    delay 2
  end tell
end tell
EOF
  sync
fi

sleep 1
if [[ -n "${DEVICE}" ]]; then
  hdiutil detach "${DEVICE}" -quiet || hdiutil detach "${DEVICE}" -force -quiet
fi

hdiutil convert -quiet "${TMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG_PATH}"
rm -f "${TMP_DMG}"
rm -rf "${ICONSET_TMP}"

echo "7) Verifying DMG..."
hdiutil verify "${DMG_PATH}" > /dev/null

if [[ -n "${SIGN_IDENTITY}" && -n "${NOTARY_PROFILE}" ]]; then
  echo "8) Notarizing DMG..."
  xcrun notarytool submit "${DMG_PATH}" \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait

  echo "9) Stapling notarization ticket..."
  xcrun stapler staple "${DMG_PATH}"

  echo ""
  echo "Gatekeeper check:"
  spctl -a -t open --context context:primary-signature -vv "${DMG_PATH}" || true
elif [[ -n "${SIGN_IDENTITY}" ]]; then
  echo ""
  echo "NOTE: NOTARY_PROFILE not set — skipping notarization."
  echo "Set NOTARY_PROFILE to your keychain profile name and re-run to notarize."
fi

echo ""
echo "Done: ${DMG_PATH}"
echo ""
if [[ -n "${SIGN_IDENTITY}" && -n "${NOTARY_PROFILE}" ]]; then
  echo "App is Developer ID signed and notarized. Gatekeeper will accept it."
else
  echo "NOTE: This app is ad-hoc signed (no Developer ID)."
  echo "Users must right-click → Open on first launch,"
  echo "OR run: xattr -cr /Applications/${APP_NAME}.app"
fi
