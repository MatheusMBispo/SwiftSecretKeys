import Crypto
import Testing
import Foundation
@testable import SwiftSecretKeysCore

// Generator tests must run serially because generate() reads FileManager.default.currentDirectoryPath,
// which is process-wide state. Serial execution prevents CWD race conditions across tests.
@Suite("Generator", .serialized)
struct GeneratorTests {

    // MARK: - Helpers

    private func makeConfig(yaml: String) throws -> Config {
        try Config.load(from: yaml)
    }

    /// Runs body inside a unique temp directory set as the process CWD.
    /// Restores original CWD after body completes (or throws).
    private func withTempCWD<T>(_ body: (URL) throws -> T) throws -> T {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let originalCWD = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(tempDir.path)
        defer {
            FileManager.default.changeCurrentDirectoryPath(originalCWD)
            try? FileManager.default.removeItem(at: tempDir)
        }
        return try body(tempDir)
    }

    // MARK: - Tests

    @Test("generatesValidSwiftFile: generated file has correct structure")
    func generatesValidSwiftFile() throws {
        try withTempCWD { tempDir in
            let yaml = """
            keys:
              apiKey: my-api-key-value
              dbPassword: super-secret
            """
            let config = try makeConfig(yaml: yaml)
            let generator = Generator(config: config)
            try generator.generate()

            let fileURL = tempDir.appendingPathComponent("SecretKeys.swift")
            let content = try String(contentsOf: fileURL, encoding: .utf8)

            #expect(content.contains("enum SecretKeys"))
            #expect(content.contains("private static let salt: [UInt8]"))
            #expect(content.contains("private static func decode"))
            #expect(content.contains("import Foundation"))
            #expect(content.contains("static var apiKey"))
            #expect(content.contains("static var dbPassword"))
            #expect(content.contains("SECURITY NOTICE"))
            #expect(content.contains("OWASP"))
        }
    }

    @Test("generatedFileContainsAllExpectedKeys: all input keys appear as vars")
    func generatedFileContainsAllExpectedKeys() throws {
        try withTempCWD { tempDir in
            let yaml = """
            keys:
              alpha: value1
              beta: value2
              gamma: value3
            """
            let config = try makeConfig(yaml: yaml)
            let generator = Generator(config: config)
            try generator.generate()

            let fileURL = tempDir.appendingPathComponent("SecretKeys.swift")
            let content = try String(contentsOf: fileURL, encoding: .utf8)

            #expect(content.contains("static var alpha"))
            #expect(content.contains("static var beta"))
            #expect(content.contains("static var gamma"))
        }
    }

    @Test("generatedValuesDecodeCorrectly: XOR encode/decode round-trip recovers original value")
    func generatedValuesDecodeCorrectly() throws {
        try withTempCWD { tempDir in
            let originalValue = "hello"
            let yaml = """
            keys:
              testKey: \(originalValue)
            """
            let config = try makeConfig(yaml: yaml)
            let generator = Generator(config: config)
            try generator.generate()

            let fileURL = tempDir.appendingPathComponent("SecretKeys.swift")
            let content = try String(contentsOf: fileURL, encoding: .utf8)

            // Extract salt bytes from within the salt array literal
            let saltBytes = extractFirstByteArray(from: content, between: "let salt: [UInt8] = [", and: "    ]")
            #expect(saltBytes.count > 0, "Salt bytes should not be empty")

            // Extract encoded bytes for testKey — find its specific array literal
            guard let keyVarRange = content.range(of: "static var testKey: String {") else {
                Issue.record("testKey not found in generated output")
                return
            }
            let afterKeyVar = String(content[keyVarRange.upperBound...])
            let encodedBytes = extractFirstByteArray(from: afterKeyVar, between: "let encoded: [UInt8] = [", and: "        ]")
            #expect(encodedBytes.count > 0, "Encoded bytes should not be empty")
            #expect(encodedBytes.count == originalValue.utf8.count)

            // XOR decode with salt to recover original value
            let decoded = encodedBytes.enumerated().map { offset, byte -> UInt8 in
                byte ^ saltBytes[offset % saltBytes.count]
            }
            let decodedString = String(bytes: decoded, encoding: .utf8)
            #expect(decodedString == originalValue)
        }
    }

