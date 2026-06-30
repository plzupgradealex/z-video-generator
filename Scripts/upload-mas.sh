#!/usr/bin/env bash
# Upload the exported Mac App Store .pkg to App Store Connect using the API key.
# Run after ./Scripts/export-mas.sh. This is the step that needs your Apple creds.
#
# Required env:
#   Z_API_KEY_ID    the Key ID of your App Store Connect API key
#   Z_API_ISSUER    the Issuer ID (UUID, shown at the top of the API keys page)
#
# The private key must live at (downloadable ONCE from App Store Connect):
#   ~/.appstoreconnect/private_keys/AuthKey_<Z_API_KEY_ID>.p8
#
# GUI alternative: drop the .pkg into the Transporter app and sign in with the
# same API key (Transporter → Settings → App Store Connect API).
set -euo pipefail
cd "$(dirname "$0")/.."

: "${Z_API_KEY_ID:?set Z_API_KEY_ID (App Store Connect API Key ID)}"
: "${Z_API_ISSUER:?set Z_API_ISSUER (Issuer ID)}"

PKG="build/MAS/ZVideoGenerator.pkg"
[ -f "$PKG" ] || { echo "✗ $PKG not found — run ./Scripts/export-mas.sh first"; exit 1; }

echo "▶ uploading $PKG to App Store Connect (altool, API key)…"
xcrun altool --upload-app \
  --type macos \
  --file "$PKG" \
  --apiKey "$Z_API_KEY_ID" \
  --apiIssuer "$Z_API_ISSUER"

echo "✓ build delivered to App Store Connect."
echo "  Watch processing:"
echo "    ./Scripts/asc.py GET \"/v1/apps/6782761951/builds\""
echo "  Then add the build to the 1.1 version and Submit for Review in the web UI"
echo "  (the API can't do the final Submit — it returns 403)."
