#!/usr/bin/env bash
# Build QuickSnip and wrap it into a signed .app bundle.
#
# Env:
#   CONFIG        debug | release            (default: debug)
#   BUNDLE_ID     CFBundleIdentifier         (default: io.github.andrewaldasoro.quicksnip)
#   VERSION       CFBundleShortVersionString (default: 0.1.0)
#   BUILD         CFBundleVersion            (default: 1)
#   SIGN_IDENTITY codesign identity          (default: "-" = ad-hoc)
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-debug}"
BUNDLE_ID="${BUNDLE_ID:-io.github.andrewaldasoro.quicksnip}"
VERSION="${VERSION:-0.1.0}"
BUILD="${BUILD:-1}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

swift build -c "$CONFIG" --arch arm64
BIN_DIR="$(swift build -c "$CONFIG" --arch arm64 --show-bin-path)"

APP="build/QuickSnip.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/QuickSnip" "$APP/Contents/MacOS/QuickSnip"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
for bundle in "$BIN_DIR"/*.bundle; do
    [ -e "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done
# Third-party license notices (MIT requires shipping them); the About panel shows Credits.html.
python3 scripts/dependencies.py credits "$APP/Contents/Resources/Credits.html"
# Settings › What's New reads the release notes from here.
cp CHANGELOG.md "$APP/Contents/Resources/CHANGELOG.md"

# Sparkle (updates). ditto keeps the framework's symlinks. The XPC services are only for
# sandboxed apps and the headers only for building, so they're dropped.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
mkdir -p "$APP/Contents/Frameworks"
ditto "$BIN_DIR/Sparkle.framework" "$SPARKLE"
rm -rf "$SPARKLE/Versions/B/XPCServices" "$SPARKLE/Versions/B/Headers" "$SPARKLE/Versions/B/PrivateHeaders" \
    "$SPARKLE/Versions/B/Modules" "$SPARKLE/XPCServices" "$SPARKLE/Headers" "$SPARKLE/PrivateHeaders" "$SPARKLE/Modules"

# SwiftPM links frameworks via @rpath but only adds rpaths into .build (an absolute path with
# the builder's user name). Point it at the bundle's Frameworks folder instead.
EXECUTABLE="$APP/Contents/MacOS/QuickSnip"
for rpath in $(otool -l "$EXECUTABLE" | awk '/LC_RPATH/ { getline; getline; print $2 }'); do
    [[ "$rpath" == /Users/* || "$rpath" == "$PWD"* ]] && install_name_tool -delete_rpath "$rpath" "$EXECUTABLE"
done
install_name_tool -add_rpath "@executable_path/../Frameworks" "$EXECUTABLE" 2>/dev/null

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

# Nested code first, inside out (Sparkle's documented order), then the app. Hardened runtime's
# library validation only loads a framework signed by the same identity as the app, so
# Sparkle's own signature is replaced.
for nested in "$SPARKLE/Versions/B/Autoupdate" "$SPARKLE/Versions/B/Updater.app" "$SPARKLE"; do
    codesign --force --options runtime --timestamp=none --sign "$SIGN_IDENTITY" "$nested"
done

codesign --force --options runtime --timestamp=none \
    --entitlements Support/QuickSnip.entitlements \
    "${REQUIREMENT_ARGS[@]}" \
    --sign "$SIGN_IDENTITY" "$APP"

echo "Built $APP"
