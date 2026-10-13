#!/usr/bin/env bash
# Integration checks on the built .app (can't run inside `swift test`: it rebuilds the package).
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/bundle.sh >/dev/null
APP="build/QuickSnip.app"
BUNDLE_ID="${BUNDLE_ID:-io.github.andrewaldasoro.quicksnip}"
failures=0

check() {
    if eval "$2"; then echo "✔ $1"; else echo "✘ $1"; failures=$((failures + 1)); fi
}

requirement="$(codesign -d -r - "$APP" 2>&1)"
flags="$(codesign -dv "$APP" 2>&1)"
entitlements="$(codesign -d --entitlements - --xml "$APP" 2>/dev/null)"
# Entitlements that weaken the hardened runtime; QuickSnip needs none of them. (It does need
# disable-library-validation: ad-hoc code has no Team ID, so Sparkle wouldn't load otherwise.)
RISKY_ENTITLEMENTS='get-task-allow|allow-unsigned-executable-memory|allow-jit|allow-dyld-environment-variables|disable-executable-page-protection'

check "signature is valid, including nested code" "codesign --verify --strict --deep '$APP' 2>/dev/null"
check "hardened runtime enabled" "grep -q 'runtime' <<<\"\$flags\""
# Regression: cdhash requirement made macOS drop the Screen Recording grant on every rebuild.
check "designated requirement survives rebuilds (no cdhash)" "! grep -q 'cdhash' <<<\"\$requirement\""
check "designated requirement pins bundle ID" "grep -q 'identifier \"$BUNDLE_ID\"' <<<\"\$requirement\""
check "no runtime-weakening entitlements" "! grep -qE '$RISKY_ENTITLEMENTS' <<<\"\$entitlements\""
check "no App Transport Security exceptions" "! /usr/libexec/PlistBuddy -c 'Print :NSAppTransportSecurity' '$APP/Contents/Info.plist' >/dev/null 2>&1"
check "KeyboardShortcuts resources bundled" "[ -d '$APP/Contents/Resources/KeyboardShortcuts_KeyboardShortcuts.bundle' ]"
check "app icon bundled" "[ -f '$APP/Contents/Resources/AppIcon.icns' ]"
check "executable is arm64" "lipo -archs '$APP/Contents/MacOS/QuickSnip' | grep -qx arm64"
check "Sparkle embedded and signed" "codesign --verify --strict '$APP/Contents/Frameworks/Sparkle.framework' 2>/dev/null"
check "Sparkle signed like the app (library validation)" \
    "[ \"\$(codesign -dv '$APP/Contents/Frameworks/Sparkle.framework' 2>&1 | grep TeamIdentifier)\" = \"\$(grep TeamIdentifier <<<\"\$flags\")\" ]"
check "no sandbox-only Sparkle XPC services" "[ ! -e '$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices' ]"
# Regression: SwiftPM left an rpath into .build, leaking the builder's home folder into the binary.
check "rpaths have no build-machine paths" "! otool -l '$APP/Contents/MacOS/QuickSnip' | grep -A2 LC_RPATH | grep -qE 'path (/Users/|$PWD)'"
check "Sparkle found via the bundle's Frameworks" "otool -l '$APP/Contents/MacOS/QuickSnip' | grep -q '@executable_path/../Frameworks'"
# Regression: library validation rejected the ad-hoc Sparkle.framework and the app died at launch.
launches() {
    "$APP/Contents/MacOS/QuickSnip" 2>/dev/null &
    local pid=$!
    sleep 2
    kill -0 "$pid" 2>/dev/null || return 1
    kill "$pid"
}
check "app launches (frameworks load)" launches
# MIT requires shipping each dependency's notice; the About panel shows Credits.html.
credits_cover_pins() {
    python3 - "$APP/Contents/Resources/Credits.html" <<'PY'
import json, sys
names = [p["location"].rstrip("/").split("/")[-1].removesuffix(".git") for p in json.load(open("Package.resolved"))["pins"]]
page = open(sys.argv[1]).read()
sys.exit(not names or any(name not in page for name in names) or "Permission is hereby granted" not in page)
PY
}
check "license notices for every dependency" credits_cover_pins
check "Info.plist placeholders filled" "! grep -q '\$(' '$APP/Contents/Info.plist'"

exit "$failures"
