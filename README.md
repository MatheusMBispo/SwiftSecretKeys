# SwiftSecretKeys

![CI](https://github.com/MatheusMBispo/SwiftSecretKeys/workflows/CI/badge.svg)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20Linux-blue)
![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen)
![License](https://img.shields.io/badge/License-MIT-yellow)

**Build-time secret obfuscation for Swift projects.** CLI tool and SPM Build Tool Plugin that generates a `SecretKeys.swift` file with XOR or AES-GCM encrypted values, decoded at runtime. Prevents secrets from being trivially extracted via `strings` or binary analysis.

---

## Table of Contents

- [Why Use It](#why-use-it)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [CLI Reference](#cli-reference)
- [Configuration](#configuration)
- [SPM Build Tool Plugin](#spm-build-tool-plugin)
- [Security](#security)
- [Examples](#examples)
- [Contributing](#contributing)
- [License](#license)

---

## Why Use It

API keys and tokens embedded in iOS/macOS binaries can be extracted with a simple `strings` command. SwiftSecretKeys makes that extraction return gibberish instead of plaintext.

- **Zero runtime dependencies** — generated code uses only Foundation (XOR) or CryptoKit (AES-GCM)
- **Two cipher modes** — XOR (fast, lightweight) or AES-GCM (stronger, per-value encryption)
- **SPM Build Tool Plugin** — automatic generation on every build, no Run Script Phase needed
- **CLI for CI/CD** — `sskeys generate` runs anywhere Swift runs
- **Environment variable support** — reference `${ENV_VAR}` in your config for CI-injected secrets
- **Swift 6 strict concurrency** — generated code compiles cleanly under strict concurrency checking
- **Cross-platform** — macOS and Linux

---

## Quick Start

**1.** Create `sskeys.yml` at your project root:

```yaml
output: Sources/Generated/
keys:
  apiKey: ${API_KEY}
  analyticsToken: my-analytics-token
```

**2.** Generate the obfuscated file:

```bash
sskeys generate
```

**3.** Use the secrets in your code:

```swift
let key = SecretKeys.apiKey
let token = SecretKeys.analyticsToken
```

That's it. The generated `SecretKeys.swift` handles encoding and decoding automatically.

---

## Installation

### Swift Package Manager (recommended)

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/MatheusMBispo/SwiftSecretKeys.git", from: "1.0.0")
]
```

Then add the plugin to your target:

```swift
.target(
    name: "MyApp",
    plugins: [
        .plugin(name: "SwiftSecretKeysPlugin", package: "SwiftSecretKeys")
    ]
)
```

> [!TIP]
> With the SPM plugin, you don't need to run the CLI manually. See [SPM Build Tool Plugin](#spm-build-tool-plugin) for details.

### Mint

```bash
mint install MatheusMBispo/SwiftSecretKeys
```

### Build from Source

```bash
git clone https://github.com/MatheusMBispo/SwiftSecretKeys.git
cd SwiftSecretKeys
swift build -c release
cp .build/release/sskeys /usr/local/bin/sskeys
```

---

## CLI Reference

```
USAGE: sskeys generate [--config <path>] [--factor <n>] [--output-dir <path>] [--verbose]
```

| Option | Short | Default | Description |
|--------|-------|---------|-------------|
| `--config <path>` | `-c` | `sskeys.yml` | Path to the YAML configuration file |
| `--factor <n>` | `-f` | `32` | Salt length in bytes (XOR mode) |
| `--output-dir <path>` | | | Override output directory (ignores YAML `output` field) |
| `--verbose` | `-v` | | Print processing steps to stderr |

### Examples

```bash
# Basic generation
sskeys generate

# Custom config file
sskeys generate --config secrets/production.yml

# Verbose output for CI debugging
sskeys generate --verbose

# Custom salt factor
sskeys generate --factor 64

# Override output directory
sskeys generate --output-dir Sources/Generated/
```

When `--verbose` is enabled, processing steps are printed to **stderr** so they don't interfere with piped output or generated files.

---

## Configuration

The configuration file is written in YAML. By default, the CLI looks for `sskeys.yml` in the current directory.

### Full Reference

```yaml
# Cipher mode: "xor" (default) or "aes-gcm"
cipher: xor

# Output directory for SecretKeys.swift (relative to cwd)
output: Sources/Generated/

# Secret key-value pairs
keys:
  apiKey: my-secret-api-key
  databasePassword: ${DB_PASSWORD}      # resolved from environment
  analyticsToken: ua-123456-7
```

### Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `keys` | `{String: String}` | Yes | — | Key-value pairs. Keys become Swift property names, values are obfuscated. |
| `output` | `String` | No | `""` (cwd) | Relative path for the generated `SecretKeys.swift` file. |
| `cipher` | `String` | No | `"xor"` | Cipher mode: `"xor"` or `"aes-gcm"`. |

### Environment Variables

Use `${VARIABLE_NAME}` syntax to reference environment variables:

```yaml
keys:
  apiKey: ${API_KEY}
  secret: ${MY_SECRET}
```

Variables are resolved at generation time. If a variable is not set, the tool exits with an actionable error message.

### AES-GCM Mode

For stronger obfuscation, use AES-256-GCM:

```yaml
cipher: aes-gcm
keys:
  apiKey: ${API_KEY}
```

AES-GCM mode generates a fresh 256-bit key and a unique 12-byte nonce per secret per build. The generated code uses CryptoKit on Apple platforms and swift-crypto on Linux.

> [!NOTE]
> AES-GCM produces different ciphertext on every build even with the same input. This is by design — nonce reuse prevention.

### Key Name Sanitization

YAML key names are automatically sanitized to valid Swift identifiers:

| YAML Key | Swift Property | Rule Applied |
|----------|---------------|--------------|
| `api-key` | `api_key` | Hyphens → underscores |
| `2factor` | `key_2factor` | Leading digit → `key_` prefix |
| `class` | `` `class` `` | Reserved word → backtick-escaped |
| `my--key` | `my_key` | Consecutive underscores collapsed |

If two keys sanitize to the same identifier, the tool exits with an error explaining the collision.

---

## SPM Build Tool Plugin

The plugin runs `sskeys generate` automatically on every build. No Run Script Phase needed.

### Setup

1. Add the package dependency (see [Installation](#installation))
2. Add the plugin to your target's `plugins` array
3. Place `sskeys.yml` in the package root or the target's source directory

```swift
.target(
    name: "MyApp",
    dependencies: [...],
    plugins: [
        .plugin(name: "SwiftSecretKeysPlugin", package: "SwiftSecretKeys")
    ]
)
```

The generated `SecretKeys.swift` is placed in the build directory and compiled automatically. It does not appear in your source tree.

### Xcode Project Support

The plugin also works with Xcode projects (non-SPM) via `XcodeBuildToolPlugin`:

1. Add the SwiftSecretKeys package in Xcode
2. Open your target's **Build Phases**
3. Add `SwiftSecretKeysPlugin` under **Run Build Tool Plug-ins**
4. Place `sskeys.yml` at the Xcode project root

### How It Works

- The plugin searches for `sskeys.yml` in the target's source directory first, then the package root
- It invokes `sskeys generate --config <path> --output-dir <pluginWorkDirectory>`
- SPM incremental caching: the plugin only re-runs when `sskeys.yml` changes
- Run one build first — Xcode autocomplete for `SecretKeys` activates after the initial generation

> [!IMPORTANT]
> Secrets using `${VAR}` syntax must be present in the environment when `swift build` runs. Shell and CI environment variables are inherited by the plugin subprocess. Xcode build setting variables may not be accessible inside the SPM plugin sandbox — inject secrets via the scheme's environment variables or your CI pipeline instead.

---

## Security

SwiftSecretKeys is a **build-time obfuscation tool**, not an encryption system. It makes secrets harder to extract from compiled binaries — it does not make extraction impossible.

### What It Does

- **XOR mode:** Encodes each byte with a random salt generated per build. Makes `strings` extraction return gibberish.
- **AES-GCM mode:** Encrypts each value with AES-256-GCM using a fresh key and nonce per build. Significantly raises the effort required for extraction.

### What It Does Not Do

- Prevent a determined attacker from recovering secrets — the decode function and key material ship in the binary
- Provide tamper-proof protection against runtime analysis
- Replace a secrets manager for high-value credentials

### OWASP MASVS-RESILIENCE

This tool maps to the obfuscation mitigation class ([MASWE-0089](https://mas.owasp.org/MASWE-0089)). MASVS-RESILIENCE-3 notes that obfuscation without additional runtime controls provides limited protection against a motivated attacker with binary access.

### When to Use

- API keys for low-value or rate-limited services
- Short-lived tokens that rotate frequently
- Analytics or telemetry identifiers
- Any secret where casual inspection is the primary threat model

### When NOT to Use

- Secrets that grant access to production databases or payment systems
- Credentials whose compromise would trigger regulatory or legal consequences
- Environments where your CI/CD supports runtime secret injection (use that instead)
- Any scenario requiring cryptographic guarantees (use a dedicated secrets manager)

---

## Examples

### Minimal XOR Setup

```yaml
# sskeys.yml
keys:
  apiKey: sk-1234567890abcdef
```

```bash
sskeys generate
```

```swift
// In your app
let key = SecretKeys.apiKey  // "sk-1234567890abcdef"
```

### AES-GCM with Environment Variables

```yaml
# sskeys.yml
cipher: aes-gcm
output: Sources/Generated/
keys:
  stripeKey: ${STRIPE_SECRET_KEY}
  firebaseToken: ${FIREBASE_TOKEN}
```

```bash
export STRIPE_SECRET_KEY="sk_live_..."
export FIREBASE_TOKEN="AIza..."
sskeys generate --verbose
```

### CI/CD Integration (GitHub Actions)

```yaml
# .github/workflows/build.yml
jobs:
  build:
    runs-on: macos-latest
    env:
      API_KEY: ${{ secrets.API_KEY }}
    steps:
      - uses: actions/checkout@v4
      - run: swift build  # Plugin runs automatically
```

---

## Error Messages

SwiftSecretKeys provides actionable error messages for common issues:

| Situation | Error Message |
|-----------|--------------|
| Config file not found | `Configuration file not found at 'path'. Create sskeys.yml or use --config to specify a path.` |
| Invalid YAML | `Invalid configuration: <reason>` |
| No keys defined | `Configuration must contain a 'keys' dictionary with at least one entry.` |
| Missing env var | `Environment variable 'NAME' is not set.` |
| Bad output dir | `Output directory not found at 'path'.` |
| Invalid cipher | `Unknown cipher 'value'. Supported values: 'xor', 'aes-gcm'.` |
| Key name collision | `Key names ['a', 'b'] all sanitize to 'x'. Rename one to avoid collision.` |

---

## Other Libraries

Other obfuscation and security tools in the Swift ecosystem:

- [Arkana](https://github.com/rogerluan/arkana) — Secret keys management with code generation
- [SwiftShield](https://github.com/rockbruno/swiftshield) — Symbol obfuscation for compiled binaries
- [cocoapods-keys](https://github.com/orta/cocoapods-keys) — CocoaPods plugin for key management (CocoaPods-based)

---

## Contributing

Contributions are welcome. Please open an issue first to discuss what you'd like to change.

```bash
git clone https://github.com/MatheusMBispo/SwiftSecretKeys.git
cd SwiftSecretKeys
swift build
swift test
```

The project uses Swift 6 with strict concurrency. All 33 tests must pass on both macOS and Linux.

---

## License

SwiftSecretKeys is available under the MIT License. See the [LICENSE](LICENSE) file for details.
