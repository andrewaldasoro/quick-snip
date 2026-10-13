# Phase 3 — Polish (1 week)

## Tasks

- [x] Settings (`AppSettings`, persisted in UserDefaults; `SettingsView`):
  - [x] Default save folder (Choose… panel, `~`-abbreviated path)
  - [x] Image format (PNG / JPEG 90%)
  - [x] Hotkey recorder
  - [x] Optional menu bar icon (`MenuBarExtra(isInserted:)`); reopening the app shows Settings (`SettingsWindowController`)
  - [x] Launch at login (`SMAppService`, errors shown inline — `LaunchAtLoginModel`)
  - [x] Show floating thumbnail after capture (toggle, default on)
- [x] Native-style toolbar: Liquid Glass panel, borderless glyph buttons, color swatches, accent Copy button
- [x] Floating post-capture thumbnail: bottom-right, 5 s, click opens saved file, close button (`ThumbnailPanelController`, `ThumbnailLayout`)
- [x] Retina DPI metadata (72 × scale) in copied and saved images (`ImageEncoder`) — from Phase 1
- [x] Per-region cursors: resize per handle, open/closed hand, I-beam for text, arrow over toolbar (`OverlayCursor`) — from Phase 1
- [x] Multi-display hardening:
  - [x] QuickSnip's own windows (thumbnail, settings, onboarding) excluded from captures
  - [x] Display added/removed/rearranged mid-capture → capture cancelled cleanly
- [x] Full-screen apps and Spaces: panels use `.canJoinAllSpaces` + `.fullScreenAuxiliary` at `.screenSaver` level (manual check below)
- [x] Accessibility labels: toolbar (with shortcuts), overlay (label + help), thumbnail, settings controls
- [x] Keyboard shortcuts for tools (R A L P M T X, press again to turn off) and colors (1–8); shown in tooltips
- [x] App icon (original artwork, `scripts/make-icon.swift` → `Support/AppIcon.icns`)
- [x] Shortcut recorder records on the first click (KeyboardShortcuts 3.1: macOS 26+ editing restart)
- [x] Crosshair shows as soon as the screen freezes (forced activation + cursor refresh)
- [x] Settings window: sized to content, raised and focused (`NSWindow.hosting`, `bringToFront`, `SystemAppActivation`)
- [x] `run.sh` waits for the previous instance and retries `open` (fixed -600 on quick relaunch)
- [ ] Keyboard shortcut cheatsheet, generated from `OverlayKeyMap` + the capture hotkey (single source of truth, so it can't drift from the real bindings or the README):
  - [ ] `ShortcutCheatsheet` model (sections: global, capture, tools, colors, text) — unit-tested against `OverlayKeyMap`
  - [ ] `CheatsheetView` (SwiftUI, grouped list, native key-cap style); shows the user's current capture hotkey
  - [ ] Settings: "Shortcuts" section/tab with the cheatsheet
  - [ ] Menu bar menu: "Keyboard Shortcuts…" item opening the cheatsheet window (goes through `AppActivating` + `bringToFront`)
  - [ ] Integration test: menu item and Settings both show the same entries
  - [ ] Overlay: **?** toggles a cheatsheet overlay during capture (`OverlayCommand.toggleCheatsheet` in `OverlayKeyMap`; Esc/**?** closes it without cancelling the capture); drawn in-view, not a menu/popover (the overlay sits above menus)
- [ ] Manual test pass:
  - [x] Different resolutions / scales (2026-10-10)
  - [ ] Multi-monitor mixed scale at once
  - [ ] Full-screen app
  - [ ] Spaces
  - [ ] Launch at login

## Done when

v1 feature-complete; no known coordinate bugs on mixed-DPI setups.
