import Foundation

/// Sanitizes raw YAML key names into valid Swift identifiers.
public enum Sanitizer {

    // Swift reserved keywords that must be backtick-escaped when used as identifiers.
    private static let swiftKeywords: Set<String> = [
        "associatedtype", "class", "deinit", "enum", "extension",
        "fileprivate", "func", "import", "init", "inout",
        "internal", "let", "open", "operator", "private",
        "precedencegroup", "protocol", "public", "rethrows", "static",
        "struct", "subscript", "typealias", "var",
        "break", "case", "catch", "continue", "default",
        "defer", "do", "else", "fallthrough", "for",
        "guard", "if", "in", "repeat", "return",
        "switch", "throw", "try", "where", "while",
        "as", "Any", "false", "is", "nil",
        "self", "Self", "super", "throws", "true",
    ]

    /// Sanitizes an array of raw key names into valid Swift identifiers.
    ///
    /// Returns a dictionary mapping each original name to its sanitized form.
    /// Throws `SSKeysError.invalidKeyName` if a name cannot be made into any
    /// valid identifier, or `SSKeysError.keyNameCollision` if two different
    /// originals map to the same sanitized name.
    public static func sanitize(keyNames: [String]) throws -> [String: String] {
        var result = [String: String]()

        for original in keyNames {
            let sanitized = try sanitizeOne(original)
            result[original] = sanitized
        }

        // Collision detection: two distinct originals -> same sanitized name
        var seen = [String: String]()  // sanitized -> first original
        for (original, sanitized) in result {
            if let firstOriginal = seen[sanitized], firstOriginal != original {
                // Collect all names that collide on this sanitized form
                let colliders = result.filter { $0.value == sanitized }.map(\.key).sorted()
                throw SSKeysError.keyNameCollision(names: colliders, sanitized: sanitized)
            }
            seen[sanitized] = original
        }

        return result
    }

    // MARK: - Private

    private static func sanitizeOne(_ original: String) throws -> String {
        // Pass 1: Replace non-[A-Za-z0-9_] characters with underscore
        var sanitized = original.unicodeScalars.map { scalar in
            let c = scalar.value
            let isAlpha = (c >= 65 && c <= 90) || (c >= 97 && c <= 122)  // A-Z, a-z
            let isDigit = c >= 48 && c <= 57                               // 0-9
            let isUnderscore = c == 95                                     // _
            return (isAlpha || isDigit || isUnderscore) ? String(scalar) : "_"
        }.joined()

        // Collapse consecutive underscores to a single underscore
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }

        // Trim leading and trailing underscores
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        // Pass 2: Head validation — if starts with a digit, prepend key_
        if let first = sanitized.first, first.isNumber {
            sanitized = "key_" + sanitized
        }

        // If empty after cleanup, the name is unsalvageable
        if sanitized.isEmpty {
            throw SSKeysError.invalidKeyName(original: original)
        }

        // Pass 3: Reserved word escaping
        if swiftKeywords.contains(sanitized) {
            sanitized = "`\(sanitized)`"
        }

        return sanitized
    }
}
