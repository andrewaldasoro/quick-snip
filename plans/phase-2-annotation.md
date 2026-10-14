# Phase 2 — Annotation (1–2 weeks)

## Tasks

- [x] Floating toolbar anchored to selection: below, right-aligned → above → inside; hidden while the selection is dragged (`AnnotationToolbar`, `ToolbarLayout`)
- [x] `Annotation` model: vector kinds + style, hit-testing, offset (`Annotation`, `Geometry`)
- [x] Canvas: annotations drawn on the overlay, clipped to the selection; select (dashed outline) and move shapes without a tool
- [x] Tools:
  - [x] Rectangle
  - [x] Arrow
  - [x] Line
  - [x] Pen (freehand; click = dot)
  - [x] Marker (translucent, 4× width)
  - [x] Text (inline `NSTextField`, Return/click-away commits, Esc cancels)
  - [x] Pixelate (Core Image, 10pt blocks, cached per region)
- [x] Color (8) + stroke width (thin/medium/thick) — inline segments, apply to new and selected annotations
- [x] Undo/redo via `UndoManager`, snapshot-based; one step per drag (⌘Z / ⌘⇧Z, toolbar buttons)
- [x] Delete selected annotation (Delete / Forward Delete)
- [x] Render pipeline: crop + annotations → `CGImage` at full pixel resolution (`ExportRenderer`)
- [x] Actions wired: Copy, Save, Cancel (toolbar + keys)
- [x] Unit tests: model, builder, document/undo, geometry, renderer (pixel checks incl. Retina stroke width), pixelate, layout, toolbar, session routing, view text entry
- [x] Integration tests: rectangle, arrow, pixelate, text, undo/redo, move + delete, pen + marker + save, resize after annotating, cancel
- [x] Manual check on real hardware (2026-10-14)

## Decisions

- Annotations live in display-local points (same space as the selection), so moving/resizing the selection leaves them in place on screen.
- Once a selection has annotations, clicking outside it no longer starts a new selection (prevents losing work).
- Colors/widths are inline segmented controls, not pop-ups: menus open below the overlay's `.screenSaver` window level.

## Deferred

- "Open in editor" (optional) → Phase 5 candidate
- Tool keyboard shortcuts → Phase 3 (already listed)

## Done when

All tools usable, undoable, and exported crisply at full resolution.
