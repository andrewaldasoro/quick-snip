# Phase 1 — Capture & Select (3–5 days)

## Tasks

- [x] Capture service: on hotkey, grab every display via `SCScreenshotManager` at native pixel resolution (`ScreenCaptureKitCapturer`)
- [x] Missing/revoked permission → onboarding instead of capture (`CaptureCoordinator`)
- [x] Overlay: one borderless `NSPanel` per display, `.screenSaver` level, all Spaces + full-screen apps (`OverlayWindowManager`)
- [x] Overlay view: frozen image + dim layer, undimmed selection, border, 8 handles (`SelectionOverlayView`)
- [x] Mouse: drag to create, drag inside to move, corners/edges to resize, clamped to display (`SelectionEditor`)
- [x] Live pixel size label (`SizeLabel`)
- [x] Esc cancels; Return/Enter/⌘C copy; ⌘S save (`OverlayKeyMap`)
- [x] One selection across displays — selecting on another display clears the previous (`CaptureSession`)
- [x] Crop: points → pixels from captured image size per display, edges rounded independently (`CropMath`)
- [x] Copy to clipboard as PNG (`SystemImagePasteboard`)
- [x] Save to Desktop as `QuickSnip yyyy-MM-dd at HH.mm.ss.png`, never overwrites (`ScreenshotSaver`)
- [x] Unit tests: crop math (1x/2x/1.5x/non-uniform, tiling, clamping), selection editing, session, controller, key map, view rendering, panels
- [x] Integration tests: hotkey → select → copy (Retina + 1x external), switch displays, adjust then copy, save, cancel, no permission
- [x] Manual check on real hardware (2026-10-14) (multi-display, mixed DPI, full-screen app, Spaces)

## Deferred to Phase 3

- Per-region cursors (move/resize) — crosshair only for now
- Retina DPI metadata in saved PNGs (144 dpi so they open at point size)

## Done when

**Milestone: working basic screenshot tool.** Hotkey → select → copy or save produces a pixel-correct PNG on Retina and non-Retina displays.
