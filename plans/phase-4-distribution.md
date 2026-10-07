# Phase 4 — Distribution (2–3 days)

## Tasks

- [ ] Developer ID Application certificate
- [ ] Code sign with hardened runtime
- [ ] Notarize (`notarytool`) + staple
- [ ] Build DMG
- [ ] Sparkle: integrate, EdDSA keys, appcast hosting
- [ ] Release script (archive → sign → notarize → DMG → appcast)
- [ ] Simple landing page with download link

## Later / optional

- Mac App Store build (ScreenCaptureKit works sandboxed) — slows iteration, defer

## Done when

Fresh Mac downloads DMG, installs without Gatekeeper warnings, receives updates via Sparkle.