    @Test("outputSortedAlphabetically: keys are sorted alphabetically in output")
    func outputSortedAlphabetically() throws {
        try withTempCWD { tempDir in
            let yaml = """
            keys:
              z_key: val
              a_key: val
              m_key: val
            """
            let config = try makeConfig(yaml: yaml)
            let generator = Generator(config: config)
            try generator.generate()

            let fileURL = tempDir.appendingPathComponent("SecretKeys.swift")
            let content = try String(contentsOf: fileURL, encoding: .utf8)

            let aRange = content.range(of: "static var a_key")
            let mRange = content.range(of: "static var m_key")
            let zRange = content.range(of: "static var z_key")

            #expect(aRange != nil, "a_key should be present")
            #expect(mRange != nil, "m_key should be present")
            #expect(zRange != nil, "z_key should be present")

            if let a = aRange, let m = mRange, let z = zRange {
                #expect(a.lowerBound < m.lowerBound, "a_key should appear before m_key")
                #expect(m.lowerBound < z.lowerBound, "m_key should appear before z_key")
            }
        }
    }

    @Test("outputDirectoryOverride: generate(outputDirectory:) writes to specified path ignoring config.output")
    func outputDirectoryOverride() throws {
        try withTempCWD { _ in
            let overrideDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: overrideDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: overrideDir) }

            let yaml = """
            keys:
              apiKey: override-test-value
            output: some-other-dir
            """
            let config = try makeConfig(yaml: yaml)
            let generator = Generator(config: config)
            try generator.generate(outputDirectory: overrideDir.path)

