---
phase: 13-chacha20-cipher
plan: 01
subsystem: cipher
tags: [swift-crypto, ChaChaPoly, chacha20-poly1305, code-generation, cipher]

# Dependency graph
requires:
  - phase: 11-infrastructure-hardening
    provides: AES-GCM cipher path with ChaChaPoly already in swift-crypto dependency
  - phase: 12-developer-experience
    provides: dry-run flag and version header infrastructure used in generated output

provides:
  - CipherMode.chacha20 enum case in Config.swift
  - ChaCha20-Poly1305 encryption path in Generator.swift using ChaChaPoly.seal
  - renderChaCha20Output template producing compilable Swift with ChaChaPoly.open
  - Three ChaCha20 tests (structure, round-trip, regression guard)
  - CI compile-check for ChaCha20 generated output on macOS

affects:
  - 14-multi-environment
  - any future cipher additions (follow ChaChaKeyConfig/AESKeyConfig pattern)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ChaChaKeyConfig struct parallel to AESKeyConfig — per-cipher key+combined container"
    - "ChaChaPoly.SealedBox.combined is non-optional Data (unlike AES-GCM) — no guard-let needed"
    - "renderChaCha20Output mirrors renderAESGCMOutput structure exactly, only cipher names differ"
    - "Switch-based verbose logging in GenerateCommand covers all cipher modes exhaustively"

key-files:
  created: []
  modified:
    - Sources/SwiftSecretKeysCore/Config.swift
    - Sources/SwiftSecretKeysCore/Errors.swift
    - Sources/SwiftSecretKeysCore/Generator.swift
    - Sources/sskeys/GenerateCommand.swift
    - Tests/SwiftSecretKeysCoreTests/GeneratorTests.swift
    - .github/workflows/ci.yml

key-decisions:
  - "ChaChaPoly.SealedBox.combined returns non-optional Data — Array() directly, no guard-let required"
  - "No new SPM dependencies — ChaChaPoly already available via existing swift-crypto 4.2.0 dependency"
  - "ChaCha20 CI compile-check gated inside Darwin block alongside AES-GCM (both require CryptoKit SDK)"

patterns-established:
  - "Per-cipher private struct (AESKeyConfig, ChaChaKeyConfig) for type-safe key config containers"
  - "Per-cipher render method (renderAESGCMOutput, renderChaCha20Output) for isolated template logic"

requirements-completed:
  - CIPHER-01

# Metrics
duration: 2min
completed: 2026-02-23
---

# Phase 13 Plan 01: ChaCha20-Poly1305 Cipher Mode Summary

**ChaCha20-Poly1305 added as third cipher mode using existing swift-crypto ChaChaPoly API — zero new dependencies, full round-trip test coverage, CI compile-check gated to macOS**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-23T14:28:44Z
- **Completed:** 2026-02-23T14:30:47Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added `CipherMode.chacha20` case and updated `invalidCipher` error to list all three ciphers
- Implemented full ChaCha20-Poly1305 generation pipeline: `ChaChaKeyConfig` struct, `encryptChaCha20`, `.chacha20` switch case in `generate()`, and `renderChaCha20Output` template
- Three new tests pass: structure verification, round-trip decryption extracting key+combined bytes and calling `ChaChaPoly.open`, and XOR regression guard
- CI compile-check added for ChaCha20 generated output inside existing macOS-gated block

## Task Commits

Each task was committed atomically:

1. **Task 1: Add ChaCha20-Poly1305 cipher mode to core library and CLI** - `ce92274` (feat)
2. **Task 2: Add ChaCha20 tests and CI compile-check** - `9487cea` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `Sources/SwiftSecretKeysCore/Config.swift` - Added `case chacha20 = "chacha20"` to CipherMode enum
- `Sources/SwiftSecretKeysCore/Errors.swift` - Updated `invalidCipher` error message to list xor, aes-gcm, chacha20
- `Sources/SwiftSecretKeysCore/Generator.swift` - Added ChaChaKeyConfig struct, encryptChaCha20, .chacha20 switch case, renderChaCha20Output
- `Sources/sskeys/GenerateCommand.swift` - Replaced ternary cipher log with exhaustive switch covering all three modes
- `Tests/SwiftSecretKeysCoreTests/GeneratorTests.swift` - Added chacha20GeneratesValidStructure, chacha20RoundTripDecryption, xorModeNoChaCha20Artifacts; updated xorModeUnchanged
- `.github/workflows/ci.yml` - Added ChaCha20 compile-check step inside Darwin gate

## Decisions Made

- `ChaChaPoly.SealedBox.combined` returns non-optional `Data` (unlike `AES.GCM.SealedBox.combined` which is `Data?`) — used `Array()` directly without guard-let to avoid incorrect optional handling
- No new SPM dependencies required — `ChaChaPoly` already available via the existing `swift-crypto 4.2.0` dependency added in Phase 11
- ChaCha20 CI compile-check placed inside the existing `if [[ "$(uname)" == "Darwin" ]]` gate alongside AES-GCM since both require CryptoKit SDK typechecking

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All three cipher modes (XOR, AES-256-GCM, ChaCha20-Poly1305) are fully operational
- 39 tests pass across Generator, Sanitizer, and Config suites
- Ready for Phase 14: Multi-environment support (Config schema change — `environments:` block)

---
*Phase: 13-chacha20-cipher*
*Completed: 2026-02-23*

## Self-Check: PASSED

- All 7 files confirmed present on disk
- Commits ce92274 and 9487cea confirmed in git log
- 39 tests pass (swift test output verified)
- Build compiles cleanly (swift build output verified)
