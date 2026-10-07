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
./scripts/test-bundle.sh                         # integration checks on the built .app (signing, requirement, resources)
/usr/bin/log stream --predicate 'subsystem == "dev.quicksnip.QuickSnip"'   # app logs
```

- Full Xcode must be the selected developer dir (`xcode-select -p`). The Command Line Tools can't build this: the macOS 27 SDK's SwiftUI `@State` macro plugin ships only with Xcode.
- Use `/usr/bin/log`. In zsh, a bare `log` runs a shell builtin instead.
- Version control is Jujutsu colocated with git (`.jj/`). Prefer `jj` commands.

## Build setup

- This is a Swift Package with no `.xcodeproj`. `scripts/bundle.sh` creates the `.app`: it copies the binary and the SPM resource bundles (KeyboardShortcuts needs its bundle in `Contents/Resources`), fills the `$(BUNDLE_ID)`/`$(VERSION)`/`$(BUILD)` placeholders in `Support/Info.plist`, and codesigns with the hardened runtime. Env overrides: `CONFIG`, `BUNDLE_ID`, `VERSION`, `BUILD`, `SIGN_IDENTITY`.
- Signing is ad-hoc by default. Ad-hoc signatures normally identify the app by a hash of the binary (cdhash), which changes on every build and makes macOS drop the Screen Recording grant. So `bundle.sh` sets the designated requirement to `identifier "$BUNDLE_ID"` instead, and `test-bundle.sh` guards this. Run `test-bundle.sh` after any change to `bundle.sh`, `Info.plist`, or the entitlements.
- The package uses the Swift 6 language mode (strict concurrency). The app is arm64 only, needs macOS 15+, and sets `LSUIElement` (no Dock icon).

## Architecture

- **UI split:** SwiftUI for `MenuBarExtra`, Settings and onboarding. AppKit for anything that needs precise windowing or mouse handling (the capture overlay and annotation canvas, from Phase 1 on).
- **Entry point:** `QuickSnipApp` (SwiftUI `@main`) owns the scenes. `AppDelegate` (via `@NSApplicationDelegateAdaptor`) registers the global hotkey (`KeyboardShortcuts.Name.captureArea`) and hands off to `CaptureCoordinator`.
- **Capture flow:** hotkey → `CaptureCoordinator`, which re-checks the Screen Recording permission (onboarding if missing). Then `CaptureController.start()` → `DisplayCapturing` freezes every display into a `CapturedDisplay` (AppKit global frame + full-res `CGImage`) → a `CaptureSession` is created → `OverlayPresenting` shows it. The overlay sends an `OverlayCommand` (copy / save / cancel) back to the controller, which crops, PNG-encodes, and writes to `ImagePasteboard` or `ScreenshotSaver`.
- **Coordinate spaces.** Getting these wrong is the main bug source:
  - `CapturedDisplay.frame` is in AppKit global points, with a bottom-left origin. It's only used to position panels.
  - Selections are display-local points with a top-left origin. `SelectionOverlayView` is flipped to match.
  - `CropMath` maps points to pixels using captured image size ÷ point size per axis (not `backingScaleFactor`), and rounds each edge independently.
- **Selection model:** `SelectionEditor` (pure struct, one per display) handles create, move, and resize via handles, clamped to the display. `CaptureSession` keeps a single active selection across displays and calls `onChange` so every panel redraws.
- **Annotations:** `Annotation` values (rectangle, line, arrow, pen, marker, text, pixelate) are stored in display-local points, the same space as the selection. `AnnotationDocument` owns the committed list and undo (a snapshot per change, `groupsByEvent = false`). `CaptureSession` routes the mouse: handles resize the selection; with a tool active, a drag draws and a click places text; with no tool, a drag moves the annotation under the cursor. In-progress shapes are a preview (`draft`) and are committed once on mouse-up, so each action is one undo step.
- **Rendering:** `AnnotationRenderer` draws into any context whose user space is display-local points with a top-left origin. The flipped overlay view already has that; `ExportRenderer` sets up a pixel context to match (scale plus a y-flip) and produces the full-resolution output. Text uses `NSGraphicsContext(flipped: true)`; pixelate flips images locally.
- **Overlay window level:** `.screenSaver`, which is above where macOS draws pop-up menus. Don't use `NSPopUpButton` or menus in the overlay; they would open hidden behind it.
- **OS seams:** system calls sit behind small protocols (`ScreenCaptureAccess`, `URLOpening`, `OnboardingPresenting`, `DisplayCapturing`, `OverlayPresenting`, `ImagePasteboard`) with real defaults, so the logic runs in tests without TCC or windows. New system dependencies must follow the same pattern.
- **Permission quirk:** `CGPreflightScreenCaptureAccess` may keep returning `false` for the running process after the user grants access. Onboarding polls the permission and offers Quit & Reopen.

## Testing rules (mandatory)

- **Every unit of code gets unit tests.** Each type or file with logic has a matching suite in `Tests/QuickSnipTests/Unit/`. Write the tests with the code, in the same change. Nothing ships untested.
- **Integration tests for the most common use cases go first.** `Tests/QuickSnipTests/Integration/` covers end-to-end user flows (launch → onboarding → grant → capture; later select → annotate → copy/save) through the real wiring, faking only the OS seams. When a feature adds a common flow, write its integration test before or alongside the feature.
- **Every fix gets a regression test.** Write a test that reproduces the bug and fails before the fix, then passes after. Name it after the bug's behavior.
- **Test fakes and spies** go in `Tests/QuickSnipTests/Support/`. Reuse them; don't duplicate them per suite. `TestImages` builds synthetic captures whose pixels encode their own coordinates (r = x, g = y), so a test can check exactly which region a crop came from.
- **Framework:** Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest. Mark suites `@MainActor` when they touch main-actor types.
- **Coordinate math is a priority.** Points ↔ pixels, `backingScaleFactor`, multi-display origins and crop rects need thorough tests, including mixed-DPI cases. Most bugs concentrate there.
- Run `swift test` before calling any task done. All tests must pass.
