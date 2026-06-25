#!/usr/bin/env bash
#
# Notarizes the signed ClickShot.app so Gatekeeper allows it on other Macs.
# Requires the app to already be signed with a "Developer ID Application" cert
# (run ./scripts/build-app.sh first).
#
# One-time setup — store your notarization credentials in the keychain:
#
#   xcrun notarytool store-credentials clickshot-notary \
#       --apple-id "you@example.com" \
#       --team-id "K3JLT7W7G2" \
#       --password "app-specific-password"   # from appleid.apple.com
#
# Then just run:  ./scripts/notarize.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT/build/ClickShot.app"
ZIP_PATH="$ROOT/build/ClickShot.zip"
PROFILE="${NOTARY_PROFILE:-clickshot-notary}"

[[ -d "$APP_DIR" ]] || { echo "error: $APP_DIR not found — run build-app.sh first" >&2; exit 1; }

echo "==> Zipping app for submission"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo "==> Submitting to Apple notary service (this can take a few minutes)"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$PROFILE" --wait

echo "==> Stapling notarization ticket to the app"
xcrun stapler staple "$APP_DIR"

echo "==> Verifying Gatekeeper acceptance"
spctl --assess --type execute --verbose=2 "$APP_DIR"

echo ""
echo "Notarized & stapled: $APP_DIR"
echo "Distribute it by zipping again or wrapping in a .dmg."
