#!/usr/bin/env bash
# Build DellBridge.app from the SwiftPM executable.
#
# The app is ad-hoc signed so Apple Silicon does not report it as damaged.
# It is NOT notarized: Gatekeeper will still ask for confirmation on first
# launch. See docs/plans/m4-distribution.md.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${CONFIG:-release}"
APP="$ROOT/dist/DellBridge.app"

cd "$ROOT"

swift build -c "$CONFIG" --product DellBridge
BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_PATH/DellBridge" "$APP/Contents/MacOS/DellBridge"
cp "$ROOT/packaging/Info.plist" "$APP/Contents/Info.plist"

# Ad-hoc signature. Replace with a Developer ID identity for distribution:
#   CODESIGN_IDENTITY="Developer ID Application: ..." ./scripts/build-app.sh
IDENTITY="${CODESIGN_IDENTITY:--}"
codesign --force --deep --sign "$IDENTITY" "$APP"

codesign --verify --deep --strict "$APP"
echo "built $APP"
