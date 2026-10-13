# Security Policy

## Supported versions

Only the latest release gets security fixes.

## Reporting a vulnerability

Please report privately through [GitHub security advisories](https://github.com/andrewaldasoro/quick-snip/security/advisories/new) — not in a public issue.

Include what you found, how to reproduce it, and the QuickSnip and macOS versions. You'll get a reply within 7 days, and a fix or plan within 30 days for confirmed issues. Reporters are credited in the release notes unless they'd rather not be.

## What QuickSnip touches

- **Screen Recording** is the only permission it asks for. Captures go only to the clipboard or the folder you choose.
- Captures never leave your Mac: no accounts, no uploads. The only network request is the update check (Sparkle over HTTPS, no system profile). The feed and every update are EdDSA-signed and verified before they're read or unpacked.
- Releases are built by GitHub Actions from this repository, with SHA-256 checksums and build-provenance attestations.
