import Foundation
import Yams

public enum CipherMode: String, Sendable {
    case xor = "xor"
    case aesgcm = "aes-gcm"
    case chacha20 = "chacha20"
}

public struct Config: Sendable {
    public let keys: [String: String]
    public let output: String
    public let cipher: CipherMode

    public static func load(from yamlString: String, environment: String? = nil) throws -> Config {
        // Decode raw YAML with typed Codable struct
        let raw: RawConfig
        do {
            raw = try YAMLDecoder().decode(RawConfig.self, from: yamlString)
        } catch let error as DecodingError {
            let reason = humanReadableReason(from: error)
            throw SSKeysError.invalidConfig(reason: reason)
        } catch {
            throw SSKeysError.invalidConfig(reason: error.localizedDescription)
        }

        let hasEnvironments = !(raw.environments ?? [:]).isEmpty
        let hasFlatKeys = !(raw.keys ?? [:]).isEmpty

        // Mutual exclusivity: cannot use both keys: and environments: in the same config
        if hasEnvironments && hasFlatKeys {
            throw SSKeysError.invalidConfig(reason: "Cannot use both 'keys' and 'environments' in the same config.")
        }

        let activeKeys: [String: String]

        if hasEnvironments {
            let envMap = raw.environments!

            // Cross-environment sanitization: eagerly validate ALL environments
            for (envName, envKeys) in envMap {
                do {
                    _ = try Sanitizer.sanitize(keyNames: Array(envKeys.keys))
                } catch let ssError as SSKeysError {
                    throw SSKeysError.invalidConfig(reason: "Environment '\(envName)': \(ssError.errorDescription ?? ssError.localizedDescription)")
                }
            }

            // Environment selection is required when environments: block is present
            guard let envName = environment else {
                throw SSKeysError.environmentRequired
            }

            let availableNames = envMap.keys.sorted()
            guard let envKeys = envMap[envName] else {
                throw SSKeysError.environmentNotFound(name: envName, available: availableNames)
            }

            activeKeys = envKeys
        } else if hasFlatKeys {
            // Flat keys: mode — silently ignore environment param if provided (prevents CI breakage)
            activeKeys = raw.keys!
        } else {
            throw SSKeysError.missingKeys
        }

        guard !activeKeys.isEmpty else {
            throw SSKeysError.missingKeys
        }

        // Parse cipher mode — raw String decode allows actionable error message with invalid value
        let cipherMode: CipherMode
        if let rawCipher = raw.cipher {
            guard let parsed = CipherMode(rawValue: rawCipher) else {
                throw SSKeysError.invalidCipher(value: rawCipher)
            }
            cipherMode = parsed
        } else {
            cipherMode = .xor
        }

        // Resolve environment variables — pattern is function-local for Swift 6 strict concurrency compliance
        let envVarPattern = /\$\{(\w+)\}/
        var resolvedKeys = [String: String]()
        for (key, value) in activeKeys {
            if value.contains(envVarPattern) {
                var resolved = value
                for match in value.matches(of: envVarPattern) {
                    let varName = String(match.output.1)
                    guard let envValue = ProcessInfo.processInfo.environment[varName] else {
                        throw SSKeysError.environmentVariableNotFound(name: varName)
                    }
                    resolved = resolved.replacingOccurrences(of: String(match.output.0), with: envValue)
                }
                resolvedKeys[key] = resolved
            } else {
                resolvedKeys[key] = value
            }
        }

        return Config(keys: resolvedKeys, output: raw.output ?? "", cipher: cipherMode)
    }

    /// Returns the list of environment names declared in a YAML config, or an empty array
    /// if the config uses flat `keys:` layout. Used by ValidateCommand for all-environments fallback.
    public static func environmentNames(from yamlString: String) throws -> [String] {
        struct EnvProbe: Decodable {
            let environments: [String: [String: String]]?
        }
        do {
            let probe = try YAMLDecoder().decode(EnvProbe.self, from: yamlString)
            return (probe.environments ?? [:]).keys.sorted()
        } catch let error as DecodingError {
            let reason = humanReadableReason(from: error)
            throw SSKeysError.invalidConfig(reason: reason)
        } catch {
            throw SSKeysError.invalidConfig(reason: error.localizedDescription)
        }
    }

    // MARK: - Private

    private init(keys: [String: String], output: String, cipher: CipherMode) {
        self.keys = keys
        self.output = output
        self.cipher = cipher
    }

    private struct RawConfig: Decodable {
        let keys: [String: String]?
        let environments: [String: [String: String]]?
        let output: String?
        let cipher: String?
    }

    private static func humanReadableReason(from error: DecodingError) -> String {
        switch error {
        case let .typeMismatch(_, context):
            return "Type mismatch at '\(context.codingPath.map(\.stringValue).joined(separator: "."))': \(context.debugDescription)"
        case let .keyNotFound(key, _):
            return "Missing required field '\(key.stringValue)'. Ensure your config has a 'keys' or 'environments' dictionary."
        case let .valueNotFound(_, context):
            return "Missing value at '\(context.codingPath.map(\.stringValue).joined(separator: "."))': \(context.debugDescription)"
        case let .dataCorrupted(context):
            return "Invalid YAML structure: \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }
}
