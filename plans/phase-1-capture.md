# Phase 1 — Capture & Select (3–5 days)

## Tasks

- [ ] Capture service: on hotkey, grab every display via `SCScreenshotManager` at native pixel resolution
- [ ] Handle missing/revoked permission → route to onboarding instead of failing silently
- [ ] Overlay: one borderless `NSPanel` per `NSScreen`, high window level, covers full frame, joins all Spaces
- [ ] Overlay view (AppKit `NSView`): frozen image + dim layer, undimmed selection rect
- [ ] Mouse handling: drag to create selection; resize handles; drag inside to move
- [ ] Live size label (pixel dimensions)
- [ ] Esc cancels and tears down all overlays
- [ ] Crop: convert selection points → pixels with that screen's `backingScaleFactor`, crop from captured `CGImage`
- [ ] Copy to clipboard: `NSPasteboard` as PNG
- [ ] Save to file: default folder (Desktop/Pictures), timestamped filename
- [ ] Unit tests: point↔pixel conversion, crop rect math, multi-display coordinate origins

## Done when

**Milestone: working basic screenshot tool.** Hotkey → select → copy or save produces a pixel-correct PNG on Retina and non-Retina displays.
