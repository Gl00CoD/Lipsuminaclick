#!/usr/bin/env bash
# Builds "Lipsum in a Click.app" into ./build (requires macOS with Xcode or the Command Line Tools).
# The version comes from the VERSION file. UNIVERSAL=1 builds for Apple Silicon + Intel (needs Xcode).
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Lipsum in a Click"
EXECUTABLE="LipsumInAClick"
APP="build/${APP_NAME}.app"
VERSION="$(tr -d '[:space:]' < VERSION)"

ARCH_FLAGS=()
if [ "${UNIVERSAL:-0}" = "1" ]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

swift build -c release --product "$EXECUTABLE" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c release --show-bin-path ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"})"

rm -rf build
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/$EXECUTABLE" "$APP/Contents/MacOS/$EXECUTABLE"
cp Resources/Info.plist "$APP/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "$APP/Contents/Info.plist"

# Ad-hoc signature so macOS will run it locally.
codesign --force --sign - "$APP"

(cd build && ditto -c -k --keepParent "${APP_NAME}.app" LipsumInAClick.zip)

echo "Built: $APP ($VERSION)"
echo "Zipped: build/LipsumInAClick.zip"
