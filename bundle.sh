#!/bin/bash
# Local build for trying changes. No update feed, so Sparkle stays off and never swaps this
# build for the latest release. Releases use scripts/build-dmg.sh.
set -euo pipefail

cd "$(dirname "$0")"

echo "Building..."
swift build -c release

APP_BUNDLE="macOS Audio Renamer.app"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
cp .build/release/MacOSAudioRenamer "${APP_BUNDLE}/Contents/MacOS/"
cp Info.plist "${APP_BUNDLE}/Contents/"
/usr/libexec/PlistBuddy -c "Delete :SUFeedURL" "${APP_BUNDLE}/Contents/Info.plist"

if [ -f "AppIcon.icns" ]; then
    mkdir -p "${APP_BUNDLE}/Contents/Resources"
    cp AppIcon.icns "${APP_BUNDLE}/Contents/Resources/"
fi

scripts/embed-sparkle.sh "${APP_BUNDLE}" -
codesign --force --sign - --entitlements MacOSAudioRenamer.entitlements "${APP_BUNDLE}"

echo "Built ${APP_BUNDLE}"
echo "Run with: open \"${APP_BUNDLE}\""
