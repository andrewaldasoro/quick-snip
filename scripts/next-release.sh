#!/usr/bin/env bash
# Prints the version to release: CHANGELOG.md's newest `## [x.y.z] - date` section, when no
# vx.y.z tag exists yet. Prints nothing when that version is already tagged (a merge without
# release notes, such as a Dependabot bump). Fails when the version doesn't come right after
# the latest tag (patch, minor or major step) or when notes sit under "Unreleased", where no
# release would ever pick them up.
#   ./scripts/next-release.sh                    # tags from origin
#   TAGS="v1.0.0 v1.0.1" ./scripts/next-release.sh  # tags given (testing)
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
    echo "next-release: $*" >&2
    exit 1
}

unreleased="$(awk '
    /^## \[Unreleased\]/ { found = 1; next }
    found && /^## \[/ { exit }
    found && /^- / { print }
' CHANGELOG.md)"
[ -z "$unreleased" ] || fail "CHANGELOG.md has notes under Unreleased; put them under a '## [x.y.z] - YYYY-MM-DD' heading"

version="$(grep -m1 -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\] - [0-9]{4}-[0-9]{2}-[0-9]{2}' CHANGELOG.md | sed -E 's/^## \[([^]]+)\].*/\1/' || true)"
[ -n "$version" ] || fail "CHANGELOG.md has no '## [x.y.z] - YYYY-MM-DD' section"

tags="${TAGS-$(git ls-remote --tags --refs origin 'v*' | sed 's|.*refs/tags/||')}"
latest="$(tr ' ' '\n' <<<"$tags" | { grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || true; } | sed 's/^v//' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)"

if tr ' ' '\n' <<<"$tags" | grep -qx "v$version"; then
    exit 0 # Already released.
fi

if [ -n "$latest" ]; then
    IFS=. read -r major minor patch <<<"$latest"
    case "$version" in
        "$major.$minor.$((patch + 1))" | "$major.$((minor + 1)).0" | "$((major + 1)).0.0") ;;
        *) fail "$version doesn't follow v$latest; use $major.$minor.$((patch + 1)) (patch), $major.$((minor + 1)).0 (minor) or $((major + 1)).0.0 (major)" ;;
    esac
fi
echo "$version"
