import Testing
import Foundation

@Suite("ValidateCommand Integration")
struct ValidateCommandTests {

    private func sskeysURL() throws -> URL {
        let buildDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".build/debug/sskeys")

        guard FileManager.default.fileExists(atPath: buildDir.path) else {
            Issue.record("sskeys binary not found at \(buildDir.path) — run swift build first")
            throw CocoaError(.fileNoSuchFile)
        }
        return buildDir
    }

    private func runSSKeys(args: [String], cwd: String? = nil, env: [String: String]? = nil) throws -> (exitCode: Int32, stdout: String, stderr: String) {
        let binary = try sskeysURL()
        let process = Process()
        process.executableURL = binary
        process.arguments = args
        if let cwd { process.currentDirectoryURL = URL(fileURLWithPath: cwd) }
        if let env { process.environment = env }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return (
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }

    private func withTempDir(_ body: (String) throws -> Void) throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sskeys-validate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try body(dir.path)
    }

    // MARK: - Flat Keys

    @Test("validate with flat keys config succeeds")
    func validateFlatKeys() throws {
        try withTempDir { dir in
            let configPath = "\(dir)/sskeys.yml"
            try "keys:\n  API_KEY: secret123\n  DB_HOST: localhost".write(toFile: configPath, atomically: true, encoding: .utf8)

            let result = try runSSKeys(args: ["validate", "--config", configPath])
            #expect(result.exitCode == 0)
            #expect(result.stdout.contains("2 key(s) resolved successfully"))
        }
    }

    // MARK: - --config Flag

    @Test("validate with custom config path via --config")
    func validateCustomConfigPath() throws {
        try withTempDir { dir in
            let configPath = "\(dir)/custom.yml"
            try "keys:\n  MY_KEY: value".write(toFile: configPath, atomically: true, encoding: .utf8)

            let result = try runSSKeys(args: ["validate", "--config", configPath])
            #expect(result.exitCode == 0)
            #expect(result.stdout.contains("1 key(s) resolved successfully"))
        }
    }

    @Test("validate fails with nonexistent config")
    func validateMissingConfig() throws {
        let result = try runSSKeys(args: ["validate", "--config", "/nonexistent/sskeys.yml"])
        #expect(result.exitCode != 0)
    }

    // MARK: - --environment Flag

    @Test("validate with --environment selects specific environment")
    func validateWithEnvironment() throws {
        try withTempDir { dir in
            let yaml = """
            environments:
              staging:
                API_KEY: staging-key
              production:
                API_KEY: prod-key
            """
            let configPath = "\(dir)/sskeys.yml"
            try yaml.write(toFile: configPath, atomically: true, encoding: .utf8)

            let result = try runSSKeys(args: ["validate", "--config", configPath, "--environment", "staging"])
            #expect(result.exitCode == 0)
            #expect(result.stdout.contains("1 key(s) resolved successfully"))
        }
    }

    // MARK: - All-Environments Fallback

    @Test("validate without --environment validates all environments")
    func validateAllEnvironments() throws {
        try withTempDir { dir in
            let yaml = """
            environments:
              staging:
                API_KEY: staging-key
              production:
                API_KEY: prod-key
            """
            let configPath = "\(dir)/sskeys.yml"
            try yaml.write(toFile: configPath, atomically: true, encoding: .utf8)

            let result = try runSSKeys(args: ["validate", "--config", configPath])
            #expect(result.exitCode == 0)
            #expect(result.stdout.contains("staging"))
            #expect(result.stdout.contains("production"))
        }
    }

    // MARK: - --env-file Flag

    @Test("validate with --env-file loads environment variables from file")
    func validateWithEnvFile() throws {
        try withTempDir { dir in
            let envPath = "\(dir)/.env"
            try "VALIDATE_TEST_SECRET=resolved-value".write(toFile: envPath, atomically: true, encoding: .utf8)

            let yaml = "keys:\n  MY_SECRET: ${VALIDATE_TEST_SECRET}"
            let configPath = "\(dir)/sskeys.yml"
            try yaml.write(toFile: configPath, atomically: true, encoding: .utf8)

            let result = try runSSKeys(args: ["validate", "--config", configPath, "--env-file", envPath])
            #expect(result.exitCode == 0)
            #expect(result.stdout.contains("1 key(s) resolved successfully"))
        }
    }

    // MARK: - Error Cases

    @Test("validate fails when env var is missing")
    func validateFailsOnMissingEnvVar() throws {
        try withTempDir { dir in
            let yaml = "keys:\n  MY_SECRET: ${SSKEYS_NONEXISTENT_VAR_12345}"
            let configPath = "\(dir)/sskeys.yml"
            try yaml.write(toFile: configPath, atomically: true, encoding: .utf8)

            let result = try runSSKeys(args: ["validate", "--config", configPath])
            #expect(result.exitCode != 0)
        }
    }

    @Test("validate fails on invalid YAML")
    func validateFailsOnInvalidYAML() throws {
        try withTempDir { dir in
            let configPath = "\(dir)/sskeys.yml"
            try "{{{{ not valid yaml".write(toFile: configPath, atomically: true, encoding: .utf8)

            let result = try runSSKeys(args: ["validate", "--config", configPath])
            #expect(result.exitCode != 0)
        }
    }

    @Test("validate fails for unknown environment name")
    func validateFailsOnUnknownEnvironment() throws {
        try withTempDir { dir in
            let yaml = """
            environments:
              staging:
                API_KEY: val
            """
            let configPath = "\(dir)/sskeys.yml"
            try yaml.write(toFile: configPath, atomically: true, encoding: .utf8)

            let result = try runSSKeys(args: ["validate", "--config", configPath, "--environment", "nonexistent"])
            #expect(result.exitCode != 0)
        }
    }
}
