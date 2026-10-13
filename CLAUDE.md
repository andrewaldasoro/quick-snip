# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

QuickSnip: a macOS menu bar screenshot tool. The roadmap is in `plan.md`, with one checklist per phase in `plans/`. Tick items off as they land.

## Commands

```bash
./scripts/check.sh                               # quality gate: format lint, warnings-as-errors build, tests, coverage
./scripts/check.sh --bundle                      # same, plus test-bundle.sh
swift format format -i -r Sources Tests scripts Package.swift   # auto-format (config: .swift-format)
swift build --arch arm64                         # build
swift test                                       # all tests
swift test --filter CaptureCoordinatorTests      # one suite
swift test --filter CaptureCoordinatorTests/captureWithPermissionStartsCapture  # one test
./scripts/bundle.sh                              # build + wrap into signed build/QuickSnip.app
./scripts/run.sh                                 # bundle, kill running instance, relaunch
./scripts/test-bundle.sh                         # integration checks on the built .app (signing, requirement, resources)
VERSION=1.2.3 ./scripts/package.sh               # release build → dist/QuickSnip.zip, .dmg, SHA256SUMS
VERSION=1.2.3 ./scripts/test-package.sh          # package, then check the artifacts (signature, version, DMG layout, checksums)
swift scripts/make-icon.swift <dir>.iconset && iconutil -c icns <dir>.iconset -o Support/AppIcon.icns   # regenerate icon
/usr/bin/log stream --predicate 'subsystem == "io.github.andrewaldasoro.quicksnip"'   # app logs
```

- Full Xcode must be the selected developer dir (`xcode-select -p`). The Command Line Tools can't build this: the macOS 27 SDK's SwiftUI `@State` macro plugin ships only with Xcode.
- Use `/usr/bin/log`. In zsh, a bare `log` runs a shell builtin instead.
- Version control is Jujutsu colocated with git (`.jj/`). Prefer `jj` commands.

## CI, dependencies and security

- `.github/workflows/ci.yml` runs `./scripts/check.sh --bundle` on the `xcode-27` runner for every push to `main` and every PR. The `check` job is the required status check on `main`.
- `security.yml`: gitleaks (secrets, whole history), OSV-Scanner (`Package.resolved` vulnerabilities, fails the build), CodeQL (Swift + workflows). Also runs weekly.
- Dependabot (`.github/dependabot.yml`) sends **one** weekly PR covering every ecosystem (Swift packages, GitHub Actions). Reviewer comes from `CODEOWNERS` (`reviewers:` was removed from dependabot.yml). `dependabot-auto-merge.yml` auto-merges it when CI passes, unless it contains a major update (labelled `needs-review`).
- `release.yml` runs on a `v*` tag: quality gate → `test-package.sh` (VERSION from the tag, BUILD = run number) → build-provenance attestation → GitHub Release with the DMG, zip and checksums. Asset names have no version, so `releases/latest/download/QuickSnip.dmg` stays valid. `ci.yml` runs the same packaging as a dry run on every PR.
- `toolchain.yml` opens an issue monthly when a newer Xcode runner image exists; bump `runs-on`/`DEVELOPER_DIR` by hand.
- Pin every third-party action to a full commit SHA with the version in a comment; give each workflow `permissions: contents: read` and widen per job only.
- `test-bundle.sh` fails on runtime-weakening entitlements and App Transport Security exceptions. Never log file paths or user content with `privacy: .public` (`LogPrivacyTests`).

## Build setup

- This is a Swift Package with no `.xcodeproj`. `scripts/bundle.sh` creates the `.app`: it copies the binary and the SPM resource bundles (KeyboardShortcuts needs its bundle in `Contents/Resources`), fills the `$(BUNDLE_ID)`/`$(VERSION)`/`$(BUILD)` placeholders in `Support/Info.plist`, and codesigns with the hardened runtime. Env overrides: `CONFIG`, `BUNDLE_ID`, `VERSION`, `BUILD`, `SIGN_IDENTITY`.
- Signing is ad-hoc by default. Ad-hoc signatures normally identify the app by a hash of the binary (cdhash), which changes on every build and makes macOS drop the Screen Recording grant. So `bundle.sh` sets the designated requirement to `identifier "$BUNDLE_ID"` instead, and `test-bundle.sh` guards this. Run `test-bundle.sh` after any change to `bundle.sh`, `Info.plist`, or the entitlements.
- The package uses the Swift 6 language mode (strict concurrency). The app is arm64 only, needs macOS 15+, and sets `LSUIElement` (no Dock icon).

