# Changelog

All notable changes to QuickSnip. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/):

- **Major** — a change that breaks how existing users work (a removed feature, a changed default shortcut)
- **Minor** — new features
- **Patch** — fixes

Each release's section becomes its GitHub release notes, so write it for users. Add changes under **Unreleased** as they land; rename it to the version when you tag.

## [Unreleased]

### Added

- **Read Text** (⇧⌘C, or the text button in the toolbar): reads the text in the selection and opens it in a window, where you can fix a misread word, then copy all of it or just the part you select. Recognition runs on your Mac with Apple's Vision; anything you pixelated stays unreadable

## [0.1.0] - 2026-10-13

First release.

### Added

- Capture an area with **⇧⌘2** (or your own shortcut): every display freezes first, so menus and tooltips are captured as they were
- Select, move and resize the area on any display, with its pixel size shown
- Annotate with rectangles, arrows, lines, pen, marker, text and pixelate; move, delete, undo and redo any mark
- Copy with **Return** or **⌘C**, save with **⌘S**, at full Retina resolution
- Keyboard shortcuts for every tool and color; press **?** during a capture to see them all
- Thumbnail after each capture; click it to open the saved file
- Settings: shortcut, save folder, PNG or JPEG, thumbnail, menu bar icon, launch at login
- Automatic updates (asks first; signed updates only)

[Unreleased]: https://github.com/andrewaldasoro/quick-snip/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/andrewaldasoro/quick-snip/releases/tag/v0.1.0
