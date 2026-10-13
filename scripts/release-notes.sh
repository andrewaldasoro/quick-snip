#!/usr/bin/env bash
# Prints a version's section from CHANGELOG.md (the GitHub release notes). Fails if the
# section is missing or empty, so a release can't ship without notes.
#   ./scripts/release-notes.sh 1.2.3
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: release-notes.sh VERSION}"
notes="$(awk -v heading="## [$VERSION]" '
    index($0, heading) == 1 { found = 1; next }
    found && /^## \[/ { exit }
    found && /^\[[^]]+\]: / { exit }
    found { print }
' CHANGELOG.md | sed -e '/./,$!d')"

if [ -z "$(tr -d '[:space:]' <<<"$notes")" ]; then
    echo "CHANGELOG.md has no notes for $VERSION; add a '## [$VERSION] - YYYY-MM-DD' section" >&2
    exit 1
fi
printf '%s\n' "$notes"
