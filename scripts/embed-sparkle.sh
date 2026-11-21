#!/usr/bin/env bash
# Copies Sparkle.framework from the release build into the app and signs it inside out, ready for
# the app itself to be signed. Usage: scripts/embed-sparkle.sh <app> <identity> [codesign options…]
# ("-" as the identity signs ad hoc). Used by bundle.sh and build-dmg.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="$1"
IDENTITY="$2"
shift 2
BIN="$(swift build -c release --show-bin-path)"
FW="$APP/Contents/Frameworks/Sparkle.framework"

rm -rf "$FW"
mkdir -p "$APP/Contents/Frameworks"
ditto "$BIN/Sparkle.framework" "$FW"
# The XPC services are only for sandboxed apps, and this app isn't one.
rm -rf "$FW/XPCServices" "$FW/Versions/B/XPCServices"

for item in "$FW/Versions/B/Autoupdate" "$FW/Versions/B/Updater.app" "$FW"; do
  codesign --force --sign "$IDENTITY" "$@" "$item"
done
