#!/usr/bin/env bash
# Build QuickSnip and wrap it into a signed .app bundle.
#
# Env:
#   CONFIG        debug | release            (default: debug)
#   BUNDLE_ID     CFBundleIdentifier         (default: dev.quicksnip.QuickSnip)
#   VERSION       CFBundleShortVersionString (default: 0.1.0)
#   BUILD         CFBundleVersion            (default: 1)
#   SIGN_IDENTITY codesign identity          (default: "-" = ad-hoc)
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-debug}"
BUNDLE_ID="${BUNDLE_ID:-dev.quicksnip.QuickSnip}"
VERSION="${VERSION:-0.1.0}"
BUILD="${BUILD:-1}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

swift build -c "$CONFIG" --arch arm64
BIN_DIR="$(swift build -c "$CONFIG" --arch arm64 --show-bin-path)"

APP="build/QuickSnip.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/QuickSnip" "$APP/Contents/MacOS/QuickSnip"
for bundle in "$BIN_DIR"/*.bundle; do
    [ -e "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done

sed -e "s/\$(BUNDLE_ID)/$BUNDLE_ID/" \
    -e "s/\$(VERSION)/$VERSION/" \
    -e "s/\$(BUILD)/$BUILD/" \
    Support/Info.plist > "$APP/Contents/Info.plist"

# Ad-hoc signatures default to a cdhash designated requirement, which changes on every
# build and makes macOS forget the Screen Recording grant. Pin it to the bundle ID instead.
REQUIREMENT_ARGS=()
if [ "$SIGN_IDENTITY" = "-" ]; then
    REQUIREMENT_ARGS=(--requirements "=designated => identifier \"$BUNDLE_ID\"")
fi

codesign --force --deep --options runtime --timestamp=none \
    --entitlements Support/QuickSnip.entitlements \
    "${REQUIREMENT_ARGS[@]}" \
    --sign "$SIGN_IDENTITY" "$APP"

echo "Built $APP"
