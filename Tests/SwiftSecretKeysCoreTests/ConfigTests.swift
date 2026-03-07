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

    @Test("throwsInvalidConfigOnMissingKeysField: YAML without keys or environments field throws error")
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

    @Test("multipleEnvVarsInSingleValue: multiple ${VAR} refs in one value all resolve")
    func multipleEnvVarsInSingleValue() throws {
        let varA = "SSKEYS_MULTI_A_12345"
        let varB = "SSKEYS_MULTI_B_12345"
        setenv(varA, "alpha", 1)
        setenv(varB, "beta", 1)
        defer {
            unsetenv(varA)
            unsetenv(varB)
        }

        let yaml = """
        keys:
          CONNECTION: "host=${\(varA)};db=${\(varB)}"
        """
        let config = try Config.load(from: yaml)
        #expect(config.keys["CONNECTION"] == "host=alpha;db=beta")
    }

    @Test("multipleEnvVarsPartialMissing: throws on first missing var even when others are set")
    func multipleEnvVarsPartialMissing() throws {
        let varA = "SSKEYS_PARTIAL_A_12345"
        let varB = "SSKEYS_PARTIAL_B_MISSING_12345"
        setenv(varA, "present", 1)
        unsetenv(varB)
        defer { unsetenv(varA) }

        let yaml = """
        keys:
          CONNECTION: "${\(varA)}:${\(varB)}"
        """
        #expect(throws: SSKeysError.environmentVariableNotFound(name: varB)) {
            try Config.load(from: yaml)
        }
    }

    // MARK: - Multi-environment tests

    @Test("environmentsBlockLoadsSelectedEnvironment: environments: block with environment param loads correct keys")
    func environmentsBlockLoadsSelectedEnvironment() throws {
        let yaml = """
        environments:
          dev:
            API_KEY: dev-secret
            DB_HOST: dev.db.local
          staging:
            API_KEY: staging-secret
            DB_HOST: staging.db.example.com
        cipher: xor
        """
        let config = try Config.load(from: yaml, environment: "dev")
        #expect(config.keys.count == 2)
        #expect(config.keys["API_KEY"] == "dev-secret")
        #expect(config.keys["DB_HOST"] == "dev.db.local")
    }

    @Test("environmentsBlockThrowsWithoutFlag: environments: block without environment param throws environmentRequired")
    func environmentsBlockThrowsWithoutFlag() throws {
        let yaml = """
        environments:
          dev:
            API_KEY: dev-secret
          staging:
            API_KEY: staging-secret
        """
        #expect(throws: SSKeysError.environmentRequired) {
            try Config.load(from: yaml)
        }
    }

    @Test("environmentNotFoundThrows: unknown environment name throws environmentNotFound")
    func environmentNotFoundThrows() throws {
        let yaml = """
        environments:
          dev:
            API_KEY: dev-secret
          staging:
            API_KEY: staging-secret
        """
        #expect(throws: SSKeysError.environmentNotFound(name: "prod", available: ["dev", "staging"])) {
            try Config.load(from: yaml, environment: "prod")
        }
    }

    @Test("bothKeysAndEnvironmentsThrows: config with both keys: and environments: throws invalidConfig")
    func bothKeysAndEnvironmentsThrows() throws {
        let yaml = """
        keys:
          FLAT_KEY: flat-value
        environments:
          dev:
            API_KEY: dev-secret
        """
        #expect(throws: (any Error).self) {
            try Config.load(from: yaml, environment: "dev")
        }
        // Verify the error message mentions "Cannot use both"
        do {
            _ = try Config.load(from: yaml, environment: "dev")
        } catch let error as SSKeysError {
            if case let .invalidConfig(reason) = error {
                #expect(reason.contains("Cannot use both"))
            } else {
                #expect(Bool(false), "Expected invalidConfig error, got: \(error)")
            }
        }
    }

    @Test("flatKeysIgnoresEnvironmentParam: flat keys: config silently ignores environment param")
    func flatKeysIgnoresEnvironmentParam() throws {
        let yaml = """
        keys:
          API_KEY: flat-secret
          DB_PASSWORD: flat-db-pass
        """
        let config = try Config.load(from: yaml, environment: "dev")
        #expect(config.keys.count == 2)
        #expect(config.keys["API_KEY"] == "flat-secret")
        #expect(config.keys["DB_PASSWORD"] == "flat-db-pass")
    }

    @Test("environmentsBlockResolvesEnvVars: env vars inside environments: block are resolved")
    func environmentsBlockResolvesEnvVars() throws {
        let varName = "SSKEYS_ENV_BLOCK_VAR_12345"
        let varValue = "resolved-env-block-value"
        setenv(varName, varValue, 1)
        defer { unsetenv(varName) }

        let yaml = """
        environments:
          dev:
            API_KEY: ${\(varName)}
        """
        let config = try Config.load(from: yaml, environment: "dev")
        #expect(config.keys["API_KEY"] == varValue)
    }

    @Test("crossEnvironmentSanitizationCatchesCollisions: key name collisions in non-selected env throw eagerly")
    func crossEnvironmentSanitizationCatchesCollisions() throws {
        // staging has api-key and api.key which both sanitize to api_key — collision
        // We request dev, but staging's cross-env check should still throw
        let yaml = """
        environments:
          dev:
            api_key: dev-val
          staging:
            api-key: staging-val1
            api.key: staging-val2
        """
        #expect(throws: (any Error).self) {
            try Config.load(from: yaml, environment: "dev")
        }
        // Verify the error message mentions "staging"
        do {
            _ = try Config.load(from: yaml, environment: "dev")
        } catch let error as SSKeysError {
            if case let .invalidConfig(reason) = error {
                #expect(reason.contains("staging"))
            } else {
                #expect(Bool(false), "Expected invalidConfig error, got: \(error)")
            }
        }
    }

    @Test("environmentsBlockPreservesCipher: cipher field is respected when using environments: block")
    func environmentsBlockPreservesCipher() throws {
        let yaml = """
        cipher: aes-gcm
        environments:
          dev:
            API_KEY: dev-secret
        """
        let config = try Config.load(from: yaml, environment: "dev")
        #expect(config.cipher == .aesgcm)
    }

    @Test("emptyEnvironmentsDictThrowsMissingKeys: environments: {} throws missingKeys")
    func emptyEnvironmentsDictThrowsMissingKeys() throws {
        let yaml = """
        environments: {}
        """
        #expect(throws: SSKeysError.missingKeys) {
            try Config.load(from: yaml)
        }
    }
}
