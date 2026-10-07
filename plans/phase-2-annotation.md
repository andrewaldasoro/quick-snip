# Phase 2 — Annotation (1–2 weeks)

## Tasks

- [ ] Floating toolbar anchored to selection (repositions when selection near screen edge)
- [ ] `Annotation` model: protocol/enum with geometry, style (color, thickness), `draw(in: CGContext)`
- [ ] Canvas view: renders annotations over selection, hit-testing, select/move shapes
- [ ] Tools, in order:
  - [ ] Rectangle
  - [ ] Arrow
  - [ ] Line
  - [ ] Pen (freehand)
  - [ ] Marker (translucent highlighter)
  - [ ] Text
  - [ ] Blur / pixelate (Core Image) — prioritize, heavily used
- [ ] Color picker + thickness picker
- [ ] Undo/redo via `UndoManager` (⌘Z / ⌘⇧Z)
- [ ] Render pipeline: cropped image + annotations → final `CGImage` at pixel resolution via Core Graphics
- [ ] Actions wired: Copy, Save, Cancel; optional "Open in editor"
- [ ] Unit tests: annotation model, undo stack, render output dimensions

## Done when

All tools usable, undoable, and exported crisply at full resolution.
