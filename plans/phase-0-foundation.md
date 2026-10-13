# Phase 0 — Foundation (1–2 days)

Build setup: Swift Package (no .xcodeproj) + `scripts/bundle.sh` wraps the binary into a signed `.app`. Requires full Xcode selected (`xcode-select`) — the macOS 27 SDK's SwiftUI `@State` macro plugin ships only with Xcode, not Command Line Tools.

## Tasks

- [x] Swift package: macOS app, SwiftUI lifecycle, Swift 6 language mode (strict concurrency)
- [x] arm64-only build, macOS 15 minimum, hardened runtime (codesign `--options runtime`)
- [x] `Info.plist`: `LSUIElement = YES`
- [x] `MenuBarExtra` with menu (Capture Area, Settings…, Quit)
- [x] `Settings` scene with shortcut recorder
- [x] KeyboardShortcuts via SPM; `captureArea` default ⌘⇧2
- [x] Screen Recording permission: preflight on launch + before capture, request from onboarding
- [x] Onboarding window: explains permission, opens System Settings, polls state, Quit & Reopen
- [x] Test target (Swift Testing)
- [x] Manual check: hotkey logs, permission grant + relaunch
- [x] Bundle ID: `io.github.andrewaldasoro.quicksnip` (GitHub namespace, owned)
- [x] ~~Apple Development signing identity~~ Not needed: ad-hoc signing with an `identifier` designated requirement keeps the Screen Recording grant across rebuilds (`bundle.sh`, guarded by `test-bundle.sh`)

## Done when

- App runs from menu bar, no Dock icon
- Hotkey fires a log/stub action
- Onboarding shows when permission missing, disappears once granted

## Manual check

```
./scripts/run.sh
/usr/bin/log stream --predicate 'subsystem == "io.github.andrewaldasoro.quicksnip"'
```
