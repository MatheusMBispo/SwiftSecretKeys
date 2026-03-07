import Crypto
import Foundation

public struct Generator {
    public let config: Config
    public let saltLength: Int

    private struct KeyConfig {
        let name: String
        let value: [[UInt8]]
    }

    private struct AESKeyConfig {
        let name: String
        let combined: [UInt8]  // nonce(12) || ciphertext(n) || tag(16)
    }

    public init(config: Config, saltLength: Int = 32) {
        self.config = config
        self.saltLength = saltLength
    }

    public func generate(outputDirectory: String? = nil) throws {
        let nameMap = try Sanitizer.sanitize(keyNames: Array(config.keys.keys))

        let rendered: String

        switch config.cipher {
        case .xor:
            let cipher = generateSaltBytes(count: saltLength)
            let saltChunks = chunked(array: cipher, into: 10)

            var keyConfigs = [KeyConfig]()
            for (key, value) in config.keys {
                let sanitizedName = nameMap[key]!
                let encodedVar = encode(value, cipher: cipher)
                keyConfigs.append(KeyConfig(name: sanitizedName, value: chunked(array: encodedVar, into: 10)))
            }
            // Sort by sanitized name for deterministic output
            keyConfigs.sort { $0.name < $1.name }

            rendered = renderOutput(saltChunks: saltChunks, keyConfigs: keyConfigs)

        case .aesgcm:
            let aesKey = SymmetricKey(size: .bits256)  // Fresh 32-byte key per build
            let keyBytes: [UInt8] = aesKey.withUnsafeBytes { Array($0) }

            var aesKeyConfigs = [AESKeyConfig]()
            for (key, value) in config.keys {
                let sanitizedName = nameMap[key]!
                let combined = try encryptAESGCM(value, using: aesKey)
                aesKeyConfigs.append(AESKeyConfig(name: sanitizedName, combined: combined))
            }
            aesKeyConfigs.sort { $0.name < $1.name }

            rendered = renderAESGCMOutput(keyBytes: keyBytes, keyConfigs: aesKeyConfigs)
        }

        let outputURL: URL
        if let overrideDir = outputDirectory {
            // Caller-provided absolute path — do not prepend cwd
            outputURL = URL(fileURLWithPath: overrideDir)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: overrideDir, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                throw SSKeysError.outputDirectoryNotFound(path: overrideDir)
            }
        } else {
            let cwd = FileManager.default.currentDirectoryPath
            outputURL = URL(fileURLWithPath: cwd)
                .appendingPathComponent(config.output)
            if !config.output.isEmpty {
                var isDirectory: ObjCBool = false
                let dirPath = outputURL.path
                guard FileManager.default.fileExists(atPath: dirPath, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    throw SSKeysError.outputDirectoryNotFound(path: dirPath)
                }
            }
        }

        let fileURL = outputURL.appendingPathComponent("SecretKeys.swift")
        try rendered.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Private helpers

    private func generateSaltBytes(count: Int) -> [UInt8] {
        var rng = SystemRandomNumberGenerator()
        return (0..<count).map { _ in UInt8.random(in: 0...255, using: &rng) }
    }

    private func chunked(array: [UInt8], into size: Int) -> [[UInt8]] {
        stride(from: 0, to: array.count, by: size).map {
            Array(array[$0 ..< Swift.min($0 + size, array.count)])
        }
    }

    private func encode(_ str: String, cipher: [UInt8]) -> [UInt8] {
        Array(str.utf8).enumerated().map { offset, element in
            element ^ cipher[offset % cipher.count]
        }
    }

    private func encryptAESGCM(_ value: String, using key: SymmetricKey) throws -> [UInt8] {
        let nonce = AES.GCM.Nonce()  // Fresh 12-byte random nonce per value
        let sealedBox = try AES.GCM.seal(Data(value.utf8), using: key, nonce: nonce)
        // combined is non-nil because default nonce is always 12 bytes
        return Array(sealedBox.combined!)
    }

