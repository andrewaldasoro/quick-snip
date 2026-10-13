# quick-snip — Plan

Screenshot tool for macOS. Menu bar app → global hotkey → frozen full-screen overlay → select area → annotate → copy / save. Local only: no accounts, no uploads, no cloud.

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
| Distribution | GitHub Releases (zip + DMG), ad-hoc, Sparkle (signed feed on GitHub Pages). No paid Apple program → no notarization |
| CI / security | GitHub Actions (`check.sh --bundle`), Dependabot auto-upgrades, CodeQL, OSV-Scanner, gitleaks |

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
| — | Security & maintenance (ongoing, before Phase 4) | 1–2 days setup | [plans/security-and-maintenance.md](plans/security-and-maintenance.md) |

## Testing

Mandatory rules in [CLAUDE.md](CLAUDE.md#testing-rules-mandatory): unit suite per unit of code, integration tests for common flows first, regression test with every fix.

- Priority: coordinate math (points↔pixels, multi-display, crop rects) and annotation model. Bugs concentrate there.
- Manual: multi-monitor, mixed-scale setup.

## Open decisions

- [x] **Upload + share link?** No (2026-10-13): QuickSnip stays a local app. No cloud features.
- [x] **Bundle ID.** `io.github.andrewaldasoro.quicksnip`.
- [x] **Signing / distribution.** Free: GitHub Releases, no Developer ID (users click Open Anyway once). See Phase 4.
- [x] **Repo hosting.** GitHub: `git@github.com:andrewaldasoro/quick-snip.git` (remote `origin`, bookmark `main`).
