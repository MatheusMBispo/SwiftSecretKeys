import Foundation
import SwiftSecretKeysCore

enum DotEnvLoader {
    static func load(from path: String) throws {
        let contents: String
        do {
            contents = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw SSKeysError.dotEnvFileNotFound(path: path)
        }

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            guard trimmed.contains("=") else { continue }

            let separatorRange = trimmed.range(of: "=")!
            let key = String(trimmed[trimmed.startIndex..<separatorRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[separatorRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)

            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }

            guard !key.isEmpty else { continue }
            setenv(key, value, 1)
        }
    }
}
