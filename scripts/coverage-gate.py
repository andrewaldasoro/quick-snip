"""Fails when line coverage drops below the gate. Reads `llvm-cov export -summary-only` JSON on stdin.

Usage: coverage-gate.py <total-min-percent> <per-file-min-percent>
"""

import json
import sys

total_min, file_min = float(sys.argv[1]), float(sys.argv[2])
data = json.load(sys.stdin)["data"][0]
ok = True

for entry in sorted(data["files"], key=lambda f: f["summary"]["lines"]["percent"]):
    percent = entry["summary"]["lines"]["percent"]
    if percent < file_min:
        name = entry["filename"].split("Sources/")[-1]
        print(f"✘ {percent:5.1f}%  {name}")
        ok = False

total = data["totals"]["lines"]["percent"]
ok = ok and total >= total_min
print(f"{'✔' if ok else '✘'} total {total:.1f}%")
sys.exit(0 if ok else 1)
