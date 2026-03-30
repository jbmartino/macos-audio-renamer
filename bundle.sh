#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

echo "Building..."
swift build -c release

APP_BUNDLE="macOS Audio Renamer.app"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
cp .build/release/MacOSAudioRenamer "${APP_BUNDLE}/Contents/MacOS/"
cp Info.plist "${APP_BUNDLE}/Contents/"

if [ -f "AppIcon.icns" ]; then
    mkdir -p "${APP_BUNDLE}/Contents/Resources"
    cp AppIcon.icns "${APP_BUNDLE}/Contents/Resources/"
fi

echo "Built ${APP_BUNDLE}"
echo "Run with: open \"${APP_BUNDLE}\""
