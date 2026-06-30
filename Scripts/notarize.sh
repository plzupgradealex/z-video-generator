#!/usr/bin/env bash
# Notarize the exported Developer-ID .app and staple the ticket.
# After this, the .app opens on other Macs without a Gatekeeper warning.
# Run after export-developer-id.sh; the staple then travels inside the DMG
# made by make-dmg.sh.
#
# Required env:
#   Z_APPLE_ID                your Apple ID email
#   Z_APP_SPECIFIC_PASSWORD   app-specific password (https://appleid.apple.com
#                             → Sign-In & Security → App-Specific Passwords)
#   Z_TEAM_ID                 your Apple Developer Team ID
set -euo pipefail
cd "$(dirname "$0")/.."

: "${Z_APPLE_ID:?set Z_APPLE_ID (your Apple ID email)}"
: "${Z_APP_SPECIFIC_PASSWORD:?set Z_APP_SPECIFIC_PASSWORD}"
: "${Z_TEAM_ID:?set Z_TEAM_ID}"

APP_PATH="build/DeveloperID/ZVideoGenerator.app"
[ -d "$APP_PATH" ] || { echo "✗ $APP_PATH not found — run ./Scripts/export-developer-id.sh first"; exit 1; }

ZIP="build/ZVideoGenerator-notarize.zip"
echo "▶ zipping for notarization…"
ditto -c -k --keepParent "$APP_PATH" "$ZIP"

echo "▶ submitting to Apple notary service (--wait, can take a few minutes)…"
xcrun notarytool submit "$ZIP" \
  --apple-id "$Z_APPLE_ID" \
  --password "$Z_APP_SPECIFIC_PASSWORD" \
  --team-id "$Z_TEAM_ID" \
  --wait

echo "▶ stapling the notarization ticket…"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

echo "▶ Gatekeeper check (expect 'accepted', source=Notarized):"
spctl -a -vvv -t install "$APP_PATH"
echo "✓ notarized + stapled: $APP_PATH   (next: ./Scripts/make-dmg.sh)"
