# Changelog

All notable changes to QuickSnip. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

Pick the step by how big the change is for users:

- **Major** — a complete redesign, several major features at once, or a change that breaks how existing users work (a removed feature, a changed default shortcut)
- **Minor** — a big feature or a redesign of one part
- **Patch** — small changes, fixes, security and dependency upgrades

Each release's section becomes its GitHub release notes, so write it for users. Every pull request with user-facing changes adds its own `## [x.y.z] - YYYY-MM-DD` section, one step after the last release; merging it to `main` tags and publishes that version. Pull requests without user-facing changes add nothing and release nothing.

## [1.3.0] - 2026-10-30

### Changed

- **Text editing works like Markup and Figma**: Return starts a new line, in a single line of text as well as in a box. Esc, ⌘Return or a click elsewhere finishes and keeps what you typed
- **Edit text in place**: double-click text (or click it with the Text tool) to change it. Delete all of it to remove it; one undo puts it back
- A click places text that grows as you type; a drag makes a box that wraps. Both grow downward, so the lines above never move

### Fixed

- Options in the style dropdowns now highlight as you point at them, like the toolbar buttons
- Typing several lines in a text box no longer cuts them off

## [1.2.0] - 2026-10-30

### Changed

- **Style panel**: colors, line width, font, text size and alignment moved out of the toolbar into a small panel next to it, with dropdowns. Shapes get 1 to 16 px line widths; text gets every font (searchable), sizes from 10 to 96 px, and left, center or right alignment. It shows for the tool you picked or the annotation you selected, beside the toolbar, or under it when the selection is narrow
- **Text boxes**: with the Text tool, drag to make a box; the text wraps inside it and Return starts a new line. A click still places a single line. Drag a box's side to change its width
- The toolbar is one row: Read Text sits next to Save, and Save is a quieter outlined button, so Copy stands out
- After you draw a shape or place text, the tool turns off and the new annotation stays selected, so you can resize, move or restyle it right away

## [1.1.0] - 2026-10-30

### Added

- **Resize annotations**: click an annotation to select it, then drag one of its handles. Rectangles and pixelate resize from any corner or edge, lines and arrows from either end, and pen or marker strokes scale from their corners. Each resize is one undo step. Dragging a corner of a text annotation scales its size
- **Text size and font**: with the Text tool, or a text annotation selected, the toolbar shows a third row to type an exact size in pixels (or step it), pick System, Rounded, Serif, Monospaced or Handwriting, or search every installed font with **More Fonts…**. QuickSnip remembers your last font and size

### Changed

- Selected tools and the Copy button use a solid accent color with white text (black on light accent colors), so they're easier to read

## [1.0.0] - 2026-10-14

First stable release.

### Added

- **Window snap**: before you drag, the window under the pointer is highlighted; click to select exactly that window, even when other windows cover part of it

## [0.1.2] - 2026-10-14

### Added

- **Read Text** (⇧⌘C, or the text button in the toolbar): reads the text in the selection and opens it in a window, where you can fix a misread word, then copy all of it or just the part you select. Recognition runs on your Mac with Apple's Vision; anything you pixelated stays unreadable

## [0.1.1] - 2026-10-13

### Changed

- New landing page

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

[Unreleased]: https://github.com/andrewaldasoro/quick-snip/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/andrewaldasoro/quick-snip/compare/v0.1.2...v1.0.0
[0.1.2]: https://github.com/andrewaldasoro/quick-snip/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/andrewaldasoro/quick-snip/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/andrewaldasoro/quick-snip/releases/tag/v0.1.0