    private func renderOutput(saltChunks: [[UInt8]], keyConfigs: [KeyConfig]) -> String {
        let saltLines = saltChunks
            .map { chunk in
                "        " + chunk.map { String($0) }.joined(separator: ", ")
            }
            .joined(separator: ",\n")

        let varBlocks = keyConfigs.map { keyConfig in
            let encodedLines = keyConfig.value
                .map { chunk in
                    "            " + chunk.map { String($0) }.joined(separator: ", ")
                }
                .joined(separator: ",\n")

            return """
                static var \(keyConfig.name): String {
                    let encoded: [UInt8] = [
            \(encodedLines)
                    ]
                    return decode(encoded, cipher: salt)
                }
            """
        }.joined(separator: "\n\n")

        return """
        // Generated by SwiftSecretKeys — do not edit.
        //
        // SECURITY NOTICE
        // ===============
        // This file uses XOR-based obfuscation, not encryption.
        // The obfuscation makes casual static inspection harder,
        // but does not prevent a determined attacker from recovering
        // the original values given access to the compiled binary.
        //
        // OWASP MASVS-RESILIENCE context: this technique provides
        // obfuscation (MASWE-0089 mitigation class), not cryptographic
        // protection. It is NOT a substitute for a secrets manager.
        //
        // Use this tool when:
        //   - Secrets are low-value or short-lived
        //   - You need to slow down, not prevent, casual inspection
        //
        // Do not use this tool when:
        //   - Secrets grant access to production systems
        //   - Exposure would cause regulatory or financial harm
        //   - A secrets manager or runtime injection is feasible
        import Foundation

        enum SecretKeys {
            private static let salt: [UInt8] = [
        \(saltLines)
            ]

        \(varBlocks)

            private static func decode(_ encoded: [UInt8], cipher: [UInt8]) -> String {
                String(
                    decoding: encoded.enumerated().map { offset, element in
                        element ^ cipher[offset % cipher.count]
                    },
                    as: UTF8.self
                )
            }
        }
        """
    }

    private func renderAESGCMOutput(keyBytes: [UInt8], keyConfigs: [AESKeyConfig]) -> String {
        let keyLines = chunked(array: keyBytes, into: 10)
            .map { chunk in
                "        " + chunk.map { String($0) }.joined(separator: ", ")
            }
            .joined(separator: ",\n")

        let varBlocks = keyConfigs.map { keyConfig in
            let combinedLines = chunked(array: keyConfig.combined, into: 10)
                .map { chunk in
                    "            " + chunk.map { String($0) }.joined(separator: ", ")
                }
                .joined(separator: ",\n")

            return """
                static var \(keyConfig.name): String {
                    let combined: [UInt8] = [
            \(combinedLines)
                    ]
                    return SecretKeys._decryptAESGCM(combined)
                }
            """
        }.joined(separator: "\n\n")

        return """
        // Generated by SwiftSecretKeys — do not edit.
        //
        // SECURITY NOTICE
        // ===============
        // This file uses AES-256-GCM obfuscation, not a secrets vault.
        // The AES key and nonce are embedded in this file alongside the ciphertext.
        // A determined attacker with access to the compiled binary can recover
        // the original values.
        //
        // OWASP MASVS-RESILIENCE context: this technique provides
        // obfuscation (MASWE-0089 mitigation class), not cryptographic
        // protection. It is NOT a substitute for a secrets manager.
        //
        // Use this tool when:
        //   - Secrets are low-value or short-lived
        //   - You need to slow down, not prevent, casual inspection
        //
        // Do not use this tool when:
        //   - Secrets grant access to production systems
        //   - Exposure would cause regulatory or financial harm
        //   - A secrets manager or runtime injection is feasible
        import Foundation
        #if canImport(CryptoKit)
        import CryptoKit
        #else
        import Crypto
        #endif

        enum SecretKeys {
            private static let aesKey: [UInt8] = [
        \(keyLines)
            ]

        \(varBlocks)

            private static func _decryptAESGCM(_ combined: [UInt8]) -> String {
                let key = SymmetricKey(data: Data(aesKey))
                guard let sealedBox = try? AES.GCM.SealedBox(combined: Data(combined)),
                      let plaintext = try? AES.GCM.open(sealedBox, using: key) else {
                    return ""
                }
                return String(decoding: plaintext, as: UTF8.self)
            }
        }
        """
    }
}
