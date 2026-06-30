#!/usr/bin/env bash
# Archive Z Video Generator and export a Mac App Store-ready .pkg.
#
# API-key-driven: -allowProvisioningUpdates + the App Store Connect API key let
# xcodebuild refresh provisioning automatically — no profiles pre-installed, no
# Xcode GUI needed. This is the same flow that shipped Muxy.
#
# Required env (account-level — identical to Muxy's values):
#   Z_TEAM_ID       your Apple Developer Team ID (e.g. ABCD123XYZ)
#   Z_API_KEY_ID    App Store Connect API Key ID
#   Z_API_ISSUER    App Store Connect Issuer ID (UUID)
# The .p8 must live at ~/.appstoreconnect/private_keys/AuthKey_<Z_API_KEY_ID>.p8
set -euo pipefail
cd "$(dirname "$0")/.."

: "${Z_TEAM_ID:?set Z_TEAM_ID (e.g. ABCD123XYZ)}"
: "${Z_API_KEY_ID:?set Z_API_KEY_ID}"
: "${Z_API_ISSUER:?set Z_API_ISSUER}"
KEYPATH="$HOME/.appstoreconnect/private_keys/AuthKey_${Z_API_KEY_ID}.p8"
[ -f "$KEYPATH" ] || { echo "✗ $KEYPATH not found"; exit 1; }

APP="ZVideoGenerator"
ARCHIVE="build/$APP.xcarchive"
EXPORT_DIR="build/MAS"

echo "▶ regenerating Xcode project (xcodegen)…"
xcodegen generate 2>/dev/null || echo "  (using existing $APP.xcodeproj)"

echo "▶ archiving $APP (team $Z_TEAM_ID, API-key provisioning)…"
rm -rf "$ARCHIVE"
xcodebuild archive \
  -project "$APP.xcodeproj" -scheme "$APP" -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$Z_TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEYPATH" \
  -authenticationKeyID "$Z_API_KEY_ID" \
  -authenticationKeyIssuerID "$Z_API_ISSUER" | tail -30

echo "▶ exporting MAS .pkg…"
rm -rf "$EXPORT_DIR"
TMP_PLIST="$(mktemp -t zmas).plist"
trap 'rm -f "$TMP_PLIST"' EXIT
cat > "$TMP_PLIST" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store</string>
  <key>teamID</key><string>$Z_TEAM_ID</string>
</dict>
</plist>
EOF
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$TMP_PLIST" -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEYPATH" \
  -authenticationKeyID "$Z_API_KEY_ID" \
  -authenticationKeyIssuerID "$Z_API_ISSUER"

echo "✓ MAS pkg → $EXPORT_DIR/$APP.pkg"
echo "  Next: ./Scripts/upload-mas.sh   (then Submit for Review in App Store Connect)"
