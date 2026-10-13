#!/usr/bin/env bash
# Adds a release to the Sparkle feed: dist/QuickSnip.zip → dist/site/ (site/ + an EdDSA-signed
# appcast.xml), ready for GitHub Pages. Earlier releases are kept from the published feed.
#
# Env:
#   VERSION              required, x.y.z
#   SPARKLE_PRIVATE_KEY  the key from `generate_keys --account quicksnip -x` (CI secret);
#                        when unset, the key is read from the login Keychain
#   PREVIOUS_APPCAST     a local appcast to extend instead of the published one (testing; /dev/null = none)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:?VERSION is required}"
FEED_URL="https://andrewaldasoro.github.io/quick-snip/appcast.xml"
REPO_URL="https://github.com/andrewaldasoro/quick-snip"
BIN=".build/artifacts/sparkle/Sparkle/bin"
SITE="dist/site"

# Feeds the key on stdin (never on the command line, where `ps` would show it).
with_key() {
    if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
        printf '%s' "$SPARKLE_PRIVATE_KEY" | "$@" --ed-key-file -
    else
        "$@" --account quicksnip
    fi
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
if [ -n "${PREVIOUS_APPCAST:-}" ]; then
    [ -s "$PREVIOUS_APPCAST" ] && cp "$PREVIOUS_APPCAST" "$work/appcast.xml"
else
    # Absent before the first release.
    curl -fsSL "$FEED_URL" -o "$work/appcast.xml" || rm -f "$work/appcast.xml"
fi
cp dist/QuickSnip.zip "$work/"

with_key "$BIN/generate_appcast" \
    --download-url-prefix "$REPO_URL/releases/download/v$VERSION/" \
    --full-release-notes-url "$REPO_URL/releases" \
    --link "$REPO_URL" \
    --maximum-deltas 0 \
    "$work"

# Check what Sparkle will check before anything is published.
with_key "$BIN/sign_update" --verify "$work/appcast.xml"
signature="$(grep -o 'sparkle:edSignature="[^"]*"' "$work/appcast.xml" | head -1 | cut -d'"' -f2)"
with_key "$BIN/sign_update" --verify "$work/QuickSnip.zip" "$signature"
grep -q "<sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>" "$work/appcast.xml" || { echo "appcast has no $VERSION entry" >&2; exit 1; }

rm -rf "$SITE"
cp -R site "$SITE"
cp "$work/appcast.xml" "$SITE/appcast.xml"
echo "Appcast for $VERSION in $SITE/"
