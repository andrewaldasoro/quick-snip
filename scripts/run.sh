#!/usr/bin/env bash
# Bundle, then relaunch QuickSnip.
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/bundle.sh

# pkill returns before the old instance exits; `open` fails with -600 if it's still going.
if pkill -x QuickSnip 2>/dev/null; then
    for _ in $(seq 1 50); do
        pgrep -x QuickSnip >/dev/null || break
        sleep 0.1
    done
fi
# LaunchServices can still hold the old instance for a moment after it exits.
for attempt in 1 2 3 4 5; do
    open build/QuickSnip.app 2>/dev/null && exit 0
    sleep 0.5
done
open build/QuickSnip.app
