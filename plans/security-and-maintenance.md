# Security & maintenance (ongoing, starts before Phase 4)

Cross-cutting track. CI and the dependency pipeline must be live before the first public release; audits repeat after that.

Repo: `github.com/andrewaldasoro/quick-snip`. Scanners (gitleaks, OSV-Scanner) run in CI only; installing them locally needs approval first.

## 1. CI pipeline (GitHub Actions)

- [x] `ci.yml` on push and PR: macOS runner, select Xcode 27, run `./scripts/check.sh --bundle`
  - Verify the hosted runner image ships Xcode 27 / macOS 27 SDK; if not, a self-hosted runner until it does
  - Cache `.build/` keyed on `Package.resolved`
- [x] Least privilege: top-level `permissions: contents: read`, widen per job only
- [x] Pin every third-party action to a full commit SHA (Dependabot keeps the pins current)
- [x] Branch protection on `main`: `check` required, no force push or deletion (admin may still push directly)

## 2. Auto-upgrade pipeline (Dependabot)

- [x] `.github/dependabot.yml`, weekly, **one PR for everything** (`multi-ecosystem-groups`); owner reviews via `CODEOWNERS`:
  - `swift` ecosystem — `Package.swift` / `Package.resolved` (KeyboardShortcuts now, Sparkle from Phase 4)
  - `github-actions` ecosystem — action SHAs
- [x] `dependabot-auto-merge.yml`: `dependabot/fetch-metadata`, then `gh pr merge --auto --squash` for patch/minor once CI passes. A PR with any major gets a `needs-review` label and waits for a human
- [x] Security updates (Dependabot alerts) enabled, same auto-merge rule (security fixes come as their own PRs)
- [x] Commit messages from Dependabot follow COMMITS format: `commit-message.prefix: "⬆️ Upgrade >"`
- [x] Toolchain not covered by Dependabot: monthly scheduled workflow checks for a newer Xcode on the runner and opens an issue; bump `swift-tools-version` / runner pin by hand

## 3. Automated security audits (CI)

- [x] **Dependency vulnerabilities:** GitHub dependency graph + Dependabot alerts; OSV-Scanner on `Package.resolved` as a CI gate (fail on known vulns)
- [x] **Static analysis:** CodeQL for Swift + workflows, on PR + weekly schedule
- [x] **Secrets:** GitHub secret scanning + push protection; gitleaks on every PR
- [x] **Signed bundle checks** — extend `test-bundle.sh`:
  - Hardened runtime on; `codesign --verify --strict --deep` passes
  - Designated requirement is the one release signing expects (identifier, or our self-signed cert) — revisit with Phase 4 signing
  - Entitlements allow-list: fail on `get-task-allow` (release), `disable-library-validation`, `allow-unsigned-executable-memory`, `allow-jit`
  - `Info.plist`: no ATS exceptions
- [ ] **Release checks** (Phase 4 `release.yml`):
  - [x] `codesign --verify --strict --deep` on the app inside the zip and the DMG (`test-package.sh`)
  - [x] SHA-256 checksums + build-provenance attestation published
  - [ ] Sparkle EdDSA signature verified before the appcast is published

## 4. Manual audit checklist (each release + quarterly)

- [x] Data handling (2026-10-10): captures only go to the clipboard or the user-chosen folder; no temp files; saved path was logged `.public` → fixed, guarded by `LogPrivacyTests`
- [x] Permissions (2026-10-10): only Screen Recording requested; onboarding copy matches what the app does
- [ ] Network: the only request is Sparkle's update check (HTTPS appcast); TLS only, no ATS exceptions. Captures never leave the Mac
- [ ] Update channel: Sparkle private key only in Keychain / CI secret, appcast over HTTPS, key rotation plan written down
- [ ] Dependencies: review new transitive packages and licenses; drop unused ones
- [ ] Generate an SBOM per release (CycloneDX from `Package.resolved`), attach to the GitHub release

## 5. Policy

- [x] `SECURITY.md`: supported versions, private reporting via GitHub security advisories, response target
- [x] CLAUDE.md: add the CI, Dependabot and audit commands once they exist

## Done when

Every PR runs check + scans; Dependabot PRs for patch/minor merge themselves when green; the release script refuses to ship a bundle that fails the signing, entitlement or vulnerability checks.
