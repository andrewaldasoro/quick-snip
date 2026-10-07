#!/usr/bin/env bash
# Bundle, then relaunch QuickSnip.
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/bundle.sh
pkill -x QuickSnip 2>/dev/null || true
open build/QuickSnip.app