## Architecture

- **UI split:** SwiftUI for `MenuBarExtra`, Settings and onboarding. Settings lives in an AppKit window (`SettingsWindowController`, native toolbar tabs via `NSTabViewController`: General + Shortcuts), not a SwiftUI `Settings` scene, because the menu bar icon can be hidden: reopening the app (`applicationShouldHandleReopen`) must still open it. AppKit for anything that needs precise windowing or mouse handling (the capture overlay and annotation canvas, from Phase 1 on).
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
- **Toolbar look:** native macOS style. `NSGlassEffectView` on macOS 26+ (vibrancy fallback), borderless `ToolbarButton` glyphs (hover/press highlight, accent tint when on), `ColorSwatchButton` circles with a selection ring, and one custom-drawn `PrimaryToolbarButton` (accent fill, 28 pt like the glyphs) for the primary action (Copy). Avoid push bezels: their insets break the row alignment. Keep new controls in that style.
- **Output and preferences:** `AppSettings` (UserDefaults: save folder, PNG/JPEG, thumbnail toggle) is read by `CaptureController` at save time. `ImageEncoder` writes DPI = 72 × the display scale, so Retina captures open at their point size. After a copy or save, `ThumbnailPresenting` shows a preview. The controller dismisses it at the start of the next capture, and `ScreenCaptureKitCapturer` also leaves QuickSnip's own windows out of every capture.
- **Overlay commands:** every key and toolbar action becomes an `OverlayCommand` that `CaptureController.handle` runs: copy, save, cancel, undo, redo, delete, `selectTool`, `selectColor`, and `toggleCheatsheet`. Key bindings live only in `OverlayKeyMap.bindings` (`KeyBinding` values); key handling, toolbar tooltips and `ShortcutCheatsheet` all read that table, so a new binding shows up everywhere.
- **Cheatsheet:** `ShortcutCheatsheet` (pure model) feeds `CheatsheetView` (Settings › Shortcuts tab and the menu's Keyboard Shortcuts… window, `CheatsheetWindowController`) and `CheatsheetPanel` (drawn inside the overlay on **?**; Esc or a click closes it before cancelling anything). `CaptureHotkey` holds the current capture shortcut text; refresh it after the recorder changes.
- **OS seams:** system calls sit behind small protocols (`ScreenCaptureAccess`, `URLOpening`, `OnboardingPresenting`, `DisplayCapturing`, `OverlayPresenting`, `ImagePasteboard`, `ThumbnailPresenting`, `LoginItemService`, `SettingsPresenting`, `AppActivating`) with real defaults, so the logic runs in tests without TCC or windows. New system dependencies must follow the same pattern.
- **Focus quirk:** as a Dock-less app, QuickSnip's `NSApp.activate()` is a request macOS can decline, so windows opened unfocused. `SystemAppActivation` forces it with the deprecated `activate(ignoringOtherApps:)`, and `NSWindow.bringToFront()` raises the window. Every window QuickSnip opens must go through both.
- **Permission quirk:** `CGPreflightScreenCaptureAccess` may keep returning `false` for the running process after the user grants access. Onboarding polls the permission and offers Quit & Reopen.

## Code rules (mandatory)

Enforced by `./scripts/check.sh`. Where a rule can't be checked automatically, review against it before finishing.

- **Formatting:** `swift format` with `.swift-format` (4 spaces, 140 columns, ordered imports, no semicolons, `for` loops over `forEach`, lowerCamelCase, `///` doc comments). Run the formatter rather than fixing lint errors by hand.
- **No warnings.** The gate builds with `-warnings-as-errors`. Fix the cause; don't silence it.
- **Small, single-purpose units.** One responsibility per type, one main type per file, named after the file. Split a function once it does more than one thing or passes ~40 lines; split a type once it mixes concerns (e.g. layout math vs. drawing vs. event handling). Pure logic goes in value types (`SelectionEditor`, `CropMath`, `ToolbarLayout`) so it's testable without windows.
- **Names say what, not how.** Full words, no abbreviations except standard ones (`url`, `id`, `rect`). Booleans read as assertions (`isHovered`, `canUndo`). Functions are verbs; types are nouns.
- **Dependencies are injected.** Every system call (TCC, ScreenCaptureKit, pasteboard, file system, `SMAppService`, windows) sits behind a protocol with a real default implementation (see OS seams). No singletons in logic; `NSApp`, `NSWorkspace.shared` etc. only in adapters and views.
- **Keep OS adapters thin.** Adapters only forward to the system API. If one grows an `if`, move that decision into a tested type.
- **Access control:** `private` by default; widen only for a caller or for `@testable` tests. `final` on classes unless designed for subclassing.
- **Concurrency:** Swift 6 strict mode. UI and state types are `@MainActor`. Prefer `async`/`await` over callbacks. `MainActor.assumeIsolated` only where AppKit guarantees the main thread, with a comment saying why.
- **Errors:** no `try!`, no force unwraps in `Sources/` except for invariants that are provably safe, each with a comment. Surface failures to the user (log, inline message) rather than swallowing them; `try?` needs a reason.
- **No magic numbers.** Named `static let` constants on the owning type (`AnnotationToolbar.buttonSize`, `ToolbarLayout.margin`).
- **Comments explain why,** not what. Every non-obvious workaround (macOS quirk, window level, coordinate flip) gets one. Delete commented-out code.
- **Single source of truth.** Key bindings in `OverlayKeyMap`, preferences in `AppSettings`, styling constants on their control. Don't duplicate them.
- **Don't reach for new dependencies.** Prefer Apple frameworks; any package add needs a reason in the change description.

## Testing rules (mandatory)

- **Every unit of code gets unit tests.** Each type or file with logic has a matching suite in `Tests/QuickSnipTests/Unit/`. Write the tests with the code, in the same change. Nothing ships untested.
- **Integration tests for the most common use cases go first.** `Tests/QuickSnipTests/Integration/` covers end-to-end user flows (launch → onboarding → grant → capture; later select → annotate → copy/save) through the real wiring, faking only the OS seams. When a feature adds a common flow, write its integration test before or alongside the feature.
- **Every fix gets a regression test.** Write a test that reproduces the bug and fails before the fix, then passes after. Name it after the bug's behavior.
- **Test fakes and spies** go in `Tests/QuickSnipTests/Support/`. Use `TestDefaults` for an isolated `UserDefaults` suite. Reuse them; don't duplicate them per suite. `TestImages` builds synthetic captures whose pixels encode their own coordinates (r = x, g = y), so a test can check exactly which region a crop came from.
- **Framework:** Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest. Mark suites `@MainActor` when they touch main-actor types.
- **Coordinate math is a priority.** Points ↔ pixels, `backingScaleFactor`, multi-display origins and crop rects need thorough tests, including mixed-DPI cases. Most bugs concentrate there.
- **Test structure:** one behavior per test, named as a sentence about that behavior (`copyWithThumbnailDisabledShowsNothing`). Arrange / act / assert, with a blank line between them when it helps. No logic (loops, branches) in asserts beyond simple iteration over cases; use parameterized `@Test(arguments:)` instead.
- **Test the behavior, not the implementation.** Assert on outputs and spy calls the user would notice, not on private state. Don't loosen a test to make it pass; fix the code or explain why the expectation changed.
- **Deterministic and independent.** No real time (inject `now`/clocks), no real network, no TCC, no sleeps. Every test must pass when run alone with `--filter` (for example, call `NSApplication.shared` before touching `NSApp`).
- **Coverage gate:** total line coverage ≥ 85% and each file ≥ 60%, measured on `Sources/` minus the OS-adapter/app-shell files listed in `scripts/check.sh` (`EXEMPT`). Thresholds only go up. Adding a file to `EXEMPT` requires that it holds no logic.
- **Done means:** `./scripts/check.sh` passes (`--bundle` too when touching `bundle.sh`, `Info.plist` or entitlements), and the new behavior has unit tests, an integration test if it's a common flow, and a regression test if it's a fix.
