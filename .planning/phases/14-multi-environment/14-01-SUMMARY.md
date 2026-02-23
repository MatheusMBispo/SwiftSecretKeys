---
phase: 14-multi-environment
plan: 01
subsystem: config
tags: [yaml, environments, multi-env, config-schema, spm-plugin, swift-testing]

# Dependency graph
requires:
  - phase: 13-chacha20-cipher
    provides: stable cipher suite (xor, aes-gcm, chacha20) that multi-env Config.load selects per-environment
  - phase: 12-developer-experience
    provides: --dry-run flag and ValidateCommand structure that --environment extends
provides:
  - Multi-environment sskeys.yml schema via environments: block
  - Config.load(from:environment:) with backward-compatible optional environment param
  - Config.environmentNames(from:) public helper for all-environments validation
  - --environment CLI flag on generate and validate commands
  - SSKEYS_ENVIRONMENT env var passthrough in SPM and Xcode build tool plugins
  - Cross-environment sanitization runs eagerly at load time
  - 9 new ConfigTests covering the full environment feature surface
affects: [SPM plugin consumers, Xcode plugin consumers, CI pipelines using sskeys generate]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Mutual exclusivity guard: hasEnvironments && hasFlatKeys => invalidConfig with actionable message"
    - "EnvProbe lightweight Decodable struct for YAML field inspection without full Config decode"
    - "Cross-environment eager sanitization: validate ALL env key names before resolving selected env"
    - "All-environments validate fallback: catch environmentRequired -> probe env names -> validate each"

key-files:
  created: []
  modified:
    - Sources/SwiftSecretKeysCore/Config.swift
    - Sources/SwiftSecretKeysCore/Errors.swift
    - Sources/sskeys/GenerateCommand.swift
    - Sources/sskeys/ValidateCommand.swift
    - Plugins/SwiftSecretKeysPlugin/SwiftSecretKeysPlugin.swift
    - Tests/SwiftSecretKeysCoreTests/ConfigTests.swift

key-decisions:
  - "Config.environmentNames(from:) added as public helper to SwiftSecretKeysCore so ValidateCommand avoids direct Yams import (sskeys target does not depend on Yams directly)"
  - "Cross-environment sanitization runs eagerly on ALL environments before environment selection — catches key name collisions in non-selected environments at load time"
  - "Flat keys: silently ignores --environment param to prevent CI breakage when non-migrated projects pass the flag"
  - "ValidateCommand all-environments fallback uses catch SSKeysError.environmentRequired pattern — clean separation without special-casing inside Config.load"
  - "EnvProbe struct lives inside Config.environmentNames(from:) as a private nested type — not exposed in public API"

patterns-established:
  - "New SSKeysError cases follow existing Equatable + LocalizedError pattern with errorDescription"
  - "Public Config helpers that decode YAML use the same YAMLDecoder + DecodingError catch pattern"

requirements-completed:
  - ENV-01
  - ENV-02
  - ENV-03

# Metrics
duration: 4min
completed: 2026-02-23
---

# Phase 14 Plan 01: Multi-Environment Config Support Summary

**Single sskeys.yml with environments: block selecting dev/staging/prod keys via --environment flag, with SSKEYS_ENVIRONMENT SPM/Xcode plugin passthrough and full backward compatibility with flat keys: configs**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-23T23:41:51Z
- **Completed:** 2026-02-23T23:45:13Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Multi-environment YAML schema: environments: block with per-env key dictionaries, mutual exclusivity with keys:
- Config.load gains optional environment: String? param; backward-compatible default nil preserves all existing behavior
- Cross-environment sanitization runs eagerly — key name collisions in non-selected envs are caught at load time
- --environment option on generate (required for environments: configs) and validate (all-environments fallback when omitted)
- SPM BuildToolPlugin and Xcode XcodeBuildToolPlugin both read SSKEYS_ENVIRONMENT and append --environment to subprocess
- 9 new ConfigTests cover all requirement truths; all 48 tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Config schema, error cases, and CLI environment flags** - `f184144` (feat)
2. **Task 2: Plugin environment passthrough and comprehensive tests** - `cf1f9ad` (feat)

**Plan metadata:** committed with this SUMMARY.md (docs)

