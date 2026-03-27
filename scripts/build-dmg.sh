#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-1.0.0}"
APP_NAME="StudioDisplayRenamer"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
DMG_STAGING=".build/dmg-staging"

echo "==> Building ${APP_NAME} v${VERSION}..."
swift build -c release

echo "==> Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
cp Info.plist "${APP_BUNDLE}/Contents/"

# Copy app icon if it exists
if [ -f "AppIcon.icns" ]; then
    mkdir -p "${APP_BUNDLE}/Contents/Resources"
    cp AppIcon.icns "${APP_BUNDLE}/Contents/Resources/"
fi

echo "==> Creating DMG..."
rm -rf "${DMG_STAGING}"
mkdir -p "${DMG_STAGING}"
cp -R "${APP_BUNDLE}" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

rm -f "${DMG_NAME}"
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_STAGING}" \
    -ov \
    -format UDZO \
    "${DMG_NAME}"

rm -rf "${DMG_STAGING}"

echo ""
echo "==> Done! Created ${DMG_NAME}"
echo "    Size: $(du -h "${DMG_NAME}" | cut -f1)"
echo ""
echo "To distribute:"
echo "  1. Upload ${DMG_NAME} to a GitHub Release"
echo "  2. Users download, open DMG, drag to Applications"
echo ""
echo "Note: Without code signing, users must right-click > Open on first launch."
echo "To sign and notarize (requires Apple Developer account):"
echo "  codesign --deep --force --sign \"Developer ID Application: Your Name\" ${APP_BUNDLE}"
echo "  xcrun notarytool submit ${DMG_NAME} --apple-id you@email.com --team-id TEAMID --password app-specific-password"
