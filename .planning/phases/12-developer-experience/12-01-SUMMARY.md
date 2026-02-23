---
phase: 12-developer-experience
plan: 01
subsystem: cli
tags: [swift, argument-parser, dotenv, validate, setenv]

# Dependency graph
requires:
  - phase: 11-infrastructure-hardening
    provides: SSKeysError enum with typed errors, Config.load() with env var resolution
provides:
  - sskeys validate subcommand that checks config correctness without generating files
  - DotEnvLoader that injects .env file variables into the process environment via setenv()
  - --env-file flag on both generate and validate commands
affects:
  - 12-02 (any future DX plans)
  - 13-cipher-expansion (uses generate command, will inherit --env-file)
  - 14-multi-environment (builds on Config.load, validate is key DX touchpoint)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "DotEnvLoader in CLI target only (setenv mutates global state, belongs in sskeys not SwiftSecretKeysCore)"
    - "DotEnvLoader.load() called before Config.load() to ensure setenv changes visible through ProcessInfo"
    - "ValidateCommand exits non-zero automatically via ArgumentParser error propagation"

key-files:
  created:
    - Sources/sskeys/DotEnvLoader.swift
    - Sources/sskeys/ValidateCommand.swift
  modified:
    - Sources/SwiftSecretKeysCore/Errors.swift
    - Sources/sskeys/SSKeys.swift
    - Sources/sskeys/GenerateCommand.swift

key-decisions:
  - "DotEnvLoader placed in sskeys CLI target (not SwiftSecretKeysCore) because setenv() mutates global C environ and is a CLI-only concern"
  - "dotenv load happens before Config.load() to guarantee setenv changes are visible on all platforms"
  - "ValidateCommand lets ArgumentParser's built-in error propagation handle exit codes — no manual exit() calls needed"

patterns-established:
  - "ValidateCommand pattern: load config without side effects (no file generation), useful for CI pre-flight checks"

requirements-completed:
  - DX-01
  - DX-02

# Metrics
duration: 2min
completed: 2026-02-23
---

# Phase 12 Plan 01: Developer Experience - Validate Command Summary

**`sskeys validate` subcommand and `--env-file` flag added so developers can check config locally and load secrets from dotenv files without exporting to shell**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-23T14:03:07Z
- **Completed:** 2026-02-23T14:04:46Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Added `sskeys validate` subcommand that loads config and resolves env vars without generating files — exits 0 with success count on valid config, exits non-zero with descriptive error otherwise
- Created `DotEnvLoader` in the CLI target with `setenv()`-based injection, handling comments, blank lines, and single/double quoted values
- Added `--env-file` option to both `generate` and `validate` so developers can use `.env` files instead of shell-exported variables
- Added `SSKeysError.dotEnvFileNotFound(path:)` for clear error messaging when the dotenv file path is wrong

## Task Commits

Each task was committed atomically:

1. **Task 1: Create DotEnvLoader and add error case** - `f9601bb` (feat)
2. **Task 2: Create ValidateCommand, register subcommand, add --env-file to both commands** - `d810d13` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified
- `Sources/sskeys/DotEnvLoader.swift` - Parses KEY=VALUE dotenv format, skips comments/blanks, strips quotes, calls setenv()
- `Sources/sskeys/ValidateCommand.swift` - ParsableCommand that validates config without generating files
- `Sources/sskeys/SSKeys.swift` - Added ValidateCommand.self to subcommands array
- `Sources/sskeys/GenerateCommand.swift` - Added --env-file option with DotEnvLoader call before Config.load
- `Sources/SwiftSecretKeysCore/Errors.swift` - Added dotEnvFileNotFound(path:) case with descriptive message

## Decisions Made
- DotEnvLoader lives in the `sskeys` CLI target, not `SwiftSecretKeysCore` — `setenv()` mutates global C environ and is a CLI-only side effect; library code should not have global state mutations
- DotEnvLoader.load() is called before Config.load() in both commands to ensure the C environ is updated before ProcessInfo.processInfo.environment is read
- ValidateCommand uses ArgumentParser's built-in error propagation — throwing a LocalizedError in `run()` automatically prints the errorDescription to stderr and exits non-zero; no explicit `exit()` calls needed

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `sskeys validate` is fully functional and available for CI integration
- `--env-file` works on both generate and validate commands
- No blockers for subsequent plans in phase 12 or downstream phases
- Developers can now run `sskeys validate --env-file .env` as a pre-commit or CI pre-flight step

---
*Phase: 12-developer-experience*
*Completed: 2026-02-23*

## Self-Check: PASSED

- FOUND: Sources/sskeys/DotEnvLoader.swift
- FOUND: Sources/sskeys/ValidateCommand.swift
- FOUND: .planning/phases/12-developer-experience/12-01-SUMMARY.md
- FOUND: commit f9601bb (feat: DotEnvLoader and dotEnvFileNotFound)
- FOUND: commit d810d13 (feat: ValidateCommand and --env-file flag)
