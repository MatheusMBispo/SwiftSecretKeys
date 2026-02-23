---
phase: 11-infrastructure-hardening
plan: 03
subsystem: infra
tags: [swift, package-plugin, diagnostics, build-tool-plugin, xcodeprojectplugin]

# Dependency graph
requires:
  - phase: 11-infrastructure-hardening
    provides: SwiftSecretKeysPlugin with SPM and Xcode plugin entry points
provides:
  - Diagnostics.error on missing sskeys.yml for both SPM and Xcode plugin paths
  - Build failure (not silent warning) when sskeys.yml is absent
affects:
  - CI pipeline — missing-config scenario now produces a visible build error
  - Xcode users — missing sskeys.yml surfaces as a red error in the build log

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "PackagePlugin: use Diagnostics.error + return [] to surface build errors idomatically"

key-files:
  created: []
  modified:
    - Plugins/SwiftSecretKeysPlugin/SwiftSecretKeysPlugin.swift

key-decisions:
  - "Diagnostics.error + return [] is the idiomatic PackagePlugin pattern for hard build failures — SPM treats any Diagnostics.error as a build failure regardless of the return value"
  - "Message text unchanged — existing strings already explain the problem and remediation step"

patterns-established:
  - "Build errors in plugins: prefer Diagnostics.error over throwing, keeping return [] for SPM compatibility"

requirements-completed:
  - INFRA-02

# Metrics
duration: 2min
completed: 2026-02-23
---

# Phase 11 Plan 03: Missing sskeys.yml Produces Build Error Summary

**SwiftSecretKeysPlugin now emits Diagnostics.error (not Diagnostics.warning) on missing sskeys.yml, causing a hard build failure visible in both SPM CLI output and Xcode's build log**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-23T13:38:03Z
- **Completed:** 2026-02-23T13:40:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Changed SPM plugin entry point from `Diagnostics.warning` to `Diagnostics.error` when sskeys.yml is not found
- Changed Xcode plugin entry point (`XcodeBuildToolPlugin`) from `Diagnostics.warning` to `Diagnostics.error` when sskeys.yml is not found
- Both changes are surgical two-character word replacements — no message text, return values, or other logic altered
- `swift build` and `swift build --package-path IntegrationFixture` both pass; all 36 tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Change Diagnostics.warning to Diagnostics.error for missing sskeys.yml** - `81479b6` (fix)

**Plan metadata:** (see final metadata commit)

## Files Created/Modified

- `Plugins/SwiftSecretKeysPlugin/SwiftSecretKeysPlugin.swift` - Two `Diagnostics.warning` calls replaced with `Diagnostics.error` (lines 24 and 65)

## Decisions Made

- `Diagnostics.error` + `return []` is the correct PackagePlugin idiom: the error marks the build as failed; the empty return satisfies the `throws -> [Command]` signature without needing a separate thrown error path.
- Message strings deliberately left unchanged — they already describe the problem and the fix ("Place sskeys.yml in the target's source directory or package root").

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 11 Success Criterion 2 is satisfied: a missing sskeys.yml now causes a build error, not a silent warning, for both SPM targets and Xcode project targets.
- All Phase 11 success criteria are now met. Ready to advance to Phase 12.

---
*Phase: 11-infrastructure-hardening*
*Completed: 2026-02-23*
