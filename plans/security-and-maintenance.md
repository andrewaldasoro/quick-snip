# Security & maintenance (ongoing, starts before Phase 5)

Cross-cutting track. CI and the dependency pipeline must be live before the first public release; audits repeat after that.

Repo: `github.com/andrewaldasoro/quick-snip`. Scanners (gitleaks, OSV-Scanner) run in CI only; installing them locally needs approval first.

## 1. CI pipeline (GitHub Actions)

- [ ] `ci.yml` on push and PR: macOS runner, select Xcode 27, run `./scripts/check.sh --bundle`
  - Verify the hosted runner image ships Xcode 27 / macOS 27 SDK; if not, a self-hosted runner until it does
  - Cache `.build/` keyed on `Package.resolved`
- [ ] Least privilege: top-level `permissions: contents: read`, widen per job only
- [ ] Pin every third-party action to a full commit SHA (Dependabot keeps the pins current)
- [ ] Branch protection on `main`: CI required, no force push

## 2. Auto-upgrade pipeline (Dependabot)

- [ ] `.github/dependabot.yml`, weekly:
  - `swift` ecosystem — `Package.swift` / `Package.resolved` (KeyboardShortcuts now, Sparkle from Phase 5)
  - `github-actions` ecosystem — action SHAs
  - `npm` ecosystem — `server/` (Worker) once Phase 4 adds it
  - Group minor + patch per ecosystem into one PR; majors separate
- [ ] `dependabot-auto-merge.yml`: `dependabot/fetch-metadata`, then `gh pr merge --auto --squash` for patch/minor once CI passes. Majors get a `needs-review` label and wait for a human
- [ ] Security updates (Dependabot alerts) enabled, same auto-merge rule
- [ ] Commit messages from Dependabot follow COMMITS format: `commit-message.prefix: "⬆️ Upgrade >"`
- [ ] Toolchain not covered by Dependabot: monthly scheduled workflow checks for a newer Xcode on the runner and opens an issue; bump `swift-tools-version` / runner pin by hand

## 3. Automated security audits (CI)

- [ ] **Dependency vulnerabilities:** GitHub dependency graph + Dependabot alerts; OSV-Scanner on `Package.resolved` as a CI gate (fail on known vulns)
- [ ] **Static analysis:** CodeQL for Swift, on PR + weekly schedule
- [ ] **Secrets:** GitHub secret scanning + push protection; gitleaks on every PR
- [ ] **Signed bundle checks** — extend `test-bundle.sh`:
  - Hardened runtime on; `codesign --verify --strict --deep` passes
  - Designated requirement is the one release signing expects (identifier, or our self-signed cert)
  - Entitlements allow-list: fail on `get-task-allow` (release), `disable-library-validation`, `allow-unsigned-executable-memory`, `allow-jit`
  - `Info.plist`: no ATS exceptions; usage strings present
- [ ] **Release checks** (Phase 5 `release.yml`): `codesign --verify --strict` on the shipped app, SHA-256 checksums + build-provenance attestation published, Sparkle EdDSA signature verified before the appcast is published

## 4. Manual audit checklist (each release + quarterly)

- [ ] Data handling: captures only go to the clipboard or the user-chosen folder; no temp files left behind; logs never contain image data or paths at `.public` privacy
- [ ] Permissions: only Screen Recording requested; onboarding copy matches what the app does
- [ ] Network: only Sparkle (HTTPS appcast) and the upload API (Phase 4); TLS only, no ATS exceptions, delete tokens in Keychain
- [ ] Upload backend: unguessable ids, size/type/rate limits, metadata stripped, `nosniff`, takedown path; Worker secrets in CI only
- [ ] Update channel: Sparkle private key only in Keychain / CI secret, appcast over HTTPS, key rotation plan written down
- [ ] Dependencies: review new transitive packages and licenses; drop unused ones
- [ ] Generate an SBOM per release (CycloneDX from `Package.resolved`), attach to the GitHub release

## 5. Policy

- [ ] `SECURITY.md`: supported versions, private reporting via GitHub security advisories, response target
- [ ] CLAUDE.md: add the CI, Dependabot and audit commands once they exist

## Done when

Every PR runs check + scans; Dependabot PRs for patch/minor merge themselves when green; the release script refuses to ship a bundle that fails the signing, entitlement or vulnerability checks.
