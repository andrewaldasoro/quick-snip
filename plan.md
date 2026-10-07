# quick-snip — Plan

Screenshot tool for macOS. Menu bar app → global hotkey → frozen full-screen overlay → select area → annotate → copy / save (upload later).

Original name, icon and assets.

## Stack

| Area | Choice |
|---|---|
| Language | Swift 6.x, strict concurrency on, latest Xcode (verify current versions) |
| Target | macOS 15+, arm64 only |
| Build | Swift Package + `scripts/bundle.sh` (no .xcodeproj); needs full Xcode selected |
| UI | Hybrid: SwiftUI for `MenuBarExtra`, settings, onboarding · AppKit for capture overlay + annotation canvas |
| App type | `LSUIElement = YES` (no Dock icon), hardened runtime |
| Capture | ScreenCaptureKit `SCScreenshotManager` (not deprecated `CGWindowListCreateImage`) |
| Hotkey | [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — Carbon `RegisterEventHotKey`, no Accessibility permission |
| Annotations | Vector model + Core Graphics render at pixel res; Core Image for blur/pixelate |
| Undo | `UndoManager` |
| Login item | `SMAppService` |
| OCR (later) | Vision `VNRecognizeTextRequest` |
| Distribution | Developer ID + notarization + Sparkle. Mac App Store optional later |

## Key design decisions

- **Freeze, then select.** On hotkey, capture every display immediately. Show a borderless `NSPanel` per display at high window level with frozen image + dim layer. Crop from captured image. Handles moving windows / tooltips.
- **Points vs pixels.** Selection in points, images in pixels. Use per-screen `backingScaleFactor`. Mixed-DPI multi-display = main bug source.
- **Screen Recording permission.** `CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess`. Friendly onboarding. macOS re-prompts periodically → handle revocation gracefully.
- **Annotations are objects, not pixels.** `Annotation` types: arrow, line, rect, pen, marker, text, blur. Each draws itself. Enables undo/redo, select/move, crisp export.
- **Default hotkey** must not clash with ⌘⇧3/4/5 (no Print Screen key on Mac).

## Phases

| # | Phase | Estimate | File |
|---|---|---|---|
| 0 | Foundation | 1–2 days | [plans/phase-0-foundation.md](plans/phase-0-foundation.md) |
| 1 | Capture & select | 3–5 days | [plans/phase-1-capture.md](plans/phase-1-capture.md) |
| 2 | Annotation | 1–2 weeks | [plans/phase-2-annotation.md](plans/phase-2-annotation.md) |
| 3 | Polish | 1 week | [plans/phase-3-polish.md](plans/phase-3-polish.md) |
| 4 | Distribution | 2–3 days | [plans/phase-4-distribution.md](plans/phase-4-distribution.md) |
| 5 | Extras (post-v1) | — | [plans/phase-5-extras.md](plans/phase-5-extras.md) |

## Testing

Mandatory rules in [CLAUDE.md](CLAUDE.md#testing-rules-mandatory): unit suite per unit of code, integration tests for common flows first, regression test with every fix.

- Priority: coordinate math (points↔pixels, multi-display, crop rects) and annotation model. Bugs concentrate there.
- Manual: multi-monitor, mixed-scale setup.

## Open decisions

- [ ] **Upload + share link in v1?** Decides whether a backend is needed. Current default: **local-only v1** (clipboard + files); upload deferred to Phase 5. If added: Cloudflare R2 or S3 + tiny API, not a full service.
