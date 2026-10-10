# Phase 4 — Upload & share link (1–2 weeks)

v1 scope (decided 2026-10-10). One action uploads the selection and puts a short public link on the clipboard.

## Decisions to make first

- [ ] Storage + API: **Cloudflare R2 + a Worker** (default: no egress fees, free tier, tiny code) vs S3 + Lambda
- [ ] Link domain (own short domain vs `*.workers.dev` / `*.r2.dev`)
- [ ] Accounts: none in v1 (anonymous uploads, per-upload delete token kept locally) vs sign-in
- [ ] Retention: keep forever vs expire (e.g. 30 days); size limit per upload

## Backend

- [ ] Repo layout: `server/` in this repo (Worker + `wrangler.toml`), own tests and CI job
- [ ] `POST /upload` → stores PNG/JPEG under an unguessable id (≥ 128-bit random), returns `{ url, deleteToken }`
- [ ] `GET /<id>` serves the image (correct `Content-Type`, `nosniff`, no HTML rendering of user content)
- [ ] `DELETE /<id>` with the delete token
- [ ] Abuse controls: rate limit per IP, max size, content-type check, report/takedown address
- [ ] Strip metadata on upload (EXIF/GPS from JPEG)

## App

- [ ] `ImageUploading` protocol (OS seam) + `URLSession` adapter; fake in tests
- [ ] `OverlayCommand.upload` + toolbar button + key binding in `OverlayKeyMap` (⌘U)
- [ ] Progress + failure in the thumbnail; on success copy the link and show it
- [ ] History of uploaded links + delete tokens (Keychain for tokens) → "Delete upload" action
- [ ] Settings: upload on/off, retention info, "copy link" vs "copy image" after upload
- [ ] Privacy notice on first upload (images become public to anyone with the link)

## Tests

- [ ] Unit: request building, response parsing, error mapping, token storage
- [ ] Integration: select → upload → link on pasteboard, with a fake uploader; failure leaves image untouched
- [ ] Backend: upload/get/delete, size/type limits, rate limit

## Done when

⌘U on a selection gives a working link on the clipboard in < 2 s on a normal connection; the uploader can delete it; security track re-audit passed for the network surface.
