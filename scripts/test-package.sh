#!/usr/bin/env bash
# Checks the release artifacts from package.sh: what a user downloads must install and run.
#   VERSION=1.2.3 ./scripts/test-package.sh   (packages first unless --no-build)
set -euo pipefail
cd "$(dirname "$0")/.."

[ "${1:-}" = "--no-build" ] || ./scripts/package.sh >/dev/null
VERSION="${VERSION:?VERSION is required}"
DIST="dist"
failures=0

check() {
    if eval "$2"; then echo "✔ $1"; else echo "✘ $1"; failures=$((failures + 1)); fi
}

work="$(mktemp -d)"
mount="$work/mount"
trap 'hdiutil detach "$mount" -quiet 2>/dev/null || true; rm -rf "$work"' EXIT

check "checksums match" "(cd '$DIST' && shasum -a 256 -c SHA256SUMS >/dev/null)"

ditto -x -k "$DIST/QuickSnip.zip" "$work/zip"
zipped="$work/zip/QuickSnip.app"
check "zip holds a validly signed app" "codesign --verify --strict --deep '$zipped' 2>/dev/null"
check "zipped app has the release version" \
    "[ \"\$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' '$zipped/Contents/Info.plist')\" = '$VERSION' ]"
check "zipped app has the build number" \
    "[ \"\$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' '$zipped/Contents/Info.plist')\" = '${BUILD:-1}' ]"

hdiutil attach "$DIST/QuickSnip.dmg" -nobrowse -readonly -mountpoint "$mount" -quiet
check "DMG holds a validly signed app" "codesign --verify --strict --deep '$mount/QuickSnip.app' 2>/dev/null"
check "DMG links to Applications" "[ \"\$(readlink '$mount/Applications')\" = /Applications ]"
check "DMG and zip ship the same binary" "cmp -s '$mount/QuickSnip.app/Contents/MacOS/QuickSnip' '$zipped/Contents/MacOS/QuickSnip'"

exit "$failures"
