import Testing
import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
@testable import SwiftSecretKeysCore

@Suite("Config")
struct ConfigTests {

    @Test("loadsValidYAML: valid YAML with keys and output")
    func loadsValidYAML() throws {
        let yaml = """
        keys:
          API_KEY: my-secret-api-key
          DB_PASSWORD: supersecret
        output: Sources/Generated
        """
        let config = try Config.load(from: yaml)
        #expect(config.keys.count == 2)
        #expect(config.keys["API_KEY"] == "my-secret-api-key")
        #expect(config.keys["DB_PASSWORD"] == "supersecret")
        #expect(config.output == "Sources/Generated")
    }

    @Test("loadsYAMLWithoutOutput: YAML with only keys, no output field")
    func loadsYAMLWithoutOutput() throws {
        let yaml = """
        keys:
          API_KEY: my-secret-api-key
        """
        let config = try Config.load(from: yaml)
        #expect(config.keys.count == 1)
        #expect(config.output == "")
    }

    @Test("throwsMissingKeys: empty keys dict throws missingKeys")
    func throwsMissingKeys() throws {
        let yaml = """
        keys: {}
        output: Sources/Generated
        """
        #expect(throws: SSKeysError.missingKeys) {
            try Config.load(from: yaml)
        }
    }

    @Test("throwsInvalidConfigOnBadYAML: completely invalid YAML throws invalidConfig")
    func throwsInvalidConfigOnBadYAML() throws {
        let yaml = "this is not valid YAML: [unclosed bracket"
        #expect(throws: (any Error).self) {
            try Config.load(from: yaml)
        }
    }

    @Test("throwsInvalidConfigOnMissingKeysField: YAML without keys field throws invalidConfig")
    func throwsInvalidConfigOnMissingKeysField() throws {
        let yaml = """
        output: Sources/Generated
        """
        #expect(throws: (any Error).self) {
            try Config.load(from: yaml)
        }
    }

    @Test("resolvesEnvironmentVariable: env var in YAML value is resolved")
    func resolvesEnvironmentVariable() throws {
        let testVarName = "SSKEYS_TEST_VAR_RESOLVE_12345"
        let testVarValue = "resolved-secret-value"
        setenv(testVarName, testVarValue, 1)
        defer { unsetenv(testVarName) }

        let yaml = """
        keys:
          API_KEY: ${\(testVarName)}
        """
        let config = try Config.load(from: yaml)
        #expect(config.keys["API_KEY"] == testVarValue)
    }

    @Test("throwsOnMissingEnvironmentVariable: missing env var throws environmentVariableNotFound")
    func throwsOnMissingEnvironmentVariable() throws {
        let missingVar = "SSKEYS_NONEXISTENT_VAR_12345"
        unsetenv(missingVar)

        let yaml = """
        keys:
          API_KEY: ${\(missingVar)}
        """
        #expect(throws: SSKeysError.environmentVariableNotFound(name: missingVar)) {
            try Config.load(from: yaml)
        }
    }

    @Test("cipherDefaultsToXOR: no cipher field defaults to .xor")
    func cipherDefaultsToXOR() throws {
        let yaml = """
        keys:
          API_KEY: my-secret
        """
        let config = try Config.load(from: yaml)
        #expect(config.cipher == .xor)
    }

    @Test("cipherParsesXOR: cipher: xor parses as .xor")
    func cipherParsesXOR() throws {
        let yaml = """
        cipher: xor
        keys:
          API_KEY: my-secret
        """
        let config = try Config.load(from: yaml)
        #expect(config.cipher == .xor)
    }

    @Test("cipherParsesAESGCM: cipher: aes-gcm parses as .aesgcm")
    func cipherParsesAESGCM() throws {
        let yaml = """
        cipher: aes-gcm
        keys:
          API_KEY: my-secret
        """
        let config = try Config.load(from: yaml)
        #expect(config.cipher == .aesgcm)
    }

    @Test("invalidCipherThrows: unrecognized cipher value throws invalidCipher")
    func invalidCipherThrows() throws {
        let yaml = """
        cipher: blowfish
        keys:
          API_KEY: my-secret
        """
        #expect(throws: SSKeysError.invalidCipher(value: "blowfish")) {
            try Config.load(from: yaml)
        }
    }
}
