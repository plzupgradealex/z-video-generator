#!/usr/bin/env bash
# Build a drag-to-Applications DMG from the notarized Developer-ID .app.
# Run after notarize.sh (the staple travels with the .app inside the DMG).
set -euo pipefail
cd "$(dirname "$0")/.."

APP_PATH="build/DeveloperID/ZVideoGenerator.app"
[ -d "$APP_PATH" ] || { echo "✗ $APP_PATH not found — run ./Scripts/notarize.sh first"; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
OUT="$HOME/Desktop/ZVideoGenerator-$VERSION.dmg"

echo "▶ building DMG v$VERSION…"
STAGE="$(mktemp -d /tmp/zvgdmg.XXXX)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$OUT"
hdiutil create -volname "Z Video Generator" -srcfolder "$STAGE" -ov \
  -fs HFS+ -format UDZO -imagekey zlib-level=9 "$OUT"

echo "✓ DMG → $OUT"