## Files Created/Modified
- `Sources/SwiftSecretKeysCore/Config.swift` - RawConfig.keys optional, environments field added, Config.load(from:environment:), Config.environmentNames(from:), cross-env sanitization
- `Sources/SwiftSecretKeysCore/Errors.swift` - environmentNotFound(name:available:) and environmentRequired cases; missingKeys description updated
- `Sources/sskeys/GenerateCommand.swift` - --environment option added, Config.load call updated
- `Sources/sskeys/ValidateCommand.swift` - --environment option added, all-environments fallback via catch environmentRequired
- `Plugins/SwiftSecretKeysPlugin/SwiftSecretKeysPlugin.swift` - SSKEYS_ENVIRONMENT passthrough in both SPM and Xcode plugin paths
- `Tests/SwiftSecretKeysCoreTests/ConfigTests.swift` - 9 new environment tests added to existing suite

## Decisions Made
- `Config.environmentNames(from:)` added as public helper to SwiftSecretKeysCore so ValidateCommand doesn't need direct Yams import — the sskeys CLI target only depends on SwiftSecretKeysCore, not Yams
- Cross-environment eager sanitization approach: validate ALL environment key names before selecting the target environment. This catches collisions in non-selected envs at load time, not at generation time
- Flat `keys:` silently ignores `--environment` param — prevents CI breakage when non-migrated projects inadvertently receive the flag via SSKEYS_ENVIRONMENT plugin passthrough
- ValidateCommand all-environments fallback uses `catch SSKeysError.environmentRequired` pattern rather than pre-inspecting the YAML — keeps Config.load as the single authority on config validity
- `EnvProbe` struct (lightweight Decodable for environment name extraction) lives as a private nested type inside `Config.environmentNames(from:)` — not leaked into public API

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Moved EnvProbe struct and Yams import from ValidateCommand to Config.swift**
- **Found during:** Task 1 (ValidateCommand.swift implementation)
- **Issue:** Plan specified putting `EnvProbe: Decodable` struct directly in ValidateCommand.swift with `import Yams`. However, the sskeys CLI target does not list Yams as a dependency in Package.swift — importing Yams there would cause a build error.
- **Fix:** Added `Config.environmentNames(from:) -> [String]` as a public static helper in SwiftSecretKeysCore/Config.swift (where Yams is already imported). ValidateCommand calls this helper without any Yams import.
- **Files modified:** Sources/SwiftSecretKeysCore/Config.swift, Sources/sskeys/ValidateCommand.swift
- **Verification:** `swift build` completes without errors; `swift test` all 48 tests pass
- **Committed in:** f184144 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (blocking — missing dependency access)
**Impact on plan:** Fix necessary for compilation. The refactored approach (Config.environmentNames as public helper) is architecturally superior to having ValidateCommand import Yams directly.

## Issues Encountered
None beyond the auto-fixed Yams import issue above.

## User Setup Required
None - no external service configuration required. SSKEYS_ENVIRONMENT is a process environment variable consumers set in their build system or CI.

## Next Phase Readiness
- Phase 14 is the final planned phase. All planned requirements (ENV-01, ENV-02, ENV-03) are complete.
- Multi-environment support is fully functional and backward compatible.
- SPM and Xcode plugin consumers can set SSKEYS_ENVIRONMENT in CI or Xcode build settings to select environments at build time.

---
*Phase: 14-multi-environment*
*Completed: 2026-02-23*

## Self-Check: PASSED

- FOUND: Sources/SwiftSecretKeysCore/Config.swift
- FOUND: Sources/SwiftSecretKeysCore/Errors.swift
- FOUND: Sources/sskeys/GenerateCommand.swift
- FOUND: Sources/sskeys/ValidateCommand.swift
- FOUND: Plugins/SwiftSecretKeysPlugin/SwiftSecretKeysPlugin.swift
- FOUND: Tests/SwiftSecretKeysCoreTests/ConfigTests.swift
- FOUND: .planning/phases/14-multi-environment/14-01-SUMMARY.md
- FOUND commit f184144: feat(14-01): add multi-environment config schema, error cases, and CLI flags
- FOUND commit cf1f9ad: feat(14-01): add SSKEYS_ENVIRONMENT plugin passthrough and environment config tests
