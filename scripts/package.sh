#!/usr/bin/env bash
# Release build → dist/QuickSnip.zip, dist/QuickSnip.dmg and dist/SHA256SUMS.
# File names carry no version, so https://github.com/andrewaldasoro/quick-snip/releases/latest/download/QuickSnip.dmg
# always points at the newest release.
#
# Env:
#   VERSION  required, x.y.z (the release tag without its "v")
#   BUILD    CFBundleVersion, must grow with every release (Sparkle compares it) (default: 1)
#   SIGN_IDENTITY, BUNDLE_ID  passed through to bundle.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-}"
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "VERSION must look like 1.2.3 (got '$VERSION')" >&2
    exit 1
fi
export VERSION BUILD="${BUILD:-1}"

CONFIG=release ./scripts/bundle.sh

APP="build/QuickSnip.app"
DIST="dist"
rm -rf "$DIST"
mkdir -p "$DIST"

# ditto keeps the code signature and extended attributes intact; plain zip can break them.
ditto -c -k --keepParent "$APP" "$DIST/QuickSnip.zip"

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
cp -R "$APP" "$staging/"
ln -s /Applications "$staging/Applications"
# `hdiutil create` is deprecated on macOS 27. UDZO (zlib) opens on every supported macOS.
# Image creation sometimes fails with "Resource busy" on CI runners; retrying is the usual fix.
for attempt in 1 2 3; do
    output="$(diskutil image create from --format UDZO --volumeName "QuickSnip $VERSION" "$staging" "$DIST/QuickSnip.dmg" 2>&1)" && break
    echo "$output" >&2
    [ "$attempt" = 3 ] && exit 1
    rm -f "$DIST/QuickSnip.dmg"
    sleep 5
done

(cd "$DIST" && shasum -a 256 QuickSnip.zip QuickSnip.dmg > SHA256SUMS)

echo "Packaged QuickSnip $VERSION ($BUILD) in $DIST/"
