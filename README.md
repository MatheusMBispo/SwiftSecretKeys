# SwiftSecretKeys

![CI](https://github.com/MatheusMBispo/SwiftSecretKeys/workflows/CI/badge.svg)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20Linux-blue)
![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen)
![License](https://img.shields.io/badge/License-MIT-yellow)

**Build-time secret obfuscation for Swift projects — keep your API keys out of `strings` dumps.** CLI tool and SPM Build Tool Plugin that generates a `SecretKeys.swift` file with XOR, AES-GCM, or ChaCha20-Poly1305 encrypted values, decoded at runtime. Prevents secrets from being trivially extracted via `strings` or binary analysis.

Works as a **CLI tool** and as an **SPM Build Tool Plugin** — zero config for most projects.

---

## Table of Contents

- [Why Use It](#why-use-it)
- [🚀 Quick Start](#quick-start)
- [📦 Installation](#installation)
- [🔧 CLI Reference](#cli-reference)
- [⚙️ Configuration](#configuration)
- [🛠️ SPM Build Tool Plugin](#spm-build-tool-plugin)
- [🛡️ Security](#security)
- [💡 Examples](#examples)
- [🤝 Contributing](#contributing)
- [📄 License](#license)

---

## Why Use It

Shipping API keys in your iOS/macOS binary? Anyone with `strings` can read them in seconds. SwiftSecretKeys makes that return gibberish instead of your secrets.

- **Zero runtime dependencies** — generated code uses only Foundation (XOR) or CryptoKit (AES-GCM, ChaCha20-Poly1305)
- **Three cipher modes** — XOR (fast, lightweight), AES-GCM (stronger, per-value encryption), or ChaCha20-Poly1305 (modern AEAD alternative)
- **SPM Build Tool Plugin** — automatic generation on every build, no Run Script Phase needed
- **CLI for CI/CD** — `sskeys generate` runs anywhere Swift runs
- **Developer tools** — `sskeys validate` checks config without generating, `--dry-run` previews output, `.env` file loading
- **Multi-environment support** — define per-environment secrets with `environments:` block
- **Environment variable support** — reference `${ENV_VAR}` in your config for CI-injected secrets
- **Swift 6 strict concurrency** — generated code compiles cleanly under strict concurrency checking
- **Cross-platform** — macOS and Linux

---

## 🚀 Quick Start

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

That's it — three steps and your secrets are obfuscated.

---

## 📦 Installation

### Swift Package Manager (recommended)

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/MatheusMBispo/SwiftSecretKeys.git", from: "1.1.0")
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

## 🔧 CLI Reference

The `sskeys` tool has two subcommands: `generate` (default) and `validate`.

### `sskeys generate`

Generate a `.swift` file with obfuscated secrets.

```
USAGE: sskeys generate [--config <path>] [--factor <n>] [--output-dir <path>] [--env-file <path>] [--dry-run] [--environment <name>] [--verbose]
```

| Option | Short | Default | Description |
|--------|-------|---------|-------------|
| `--config <path>` | `-c` | `sskeys.yml` | Path to the YAML configuration file |
| `--factor <n>` | `-f` | `32` | Salt length in bytes (XOR mode) |
| `--output-dir <path>` | | | Override output directory (ignores YAML `output` field) |
| `--env-file <path>` | | | Path to a .env file to load before generation |
| `--dry-run` | | | Print generated output to stdout without writing files |
| `--environment <name>` | `-e` | | Target environment when using `environments:` block |
| `--verbose` | `-v` | | Print processing steps to stderr |

#### Examples

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

# Preview generated output without writing files
sskeys generate --dry-run

# Load secrets from a .env file
sskeys generate --env-file .env.local

# Generate for a specific environment
sskeys generate --environment staging

# Combine flags
sskeys generate --env-file .env.local --environment prod --verbose
```

When `--verbose` is enabled, processing steps are printed to **stderr** so they don't interfere with piped output or generated files.

### `sskeys validate`

Check config and resolve environment variables without generating files.

```
USAGE: sskeys validate [--config <path>] [--env-file <path>] [--environment <name>]
```

| Option | Short | Default | Description |
|--------|-------|---------|-------------|
| `--config <path>` | `-c` | `sskeys.yml` | Path to the YAML configuration file |
| `--env-file <path>` | | | Path to a .env file to load before validation |
| `--environment <name>` | `-e` | | Target environment to validate (omit to validate all) |

#### Examples

```bash
# Validate default config
sskeys validate

# Validate a specific environment
sskeys validate --environment prod

# Validate with .env file loaded
sskeys validate --env-file .env.local

# Validate a specific config file
sskeys validate --config secrets/production.yml
```

When no `--environment` is specified and the config uses an `environments:` block, `validate` checks all environments and reports each one individually.

---

## ⚙️ Configuration

The configuration file is written in YAML. By default, the CLI looks for `sskeys.yml` in the current directory.

### Full Reference

```yaml
# Cipher mode: "xor" (default), "aes-gcm", or "chacha20"
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
| `keys` | `{String: String}` | Yes* | — | Key-value pairs. Keys become Swift property names, values are obfuscated. |
| `environments` | `{String: {String: String}}` | Yes* | — | Per-environment key-value pairs. Mutually exclusive with `keys`. |
| `output` | `String` | No | `""` (cwd) | Relative path for the generated `SecretKeys.swift` file. |
| `cipher` | `String` | No | `"xor"` | Cipher mode: `"xor"`, `"aes-gcm"`, or `"chacha20"`. |

*One of `keys` or `environments` is required.

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

### ChaCha20-Poly1305 Mode

For a modern AEAD alternative to AES-GCM:

```yaml
cipher: chacha20
keys:
  apiKey: ${API_KEY}
```

ChaCha20-Poly1305 uses the same security model as AES-GCM: a fresh 256-bit key and 12-byte nonce per build, with authenticated encryption. The generated code uses CryptoKit on Apple platforms and swift-crypto on Linux.

ChaCha20-Poly1305 is a modern alternative preferred in some contexts, particularly on platforms without AES hardware acceleration (AES-NI). Both ciphers provide equivalent security guarantees.

> [!NOTE]
> Like AES-GCM, ChaCha20-Poly1305 produces different ciphertext on every build. This is by design.

### Multi-Environment Configuration

For projects that need different secrets per environment (dev, staging, prod), use the `environments:` block instead of `keys:`:

```yaml
cipher: aes-gcm
output: Sources/Generated/
environments:
  dev:
    apiKey: dev-key-123
    apiUrl: https://dev.api.example.com
  staging:
    apiKey: ${STAGING_API_KEY}
    apiUrl: https://staging.api.example.com
  prod:
    apiKey: ${PROD_API_KEY}
    apiUrl: https://api.example.com
```

Select an environment with `--environment <name>`:

```bash
sskeys generate --environment prod
```

> [!IMPORTANT]
> - You cannot mix `keys:` and `environments:` in the same config file.
> - All environments are validated for key name sanitization even when selecting a single one.
> - When `environments:` is present, `--environment` is required for `generate`.

### .env File Support

Load environment variables from a `.env` file before resolving `${VAR}` references:

```bash
sskeys generate --env-file .env.local
sskeys validate --env-file .env.local
```

The `.env` file supports standard formats:

```env
# Database credentials
DB_PASSWORD=my-secret-password
API_KEY="quoted-value"
ANALYTICS_TOKEN='single-quoted'
```

- Lines starting with `#` are treated as comments
- Blank lines are ignored
- Values can be unquoted, double-quoted, or single-quoted
- Variables are injected into the process environment before config resolution

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

## 🛠️ SPM Build Tool Plugin

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

### Multi-Environment with the Plugin

When using multi-environment configuration, set the `SSKEYS_ENVIRONMENT` environment variable. The plugin reads this variable and automatically passes `--environment <value>` to the CLI.

```bash
# In your CI/CD pipeline or Xcode scheme environment variables:
SSKEYS_ENVIRONMENT=prod swift build
```

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

## 🛡️ Security

SwiftSecretKeys is a **build-time obfuscation tool**, not an encryption system. It makes secrets harder to extract from compiled binaries — it does not make extraction impossible.

### What It Does

- **XOR mode:** Encodes each byte with a random salt generated per build. Makes `strings` extraction return gibberish.
- **AES-GCM mode:** Encrypts each value with AES-256-GCM using a fresh key and nonce per build. Significantly raises the effort required for extraction.
- **ChaCha20-Poly1305 mode:** Encrypts each value with ChaCha20-Poly1305 AEAD using a fresh key and nonce per build. Equivalent security profile to AES-GCM, preferred on platforms without AES-NI.

### What It Does Not Do

- Prevent a determined attacker from recovering secrets — the decode function and key material ship in the binary
- Provide tamper-proof protection against runtime analysis
- Replace a secrets manager for high-value credentials

### OWASP MASVS-RESILIENCE

This tool maps to the obfuscation mitigation class ([MASWE-0089](https://mas.owasp.org/MASWE-0089)). MASVS-RESILIENCE-3 notes that obfuscation without additional runtime controls provides limited protection against a motivated attacker with binary access.

### ✅ When to Use

- API keys for low-value or rate-limited services
- Short-lived tokens that rotate frequently
- Analytics or telemetry identifiers
- Any secret where casual inspection is the primary threat model

### ⚠️ When NOT to Use

- Secrets that grant access to production databases or payment systems
- Credentials whose compromise would trigger regulatory or legal consequences
- Environments where your CI/CD supports runtime secret injection (use that instead)
- Any scenario requiring cryptographic guarantees (use a dedicated secrets manager)

---

## 💡 Examples

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

### ChaCha20-Poly1305 Setup

```yaml
# sskeys.yml
cipher: chacha20
output: Sources/Generated/
keys:
  apiKey: ${API_KEY}
  webhookSecret: ${WEBHOOK_SECRET}
```

```bash
export API_KEY="my-api-key"
export WEBHOOK_SECRET="whsec_..."
sskeys generate --verbose
```

### Multi-Environment Setup

```yaml
# sskeys.yml
cipher: aes-gcm
output: Sources/Generated/
environments:
  dev:
    apiKey: dev-key-123
    apiUrl: https://dev.api.example.com
  staging:
    apiKey: ${STAGING_API_KEY}
    apiUrl: https://staging.api.example.com
  prod:
    apiKey: ${PROD_API_KEY}
    apiUrl: https://api.example.com
```

```bash
# Generate for a specific environment
sskeys generate --environment dev

# Validate all environments at once
sskeys validate

# Validate a single environment
sskeys validate --environment prod

# Use in CI/CD with the SPM plugin
SSKEYS_ENVIRONMENT=prod swift build
```

### Dry Run Preview

Preview the generated `SecretKeys.swift` without writing any files:

```bash
sskeys generate --dry-run
sskeys generate --dry-run --environment staging
```

### Using a .env File

Create a `.env.local` file with your secrets:

```env
# .env.local
API_KEY=sk-1234567890abcdef
STRIPE_SECRET_KEY=sk_live_...
```

Then reference them in your config:

```yaml
# sskeys.yml
cipher: aes-gcm
keys:
  apiKey: ${API_KEY}
  stripeKey: ${STRIPE_SECRET_KEY}
```

```bash
# Load .env file and generate
sskeys generate --env-file .env.local

# Validate with .env file
sskeys validate --env-file .env.local
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

## 🚨 Error Messages

SwiftSecretKeys provides actionable error messages for common issues:

| Situation | Error Message |
|-----------|--------------|
| Config file not found | `Configuration file not found at 'path'. Create sskeys.yml or use --config to specify a path.` |
| Invalid YAML | `Invalid configuration: <reason>` |
| No keys defined | `Configuration must contain a 'keys' or 'environments' dictionary with at least one entry.` |
| Missing env var | `Environment variable 'NAME' is not set.` |
| Bad output dir | `Output directory not found at 'path'.` |
| Invalid cipher | `Unknown cipher 'value'. Supported values: 'xor', 'aes-gcm', 'chacha20'.` |
| Key name collision | `Key names ['a', 'b'] all sanitize to 'x'. Rename one to avoid collision.` |
| .env file not found | `Environment file not found at 'path'.` |
| Environment not found | `Environment 'name' not found. Available environments: dev, staging, prod.` |
| Environment required | `This config uses 'environments:' block. Specify an environment with --environment <name>.` |

---

## 📚 Other Libraries

Other obfuscation and security tools in the Swift ecosystem:

- [Arkana](https://github.com/rogerluan/arkana) — Secret keys management with code generation
- [SwiftShield](https://github.com/rockbruno/swiftshield) — Symbol obfuscation for compiled binaries
- [cocoapods-keys](https://github.com/orta/cocoapods-keys) — CocoaPods plugin for key management (CocoaPods-based)

---

## 🤝 Contributing

Contributions are welcome — whether it's a bug report, feature idea, or pull request. If you have something in mind, please open an issue first to discuss the approach. We'd love to hear from you!

```bash
git clone https://github.com/MatheusMBispo/SwiftSecretKeys.git
cd SwiftSecretKeys
swift build
swift test
```

The project uses swift-tools-version 6.2 with Swift 6 strict concurrency. All 48 tests must pass on both macOS and Linux. Tests use the Swift Testing framework (`@Test`).

---

## 📄 License

SwiftSecretKeys is available under the MIT License. See the [LICENSE](LICENSE) file for details.
