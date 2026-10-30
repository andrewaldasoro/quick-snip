# Phase 5 — Extras (post-v1, optional)

## Candidates

- [x] **OCR text copy** (2026-10-13): ⇧⌘C / toolbar → on-device Vision (`RecognizeTextRequest`) on the rendered selection (pixelate respected), reading order, Recognized Text window to review/edit and copy all or part (nothing copied automatically); notices for reading / no text / failure
- [x] **Window-snap selection** (2026-10-14): window frames come with the capture (`CGWindowListCopyWindowInfo`, front to back, app-window layer only, clipped per display by `WindowSnap`); before a selection exists, hover outlines the window under the cursor and a click selects it; a drag still selects freely; a covered window is captured on its own and painted in front (`CoveredWindowLoader`), so the copy is the window, not what overlapped it
- [x] **Resize annotations** (2026-10-30): handles on the selected annotation (no tool): 8 on rectangle/pixelate, one per end on line/arrow, corners on pen/marker (points scaled into the new box); handles win over the selection's; one undo step per drag (`AnnotationResizer`)
- [x] **Text size and font** (2026-10-30): exact size in px (`FontSizeControl`: field + stepper, 8–200, parsed by `TextSize`), curated fonts inline (`TextFont`: system, rounded, serif, monospaced, handwriting) plus More Fonts… (`FontListPanel`, every installed family from `FontCatalog`, searchable) in a third toolbar row for text; applies to new and selected text; remembered in `AppSettings`; text corners scale the size

## Future (not planned)

- [ ] **Screenshot history** — recent captures list in menu (deferred 2026-10-14; open questions: kept on disk? opt-in? how many?)
