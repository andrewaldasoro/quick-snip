# Phase 4 — Distribution (2–3 days)

GitHub Releases, no paid Apple Developer Program (decided 2026-10-10). So no Developer ID, no notarization: macOS blocks the first launch and users allow it once.

## Tasks

- [ ] Release signing: keep ad-hoc + `identifier` requirement, or a free self-signed code-signing certificate (CI secret) so the designated requirement pins our cert, not just the ID (stronger: another app can't claim our Screen Recording grant by reusing the ID). Decide and test that the grant survives an update
- [x] Hardened runtime on (already in `bundle.sh`)
- [x] Package: zipped `.app` (`ditto -c -k --keepParent`) + DMG with Applications link (`scripts/package.sh`, checked by `scripts/test-package.sh`; dry run in CI on every PR)
- [x] `release.yml` (GitHub Actions) on tag `v*`: `check.sh --bundle` → bundle with `VERSION`/`BUILD` from the tag → zip + DMG → SHA-256 checksums → GitHub Release with notes
- [x] Build provenance: `actions/attest-build-provenance` on the artifacts (free trust signal replacing notarization); `gh attestation verify` documented in the README
- [ ] Sparkle updates: EdDSA keys (private key as CI secret), `appcast.xml` on GitHub Pages, enclosures point at release assets. Check the update keeps the TCC grant and isn't blocked by quarantine
- [x] README install section: download, move to Applications, first launch → System Settings › Privacy & Security › **Open Anyway** (macOS 15 dropped the right-click › Open bypass); or `xattr -dr com.apple.quarantine /Applications/QuickSnip.app`
- [x] README: features, shortcut guide, permissions, settings, build from source
- [ ] README screenshots / demo GIF
- [ ] Landing page: GitHub Pages (same site as the appcast)

- [ ] First release: tag `v0.1.0`, check the release page, download on a clean account, Open Anyway, grant Screen Recording

## Not doing (needs the paid program)

- Developer ID signing, notarization, stapling — revisit if the Gatekeeper prompt costs users
- Homebrew cask — Homebrew is removing casks that fail Gatekeeper
- Mac App Store

## Done when

Pushing a `v*` tag publishes a release with zip, DMG, checksums and attestation; a fresh Mac installs it via Open Anyway, keeps the Screen Recording grant, and receives the next version through Sparkle.
