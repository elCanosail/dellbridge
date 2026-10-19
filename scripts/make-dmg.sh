#!/usr/bin/env bash
# Package dist/DellBridge.app into a drag-to-Applications DMG.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/DellBridge.app"
VERSION="${VERSION:-0.2.0}"
DMG="$ROOT/dist/DellBridge-$VERSION.dmg"

if [[ ! -d "$APP" ]]; then
  echo "error: $APP not found; run ./scripts/build-app.sh first" >&2
  exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create \
  -volname "DellBridge" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

echo "built $DMG"
SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
printf '%s  %s\n' "$SHA" "$(basename "$DMG")" > "$DMG.sha256"
echo "sha256: $SHA"
echo "written $DMG.sha256"

if [[ "${NOTARIZE:-0}" == "1" ]]; then
  echo "notarizing with keychain profile '${NOTARY_PROFILE:-dellbridge}'"
  xcrun notarytool submit "$DMG" \
    --keychain-profile "${NOTARY_PROFILE:-dellbridge}" \
    --wait
  xcrun stapler staple "$DMG"
  echo "notarized and stapled"
fi
