import Foundation

public enum DotEnvLoader {
    public static func load(from path: String) throws {
        let contents: String
        do {
            contents = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw SSKeysError.dotEnvFileNotFound(path: path)
        }

        for (key, value) in parse(contents) {
            setenv(key, value, 1)
        }
    }

    static func parse(_ contents: String) -> [(key: String, value: String)] {
        var result: [(key: String, value: String)] = []

        for line in contents.components(separatedBy: .newlines) {
            var trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            if trimmed.hasPrefix("export ") {
                trimmed = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            }

            guard trimmed.contains("=") else { continue }

            let separatorRange = trimmed.range(of: "=")!
            let key = String(trimmed[trimmed.startIndex..<separatorRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[separatorRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)

            if value.hasPrefix("\"") {
                let inner = value.dropFirst()
                if let closeIdx = inner.firstIndex(of: "\"") {
                    value = String(inner[inner.startIndex..<closeIdx])
                }
            } else if value.hasPrefix("'") {
                let inner = value.dropFirst()
                if let closeIdx = inner.firstIndex(of: "'") {
                    value = String(inner[inner.startIndex..<closeIdx])
                }
            } else if let commentRange = value.range(of: " #") {
                value = String(value[value.startIndex..<commentRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
            }

            guard !key.isEmpty else { continue }
            result.append((key: key, value: value))
        }

        return result
    }
}
