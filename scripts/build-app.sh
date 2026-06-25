#!/usr/bin/env bash
#
# Builds ClickShot and assembles a runnable .app bundle.
#
#   ./scripts/build-app.sh [debug|release]   (default: release)
#
# Code signing identity selection (first match wins):
#   1. $SIGN_ID environment variable, e.g.
#        SIGN_ID="Developer ID Application: Tengfei Ye (K3JLT7W7G2)" ./scripts/build-app.sh
#   2. An installed "Developer ID Application" certificate (best: notarizable, runs anywhere).
#   3. An installed "Apple Development" certificate (stable locally; TCC permissions persist).
#   4. Ad-hoc ("-") as a last resort (permissions reset on every rebuild).
#
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ClickShot"
BUNDLE_ID="com.clickshot.app"
APP_DIR="$ROOT/build/$APP_NAME.app"

cd "$ROOT"

# --- Pick a signing identity -------------------------------------------------
pick_identity() {
    if [[ -n "${SIGN_ID:-}" ]]; then
        echo "$SIGN_ID"; return
    fi
    local devid apple_dev
    devid="$(security find-identity -v -p codesigning 2>/dev/null \
        | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')"
    if [[ -n "$devid" ]]; then echo "$devid"; return; fi
    apple_dev="$(security find-identity -v -p codesigning 2>/dev/null \
        | grep -o '"Apple Development: [^"]*"' | head -1 | tr -d '"')"
    if [[ -n "$apple_dev" ]]; then echo "$apple_dev"; return; fi
    echo "-"
}

IDENTITY="$(pick_identity)"

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"
if [[ ! -x "$BIN_PATH" ]]; then
    echo "error: built binary not found at $BIN_PATH" >&2
    exit 1
fi

echo "==> Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT/Info.plist" "$APP_DIR/Contents/Info.plist"
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

# --- Sign --------------------------------------------------------------------
if [[ "$IDENTITY" == "-" ]]; then
    echo "==> Ad-hoc code signing (no certificate found)"
    codesign --force --sign - "$APP_DIR/Contents/MacOS/$APP_NAME"
    codesign --force --sign - "$APP_DIR"
else
    echo "==> Code signing with: $IDENTITY"
    # Hardened runtime + secure timestamp so the result is notarizable.
    SIGN_OPTS=(--force --options runtime --timestamp --identifier "$BUNDLE_ID")
    codesign "${SIGN_OPTS[@]}" --sign "$IDENTITY" "$APP_DIR/Contents/MacOS/$APP_NAME"
    codesign "${SIGN_OPTS[@]}" --sign "$IDENTITY" "$APP_DIR"
fi

echo "==> Verifying signature"
codesign --verify --strict --verbose=2 "$APP_DIR"

echo ""
echo "Built:    $APP_DIR"
echo "Identity: $IDENTITY"
echo "Run with: open \"$APP_DIR\""
if [[ "$IDENTITY" == *"Developer ID Application"* ]]; then
    echo ""
    echo "To distribute to other Macs, notarize next:"
    echo "  ./scripts/notarize.sh"
fi