            let fileURL = overrideDir.appendingPathComponent("SecretKeys.swift")
            #expect(FileManager.default.fileExists(atPath: fileURL.path), "SecretKeys.swift should exist at override directory")
        }
    }

    @Test("throwsOnMissingOutputDirectory: nonexistent output dir throws outputDirectoryNotFound")
    func throwsOnMissingOutputDirectory() throws {
        let nonexistentRelativePath = "nonexistent_dir_\(UUID().uuidString)"
        let yaml = """
        keys:
          apiKey: value
        output: \(nonexistentRelativePath)
        """
        let config = try makeConfig(yaml: yaml)
        let generator = Generator(config: config)
        #expect(throws: (any Error).self) {
            try generator.generate()
        }
    }

    // MARK: - AES-GCM tests

    @Test("aesGCMGeneratesValidStructure: generated file has AES-GCM structure and not XOR artifacts")
    func aesGCMGeneratesValidStructure() throws {
        try withTempCWD { tempDir in
            let yaml = """
            cipher: aes-gcm
            keys:
              apiKey: test-value
              dbPass: secret
            """
            let config = try makeConfig(yaml: yaml)
            let generator = Generator(config: config)
            try generator.generate()

            let fileURL = tempDir.appendingPathComponent("SecretKeys.swift")
            let content = try String(contentsOf: fileURL, encoding: .utf8)

            #expect(content.contains("import Foundation"))
            #expect(content.contains("#if canImport(CryptoKit)"))
            #expect(content.contains("import CryptoKit"))
            #expect(content.contains("import Crypto"))
            #expect(content.contains("enum SecretKeys"))
            #expect(content.contains("private static let aesKey: [UInt8]"))
            #expect(content.contains("static var apiKey"))
            #expect(content.contains("static var dbPass"))
            #expect(content.contains("_decryptAESGCM"))
            #expect(content.contains("AES.GCM.SealedBox"))
            #expect(content.contains("AES.GCM.open"))
            #expect(content.contains("SECURITY NOTICE"))
            #expect(content.contains("OWASP"))
            // Must NOT contain XOR-only artifacts
            #expect(!content.contains("let salt:"))
            #expect(!content.contains("func decode"))
        }
    }

    @Test("aesGCMRoundTripDecryption: extracted key and combined bytes decrypt to original plaintext")
    func aesGCMRoundTripDecryption() throws {
        try withTempCWD { tempDir in
            let originalValue = "hello-world-secret"
            let yaml = """
            cipher: aes-gcm
            keys:
              testKey: \(originalValue)
            """
            let config = try makeConfig(yaml: yaml)
            let generator = Generator(config: config)
            try generator.generate()

            let fileURL = tempDir.appendingPathComponent("SecretKeys.swift")
            let content = try String(contentsOf: fileURL, encoding: .utf8)

            // Extract aesKey bytes
            let keyBytes = extractFirstByteArray(from: content, between: "let aesKey: [UInt8] = [", and: "    ]")
            #expect(keyBytes.count == 32, "AES-256 key must be 32 bytes")

            // Extract combined bytes for testKey
            guard let keyVarRange = content.range(of: "static var testKey: String {") else {
                Issue.record("testKey not found in generated output")
                return
            }
            let afterKeyVar = String(content[keyVarRange.upperBound...])
            let combinedBytes = extractFirstByteArray(from: afterKeyVar, between: "let combined: [UInt8] = [", and: "        ]")
            // combined = nonce(12) + ciphertext + tag(16), so minimum is 12 + 0 + 16 = 28
            #expect(combinedBytes.count >= 28, "Combined must have at least nonce + tag bytes")

            // Perform the same decryption the generated code would do
            let key = SymmetricKey(data: Data(keyBytes))
            let sealedBox = try AES.GCM.SealedBox(combined: Data(combinedBytes))
            let plaintext = try AES.GCM.open(sealedBox, using: key)
            let decoded = String(decoding: plaintext, as: UTF8.self)
            #expect(decoded == originalValue)
        }
    }

    @Test("aesGCMNonceFreshness: two generates produce different combined bytes (CRYP-03)")
    func aesGCMNonceFreshness() throws {
        try withTempCWD { tempDir in
            let yaml = """
            cipher: aes-gcm
            keys:
              mySecret: same-value-every-time
            """
            let config = try makeConfig(yaml: yaml)
            let generator = Generator(config: config)

            // First generate
            try generator.generate()
            let fileURL = tempDir.appendingPathComponent("SecretKeys.swift")
            let firstContent = try String(contentsOf: fileURL, encoding: .utf8)

            // Second generate — overwrites the file
            try generator.generate()
            let secondContent = try String(contentsOf: fileURL, encoding: .utf8)

            // Extract combined bytes from each generate
            guard let firstVarRange = firstContent.range(of: "static var mySecret: String {") else {
                Issue.record("mySecret not found in first generated output")
                return
            }
            let afterFirst = String(firstContent[firstVarRange.upperBound...])
            let firstCombined = extractFirstByteArray(from: afterFirst, between: "let combined: [UInt8] = [", and: "        ]")

            guard let secondVarRange = secondContent.range(of: "static var mySecret: String {") else {
                Issue.record("mySecret not found in second generated output")
                return
            }
            let afterSecond = String(secondContent[secondVarRange.upperBound...])
            let secondCombined = extractFirstByteArray(from: afterSecond, between: "let combined: [UInt8] = [", and: "        ]")

            #expect(firstCombined.count >= 28, "First combined must have at least nonce + tag bytes")
            #expect(secondCombined.count >= 28, "Second combined must have at least nonce + tag bytes")

            // Fresh nonce per build means different ciphertext even with identical plaintext
            #expect(firstCombined != secondCombined, "Two generates must produce different combined bytes (CRYP-03: fresh nonce per build)")
        }
    }

    @Test("xorModeUnchanged: cipher: xor output has no AES-GCM artifacts (regression guard)")
    func xorModeUnchanged() throws {
        try withTempCWD { tempDir in
            let yaml = """
            cipher: xor
            keys:
              myKey: some-value
            """
            let config = try makeConfig(yaml: yaml)
            let generator = Generator(config: config)
            try generator.generate()

            let fileURL = tempDir.appendingPathComponent("SecretKeys.swift")
            let content = try String(contentsOf: fileURL, encoding: .utf8)

            #expect(content.contains("let salt:"))
            #expect(content.contains("func decode"))
            #expect(content.contains("import Foundation"))
            // Must NOT contain AES-GCM artifacts
            #expect(!content.contains("aesKey"))
            #expect(!content.contains("_decryptAESGCM"))
            #expect(!content.contains("CryptoKit"))
            #expect(!content.contains("AES.GCM"))
            // Must NOT contain ChaCha20 artifacts
            #expect(!content.contains("chachaKey"))
            #expect(!content.contains("_decryptChaCha20"))
            #expect(!content.contains("ChaChaPoly"))
        }
    }

    // MARK: - ChaCha20 tests

    @Test("chacha20GeneratesValidStructure: generated file has ChaCha20 structure and not XOR/AES-GCM artifacts")
    func chacha20GeneratesValidStructure() throws {
        try withTempCWD { tempDir in
            let yaml = """
            cipher: chacha20
            keys:
              apiKey: test-value
              dbPass: secret
            """
            let config = try makeConfig(yaml: yaml)
            let generator = Generator(config: config)
            try generator.generate()

            let fileURL = tempDir.appendingPathComponent("SecretKeys.swift")
            let content = try String(contentsOf: fileURL, encoding: .utf8)

            #expect(content.contains("import Foundation"))
            #expect(content.contains("#if canImport(CryptoKit)"))
            #expect(content.contains("import CryptoKit"))
            #expect(content.contains("import Crypto"))
            #expect(content.contains("enum SecretKeys"))
            #expect(content.contains("private static let chachaKey: [UInt8]"))
            #expect(content.contains("static var apiKey"))
            #expect(content.contains("static var dbPass"))
            #expect(content.contains("_decryptChaCha20"))
            #expect(content.contains("ChaChaPoly.SealedBox"))
            #expect(content.contains("ChaChaPoly.open"))
            #expect(content.contains("SECURITY NOTICE"))
            #expect(content.contains("OWASP"))
            // Must NOT contain XOR-only artifacts
            #expect(!content.contains("let salt:"))
            #expect(!content.contains("func decode"))
            // Must NOT contain AES-GCM artifacts
            #expect(!content.contains("aesKey"))
            #expect(!content.contains("_decryptAESGCM"))
            #expect(!content.contains("AES.GCM"))
        }
    }

    @Test("chacha20RoundTripDecryption: extracted key and combined bytes decrypt to original plaintext")
    func chacha20RoundTripDecryption() throws {
        try withTempCWD { tempDir in
            let originalValue = "hello-world-secret"
            let yaml = """
            cipher: chacha20
            keys:
              testKey: \(originalValue)
            """
            let config = try makeConfig(yaml: yaml)
            let generator = Generator(config: config)
            try generator.generate()

            let fileURL = tempDir.appendingPathComponent("SecretKeys.swift")
            let content = try String(contentsOf: fileURL, encoding: .utf8)

            // Extract chachaKey bytes
            let keyBytes = extractFirstByteArray(from: content, between: "let chachaKey: [UInt8] = [", and: "    ]")
            #expect(keyBytes.count == 32, "ChaCha20 key must be 32 bytes")

            // Extract combined bytes for testKey
            guard let keyVarRange = content.range(of: "static var testKey: String {") else {
                Issue.record("testKey not found in generated output")
                return
            }
            let afterKeyVar = String(content[keyVarRange.upperBound...])
            let combinedBytes = extractFirstByteArray(from: afterKeyVar, between: "let combined: [UInt8] = [", and: "        ]")
            // combined = nonce(12) + ciphertext + tag(16), so minimum is 12 + 0 + 16 = 28
            #expect(combinedBytes.count >= 28, "Combined must have at least nonce + tag bytes")

            // Perform the same decryption the generated code would do
            let key = SymmetricKey(data: Data(keyBytes))
            let sealedBox = try ChaChaPoly.SealedBox(combined: Data(combinedBytes))
            let plaintext = try ChaChaPoly.open(sealedBox, using: key)
            let decoded = String(decoding: plaintext, as: UTF8.self)
            #expect(decoded == originalValue)
        }
    }

    @Test("xorModeNoChaCha20Artifacts: cipher: xor output has no ChaCha20 artifacts (regression guard)")
    func xorModeNoChaCha20Artifacts() throws {
        try withTempCWD { tempDir in
            let yaml = """
            cipher: xor
            keys:
              myKey: some-value
            """
            let config = try makeConfig(yaml: yaml)
            let generator = Generator(config: config)
            try generator.generate()

            let fileURL = tempDir.appendingPathComponent("SecretKeys.swift")
            let content = try String(contentsOf: fileURL, encoding: .utf8)

            #expect(!content.contains("chachaKey"))
            #expect(!content.contains("_decryptChaCha20"))
            #expect(!content.contains("ChaChaPoly"))
        }
    }

    // MARK: - DIST-01 integration test

    @Test("absoluteConfigPathIntegration: loading config from absolute path and generating works (DIST-01)")
    func absoluteConfigPathIntegration() throws {
        try withTempCWD { tempDir in
            // Create config in a separate temp location (simulates plugin passing absolute target.directoryURL)
            let configDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: configDir) }

            let configFile = configDir.appendingPathComponent("sskeys.yml")
            let yaml = """
            keys:
              pluginTestKey: absolute-path-value
            """
            try yaml.write(to: configFile, atomically: true, encoding: .utf8)

            // Load config from absolute path (this is what GenerateCommand does after the fix)
            let absolutePath = configFile.path
            let contents = try String(contentsOfFile: absolutePath, encoding: .utf8)
            let config = try Config.load(from: contents)

            // Generate into a different temp directory (simulates pluginWorkDirectory)
            let outputDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: outputDir) }

            let generator = Generator(config: config)
            try generator.generate(outputDirectory: outputDir.path)

            let outputFile = outputDir.appendingPathComponent("SecretKeys.swift")
            #expect(FileManager.default.fileExists(atPath: outputFile.path),
                    "SecretKeys.swift should exist at output directory when config loaded from absolute path")

            let content = try String(contentsOf: outputFile, encoding: .utf8)
            #expect(content.contains("static var pluginTestKey"))
        }
    }

    // MARK: - Error description tests

    @Test("errorDescriptionsAreActionable: SSKeysError errorDescription returns useful messages")
    func errorDescriptionsAreActionable() throws {
        let errors: [(SSKeysError, String)] = [
            (.configFileNotFound(path: "/some/path"), "not found"),
            (.invalidConfig(reason: "bad yaml"), "Invalid configuration"),
            (.missingKeys, "keys"),
            (.environmentVariableNotFound(name: "MY_VAR"), "MY_VAR"),
            (.outputDirectoryNotFound(path: "/missing/dir"), "not found"),
            (.invalidKeyName(original: "123bad"), "123bad"),
            (.keyNameCollision(names: ["a", "b"], sanitized: "c"), "collision"),
            (.invalidCipher(value: "rot13"), "rot13"),
            (.encryptionFailed(reason: "bad data"), "bad data"),
        ]
        for (error, expectedSubstring) in errors {
            let description = error.errorDescription
            #expect(description != nil, "errorDescription should not be nil for \(error)")
            #expect(description?.contains(expectedSubstring) == true,
                    "errorDescription for \(error) should contain '\(expectedSubstring)'")
        }
    }

    @Test("aesGCMTemplateUsesPreconditionFailure: generated _decryptAESGCM uses preconditionFailure not silent return")
    func aesGCMTemplateUsesPreconditionFailure() throws {
        try withTempCWD { tempDir in
            let yaml = """
            cipher: aes-gcm
            keys:
              testKey: some-value
            """
            let config = try makeConfig(yaml: yaml)
            let generator = Generator(config: config)
            try generator.generate()

            let fileURL = tempDir.appendingPathComponent("SecretKeys.swift")
            let content = try String(contentsOf: fileURL, encoding: .utf8)

            // Must contain preconditionFailure for descriptive crash
            #expect(content.contains("preconditionFailure"))
            // Must NOT contain silent return ""
            #expect(!content.contains("return \"\""))
        }
    }

    // MARK: - Byte extraction helpers

    /// Extracts contiguous byte values from the first '[...contents...]' found between two markers.
    private func extractFirstByteArray(from content: String, between start: String, and end: String) -> [UInt8] {
        guard let startRange = content.range(of: start) else { return [] }
        let afterStart = String(content[startRange.upperBound...])
        guard let endRange = afterStart.range(of: "]") else { return [] }
        let arraySection = String(afterStart[..<endRange.lowerBound])

        return arraySection
            .components(separatedBy: CharacterSet(charactersIn: ",\n "))
            .compactMap { UInt8($0.trimmingCharacters(in: .whitespaces)) }
    }
}
