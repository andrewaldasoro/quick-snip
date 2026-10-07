# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

QuickSnip: a macOS menu bar screenshot tool. The roadmap is in `plan.md`, with one checklist per phase in `plans/`. Tick items off as they land.

## Commands

```bash
swift build --arch arm64                         # build
swift test                                       # all tests
swift test --filter CaptureCoordinatorTests      # one suite
swift test --filter CaptureCoordinatorTests/captureWithPermissionStartsCapture  # one test
./scripts/bundle.sh                              # build + wrap into signed build/QuickSnip.app
./scripts/run.sh                                 # bundle, kill running instance, relaunch
/usr/bin/log stream --predicate 'subsystem == "dev.quicksnip.QuickSnip"'   # app logs
```

- Full Xcode must be the selected developer dir (`xcode-select -p`). The Command Line Tools can't build this: the macOS 27 SDK's SwiftUI `@State` macro plugin ships only with Xcode.
- Use `/usr/bin/log`. In zsh, a bare `log` runs a shell builtin instead.
- Version control is Jujutsu colocated with git (`.jj/`). Prefer `jj` commands.

## Build setup

- This is a Swift Package with no `.xcodeproj`. `scripts/bundle.sh` creates the `.app`: it copies the binary and the SPM resource bundles (KeyboardShortcuts needs its bundle in `Contents/Resources`), fills the `$(BUNDLE_ID)`/`$(VERSION)`/`$(BUILD)` placeholders in `Support/Info.plist`, and codesigns with the hardened runtime. Env overrides: `CONFIG`, `BUNDLE_ID`, `VERSION`, `BUILD`, `SIGN_IDENTITY`.
- Signing is ad-hoc by default, so macOS may reset the Screen Recording permission after a rebuild. Pass `SIGN_IDENTITY` with a real certificate to avoid that.
- The package uses the Swift 6 language mode (strict concurrency). The app is arm64 only, needs macOS 15+, and sets `LSUIElement` (no Dock icon).

## Architecture

- **UI split:** SwiftUI for `MenuBarExtra`, Settings and onboarding. AppKit for anything that needs precise windowing or mouse handling (the capture overlay and annotation canvas, from Phase 1 on).
- **Entry point:** `QuickSnipApp` (SwiftUI `@main`) owns the scenes. `AppDelegate` (via `@NSApplicationDelegateAdaptor`) registers the global hotkey (`KeyboardShortcuts.Name.captureArea`) and hands off to `CaptureCoordinator`.
- **`CaptureCoordinator`** is the routing point. At launch and on each capture request it re-checks the Screen Recording permission. Without permission it shows onboarding (`OnboardingPresenting`); with it, it runs the `startCapture` closure (the Phase 1 overlay goes here).
- **OS seams:** system calls sit behind small protocols (`ScreenCaptureAccess`, `URLOpening`, `OnboardingPresenting`) with real defaults, so the logic runs in tests without TCC or windows. New system dependencies (ScreenCaptureKit, pasteboard, file system, display info) must follow the same pattern.
- **Permission quirk:** `CGPreflightScreenCaptureAccess` may keep returning `false` for the running process after the user grants access. Onboarding polls the permission and offers Quit & Reopen.

## Testing rules (mandatory)

- **Every unit of code gets unit tests.** Each type or file with logic has a matching suite in `Tests/QuickSnipTests/Unit/`. Write the tests with the code, in the same change. Nothing ships untested.
- **Integration tests for the most common use cases go first.** `Tests/QuickSnipTests/Integration/` covers end-to-end user flows (launch → onboarding → grant → capture; later select → annotate → copy/save) through the real wiring, faking only the OS seams. When a feature adds a common flow, write its integration test before or alongside the feature.
- **Every fix gets a regression test.** Write a test that reproduces the bug and fails before the fix, then passes after. Name it after the bug's behavior.
- **Test fakes and spies** go in `Tests/QuickSnipTests/Support/`. Reuse them; don't duplicate them per suite.
- **Framework:** Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest. Mark suites `@MainActor` when they touch main-actor types.
- **Coordinate math is a priority.** Points ↔ pixels, `backingScaleFactor`, multi-display origins and crop rects need thorough tests, including mixed-DPI cases. Most bugs concentrate there.
- Run `swift test` before calling any task done. All tests must pass.
