#!/usr/bin/env bash
# Archive a Release build of Z Video Generator and export a Developer-ID-signed
# .app for direct (non-App-Store) download. Run AFTER enrollment in the Developer
# ID program. Produces build/DeveloperID/ZVideoGenerator.app.
#
# Required env:
#   Z_TEAM_ID       your Apple Developer Team ID (e.g. ABCD123XYZ)
set -euo pipefail
cd "$(dirname "$0")/.."

: "${Z_TEAM_ID:?set Z_TEAM_ID to your Apple Developer Team ID}"

APP="ZVideoGenerator"
SCHEME="ZVideoGenerator"
ARCHIVE="build/$APP-DevID.xcarchive"
EXPORT_DIR="build/DeveloperID"

echo "▶ regenerating Xcode project (xcodegen)…"
xcodegen generate 2>/dev/null || echo "  (using existing $APP.xcodeproj)"

echo "▶ archiving $SCHEME (Release)…"
rm -rf "$ARCHIVE"
xcodebuild archive \
  -project "$APP.xcodeproj" -scheme "$SCHEME" -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$Z_TEAM_ID" \
  CODE_SIGN_STYLE=Automatic | tail -20

echo "▶ exporting Developer-ID .app…"
rm -rf "$EXPORT_DIR"
TMP_PLIST="$(mktemp -t zdevid).plist"
trap 'rm -f "$TMP_PLIST"' EXIT
cat > "$TMP_PLIST" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$Z_TEAM_ID</string>
</dict>
</plist>
EOF
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$TMP_PLIST" -exportPath "$EXPORT_DIR"

echo "✓ exported → $EXPORT_DIR/$APP.app   (next: ./Scripts/notarize.sh)"
