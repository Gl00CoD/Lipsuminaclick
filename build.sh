#!/usr/bin/env bash
# Builds "Lipsum in a Click.app" into ./build (requires macOS with Xcode or the Command Line Tools).
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Lipsum in a Click"
EXECUTABLE="LipsumInAClick"
APP="build/${APP_NAME}.app"

swift build -c release --product "$EXECUTABLE"
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf build
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/$EXECUTABLE" "$APP/Contents/MacOS/$EXECUTABLE"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature so macOS will run it locally.
codesign --force --sign - "$APP"

(cd build && ditto -c -k --keepParent "${APP_NAME}.app" LipsumInAClick.zip)

echo "Built: $APP"
echo "Zipped: build/LipsumInAClick.zip"
