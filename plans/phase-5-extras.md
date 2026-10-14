# Phase 5 — Extras (post-v1, optional)

## Candidates

- [x] **OCR text copy** (2026-10-13): ⇧⌘C / toolbar → on-device Vision (`RecognizeTextRequest`) on the rendered selection (pixelate respected), reading order, Recognized Text window to review/edit and copy all or part (nothing copied automatically); notices for reading / no text / failure
- [x] **Window-snap selection** (2026-10-14): window frames come with the capture (`CGWindowListCopyWindowInfo`, front to back, app-window layer only, clipped per display by `WindowSnap`); before a selection exists, hover outlines the window under the cursor and a click selects it; a drag still selects freely; a covered window is captured on its own and painted in front (`CoveredWindowLoader`), so the copy is the window, not what overlapped it

## Future (not planned)

- [ ] **Screenshot history** — recent captures list in menu (deferred 2026-10-14; open questions: kept on disk? opt-in? how many?)
