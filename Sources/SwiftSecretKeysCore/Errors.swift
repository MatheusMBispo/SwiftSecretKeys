import Foundation

public enum SSKeysError: LocalizedError, Equatable {
    case configFileNotFound(path: String)
    case invalidConfig(reason: String)
    case missingKeys
    case environmentVariableNotFound(name: String)
    case outputDirectoryNotFound(path: String)
    case invalidKeyName(original: String)
    case keyNameCollision(names: [String], sanitized: String)
    case invalidCipher(value: String)

    public var errorDescription: String? {
        switch self {
        case let .configFileNotFound(path):
            return "Configuration file not found at '\(path)'. Create sskeys.yml or use --config to specify a path."
        case let .invalidConfig(reason):
            return "Invalid configuration: \(reason)"
        case .missingKeys:
            return "Configuration must contain a 'keys' dictionary with at least one entry."
        case let .environmentVariableNotFound(name):
            return "Environment variable '\(name)' is not set."
        case let .outputDirectoryNotFound(path):
            return "Output directory not found at '\(path)'."
        case let .invalidKeyName(original):
            return "Key name '\(original)' cannot be converted to a valid Swift identifier."
        case let .keyNameCollision(names, sanitized):
            return "Key names \(names) all sanitize to '\(sanitized)'. Rename one to avoid collision."
        case let .invalidCipher(value):
            return "Unknown cipher '\(value)'. Supported values: 'xor', 'aes-gcm'."
        }
    }
}
