#!/usr/bin/env bash
# Integration checks on the built .app (can't run inside `swift test`: it rebuilds the package).
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/bundle.sh >/dev/null
APP="build/QuickSnip.app"
BUNDLE_ID="${BUNDLE_ID:-dev.quicksnip.QuickSnip}"
failures=0

check() {
    if eval "$2"; then echo "✔ $1"; else echo "✘ $1"; failures=$((failures + 1)); fi
}

requirement="$(codesign -d -r - "$APP" 2>&1)"
flags="$(codesign -dv "$APP" 2>&1)"

check "signature is valid" "codesign --verify --strict '$APP' 2>/dev/null"
check "hardened runtime enabled" "grep -q 'runtime' <<<\"\$flags\""
# Regression: cdhash requirement made macOS drop the Screen Recording grant on every rebuild.
check "designated requirement survives rebuilds (no cdhash)" "! grep -q 'cdhash' <<<\"\$requirement\""
check "designated requirement pins bundle ID" "grep -q 'identifier \"$BUNDLE_ID\"' <<<\"\$requirement\""
check "KeyboardShortcuts resources bundled" "[ -d '$APP/Contents/Resources/KeyboardShortcuts_KeyboardShortcuts.bundle' ]"
check "executable is arm64" "lipo -archs '$APP/Contents/MacOS/QuickSnip' | grep -qx arm64"
check "Info.plist placeholders filled" "! grep -q '\$(' '$APP/Contents/Info.plist'"

exit "$failures"
