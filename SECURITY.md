# Security Policy

## Supported versions

Only the latest release gets security fixes.

## Reporting a vulnerability

Please report privately through [GitHub security advisories](https://github.com/andrewaldasoro/quick-snip/security/advisories/new) — not in a public issue.

Include what you found, how to reproduce it, and the QuickSnip and macOS versions. You'll get a reply within 7 days, and a fix or plan within 30 days for confirmed issues. Reporters are credited in the release notes unless they'd rather not be.

## What QuickSnip touches

- **Screen Recording** is the only permission it asks for. Captures go only to the clipboard or the folder you choose.
- It makes no network requests today. Planned: update checks (Sparkle, HTTPS, signed updates) and opt-in uploads.
- Releases are built by GitHub Actions from this repository, with SHA-256 checksums and build-provenance attestations.
