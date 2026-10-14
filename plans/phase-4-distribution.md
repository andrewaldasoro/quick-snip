# Phase 4 — Distribution (2–3 days)

GitHub Releases, no paid Apple Developer Program (decided 2026-10-10). So no Developer ID, no notarization: macOS blocks the first launch and users allow it once.

## Tasks

- [x] Release signing: **ad-hoc** + `identifier` designated requirement (decided 2026-10-13). A self-signed certificate would only stop another app from claiming our Screen Recording grant by reusing the bundle ID; it adds a cert to manage and doesn't remove the Open Anyway step. Revisit if that threat matters. The grant surviving an update is checked with the first two releases (below)
- [x] Hardened runtime on (already in `bundle.sh`)
- [x] Package: zipped `.app` (`ditto -c -k --keepParent`) + DMG with Applications link (`scripts/package.sh`, checked by `scripts/test-package.sh`; dry run in CI on every PR)
- [x] `release.yml` (GitHub Actions) on tag `v*`: `check.sh --bundle` → bundle with `VERSION`/`BUILD` from the tag → zip + DMG → SHA-256 checksums → GitHub Release with notes
- [x] Build provenance: `actions/attest-build-provenance` on the artifacts (free trust signal replacing notarization); `gh attestation verify` documented in the README
- [x] Sparkle updates (2.10): EdDSA key (login Keychain, account `quicksnip`; `SPARKLE_PRIVATE_KEY` secret), signed `appcast.xml` on GitHub Pages via `make-appcast.sh` in `release.yml`, enclosures point at release assets; Settings toggle + Check for Updates… menu item; asks before the first automatic check
  - [x] (2026-10-14) After the first two releases: an update from the older one installs, keeps the Screen Recording grant, and isn't blocked by quarantine
- [x] README install section: download, move to Applications, first launch → System Settings › Privacy & Security › **Open Anyway** (macOS 15 dropped the right-click › Open bypass); or `xattr -dr com.apple.quarantine /Applications/QuickSnip.app`
- [x] README: features, shortcut guide, permissions, settings, build from source
- [x] Third-party notices: `scripts/dependencies.py credits` writes `Credits.html` into the app (About panel, **About QuickSnip** menu item); `test-bundle.sh` fails if a dependency's notice is missing
- [x] Versioning: SemVer + `CHANGELOG.md` (Keep a Changelog); `release.yml` publishes the version's section as the release notes and fails if it's missing (`scripts/release-notes.sh`)
- [x] README: uninstall steps (login item, app, preferences, caches, Screen Recording entry)
- [ ] README screenshots / demo GIF
- [x] Landing page: GitHub Pages (same site as the appcast, `site/index.html`)

- [x] (2026-10-14) First release: tag `v0.1.0`, check the release page, download on a clean account, Open Anyway, grant Screen Recording

## Not doing (needs the paid program)

- Developer ID signing, notarization, stapling — revisit if the Gatekeeper prompt costs users
- Homebrew cask — Homebrew is removing casks that fail Gatekeeper
- Mac App Store

## Done when

Pushing a `v*` tag publishes a release with zip, DMG, checksums and attestation; a fresh Mac installs it via Open Anyway, keeps the Screen Recording grant, and receives the next version through Sparkle.
