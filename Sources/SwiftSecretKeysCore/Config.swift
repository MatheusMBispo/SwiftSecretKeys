import Foundation
import Yams

public enum CipherMode: String, Sendable {
    case xor = "xor"
    case aesgcm = "aes-gcm"
}

public struct Config: Sendable {
    public let keys: [String: String]
    public let output: String
    public let cipher: CipherMode

    public static func load(from yamlString: String) throws -> Config {
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

        guard !raw.keys.isEmpty else {
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
        for (key, value) in raw.keys {
            if value.contains(envVarPattern) {
                guard let match = value.firstMatch(of: envVarPattern) else {
                    throw SSKeysError.invalidConfig(reason: "Malformed environment variable reference in value for key '\(key)'.")
                }
                let varName = String(match.output.1)
                guard let envValue = ProcessInfo.processInfo.environment[varName] else {
                    throw SSKeysError.environmentVariableNotFound(name: varName)
                }
                resolvedKeys[key] = envValue
            } else {
                resolvedKeys[key] = value
            }
        }

        return Config(keys: resolvedKeys, output: raw.output ?? "", cipher: cipherMode)
    }

    // MARK: - Private

    private init(keys: [String: String], output: String, cipher: CipherMode) {
        self.keys = keys
        self.output = output
        self.cipher = cipher
    }

    private struct RawConfig: Decodable {
        let keys: [String: String]
        let output: String?
        let cipher: String?
    }

    private static func humanReadableReason(from error: DecodingError) -> String {
        switch error {
        case let .typeMismatch(_, context):
            return "Type mismatch at '\(context.codingPath.map(\.stringValue).joined(separator: "."))': \(context.debugDescription)"
        case let .keyNotFound(key, _):
            return "Missing required field '\(key.stringValue)'. Ensure your config has a 'keys' dictionary."
        case let .valueNotFound(_, context):
            return "Missing value at '\(context.codingPath.map(\.stringValue).joined(separator: "."))': \(context.debugDescription)"
        case let .dataCorrupted(context):
            return "Invalid YAML structure: \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }
}
