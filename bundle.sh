#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

echo "Building..."
swift build -c release

APP_DIR="StudioDisplayRenamer.app/Contents/MacOS"
mkdir -p "$APP_DIR"
cp .build/release/StudioDisplayRenamer "$APP_DIR/"
cp Info.plist StudioDisplayRenamer.app/Contents/

echo "Built StudioDisplayRenamer.app"
echo "Run with: open StudioDisplayRenamer.app"
