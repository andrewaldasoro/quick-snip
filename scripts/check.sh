#!/usr/bin/env bash
# Quality gate. A task isn't done until this passes.
#   ./scripts/check.sh            lint, strict build, tests, coverage
#   ./scripts/check.sh --bundle   also build the .app and run test-bundle.sh
set -euo pipefail
cd "$(dirname "$0")/.."

# Minimum line coverage. Raise these as coverage grows; never lower them.
TOTAL_MIN=85
FILE_MIN=60
# OS adapters and app shell: thin wrappers over system APIs (TCC, ScreenCaptureKit,
# NSPasteboard, app activation, Sparkle, SwiftUI scene bodies) that only run in the real app. Keep logic out of them.
EXEMPT='SparkleUpdater|AppActivation|QuickSnipApp|AppDelegate|OnboardingView|Clipboard|ScreenCaptureAccess|DisplayCapturing|WindowImageCapturing'

step() { printf '\n▸ %s\n' "$1"; }

step "Format (swift format lint --strict)"
swift format lint --strict --recursive --parallel Sources Tests scripts Package.swift

step "Build (warnings are errors)"
if ! output="$(swift build --arch arm64 -Xswiftc -warnings-as-errors 2>&1)"; then
    echo "$output" | grep -E "error|warning"
    exit 1
fi

step "Tests"
if ! output="$(swift test --enable-code-coverage 2>&1)"; then
    # ↳ lines carry each failed expectation's values and message.
    echo "$output" | grep -E "✘|↳|error:" | grep -vE "↳ (Testing Library Version|Target Platform)"
    exit 1
fi
echo "$output" | grep -E "Test run with"

step "Coverage (total ≥ ${TOTAL_MIN}%, each file ≥ ${FILE_MIN}%)"
profile="$(dirname "$(swift test --show-codecov-path)")/default.profdata"
binary="$(swift build --show-bin-path)/QuickSnipTests.xctest/Contents/MacOS/QuickSnipTests"
xcrun llvm-cov export "$binary" -instr-profile "$profile" -summary-only \
    --ignore-filename-regex="(\.build|Tests)/|($EXEMPT)\.swift" |
    python3 scripts/coverage-gate.py "$TOTAL_MIN" "$FILE_MIN"

if [[ "${1:-}" == "--bundle" ]]; then
    step "Bundle"
    ./scripts/test-bundle.sh
fi

printf '\n✔ All checks passed\n'
