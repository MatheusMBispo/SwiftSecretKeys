---
phase: 11-infrastructure-hardening
plan: 02
subsystem: infra
tags: [ci, spm-plugin, swiftc, integration-testing, github-actions]

# Dependency graph
requires: []
provides:
  - IntegrationFixture SPM package for end-to-end plugin testing
  - CI compile check for generated XOR and AES-GCM SecretKeys.swift output
  - CI integration test exercising SwiftSecretKeysPlugin build tool plugin

affects:
  - future plugin changes (regression caught by CI compile check)
  - future template changes (syntax errors caught before user impact)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "IntegrationFixture pattern: separate SPM package referencing parent repo via local path dependency to test build tool plugins"
    - "CI template regression: swiftc -parse for Foundation-only output, swiftc -typecheck with SDK for CryptoKit output"

key-files:
  created:
    - IntegrationFixture/Package.swift
    - IntegrationFixture/sskeys.yml
    - IntegrationFixture/Sources/FixtureApp/main.swift
  modified:
    - .github/workflows/ci.yml

key-decisions:
  - "Use package identity 'SwiftSecretKeys' (directory name) not 'sskeys' (Package.swift name field) for local path dependency plugin reference — SPM derives identity from directory, not the name field"
  - "Keep IntegrationFixture at swift-tools-version 6.2 (same as parent) rather than 6.0 — CI uses 6.2, no compatibility benefit from downgrading"
  - "Use swiftc -parse for XOR mode (no SDK needed, works cross-platform) and swiftc -typecheck with SDK for AES-GCM (CryptoKit requires macOS SDK)"

patterns-established:
  - "Plugin consumer pattern: external fixture package at repo root references parent via .package(path: '../') with identity matching directory name"

requirements-completed:
  - INFRA-01
  - INFRA-02

# Metrics
duration: 3min
completed: 2026-02-23
---

# Phase 11 Plan 02: CI Compile Checks and SPM Plugin Integration Fixture Summary

**CI now catches template regressions and exercises the full SPM Build Tool Plugin code path on every PR via swiftc compile checks and an IntegrationFixture package**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-23T13:19:42Z
- **Completed:** 2026-02-23T13:22:51Z
- **Tasks:** 2
- **Files modified:** 4 (3 created, 1 modified)

## Accomplishments

- Created IntegrationFixture SPM package at repo root that exercises SwiftSecretKeysPlugin end-to-end via a local path dependency — the only way to test build tool plugins (plugins cannot be applied to targets in the same package that declares them)
- Added CI step that runs `swiftc -parse` on generated XOR output (both Ubuntu and macOS) and `swiftc -typecheck` with SDK on generated AES-GCM output (macOS only, CryptoKit dependency)
- Added CI integration test step that runs `swift build --package-path IntegrationFixture` on every PR, proving the plugin discovers sskeys.yml, generates SecretKeys.swift, and the output compiles

## Task Commits

1. **Task 1: Create IntegrationFixture package for SPM Build Tool Plugin testing** - `5a30997` (feat)
2. **Task 2: Add CI steps for generated output compilation and plugin integration test** - `c6a919d` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `IntegrationFixture/Package.swift` - Minimal SPM package depending on parent repo, applying SwiftSecretKeysPlugin to FixtureApp target
- `IntegrationFixture/sskeys.yml` - Minimal config with FIXTURE_KEY for plugin exercise
- `IntegrationFixture/Sources/FixtureApp/main.swift` - Minimal executable target for plugin code generation
- `.github/workflows/ci.yml` - Added two new steps: compile-check and integration-test, positioned between Build and Test with coverage

## Decisions Made

- Used `package: "SwiftSecretKeys"` (directory name) not `package: "sskeys"` (Package.swift name field) in the plugin reference — SPM derives local dependency identity from directory name, not the `name` field. Using `"sskeys"` produced "product not found" error despite the product existing.
- Kept `swift-tools-version: 6.2` in IntegrationFixture (same as parent) — the plan suggested 6.0 for broader compatibility but CI is already pinned to 6.2, and the local fixture only needs to run there.
- AES-GCM typecheck uses `-sdk $(xcrun --show-sdk-path)` on macOS only — Linux lacks CryptoKit; standalone `swiftc` cannot locate swift-crypto's `Crypto` module, so Linux AES-GCM is skipped by design.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed incorrect package identity in plugin reference**
- **Found during:** Task 1 (IntegrationFixture package creation)
- **Issue:** Plan specified `package: "sskeys"` but SPM derives local path dependency identity from the directory name `"SwiftSecretKeys"`, not from the `name` field in Package.swift. Build failed with "product 'SwiftSecretKeysPlugin' not found in package 'sskeys'"
- **Fix:** Changed to `package: "SwiftSecretKeys"` to match the directory-derived identity
- **Files modified:** IntegrationFixture/Package.swift
- **Verification:** `swift build --package-path IntegrationFixture` exits 0
- **Committed in:** `5a30997` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug — incorrect package identity)
**Impact on plan:** Essential fix for the build to succeed. No scope creep.

## Issues Encountered

SPM package identity for local path dependencies: SPM uses the last path component of the directory as the package identity (not the `name` field in Package.swift). When referencing a plugin product from a local dependency, the `package:` argument in `.plugin(name:package:)` must match the directory name. This is a non-obvious SPM behavior that caused the initial build failure and was auto-corrected.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- CI now has template regression protection for both cipher modes
- Plugin integration test runs on every PR, catching plugin-breaking changes early
- IntegrationFixture is ready to be extended with additional test scenarios (e.g., testing sskeys.yml in target directory vs package root)
- Phase 11-01 (env var substitution, force-unwrap guards) can proceed independently

---
*Phase: 11-infrastructure-hardening*
*Completed: 2026-02-23*

## Self-Check: PASSED

- IntegrationFixture/Package.swift: FOUND
- IntegrationFixture/sskeys.yml: FOUND
- IntegrationFixture/Sources/FixtureApp/main.swift: FOUND
- .github/workflows/ci.yml: FOUND
- 11-02-SUMMARY.md: FOUND
- Commit 5a30997 (Task 1): FOUND
- Commit c6a919d (Task 2): FOUND
