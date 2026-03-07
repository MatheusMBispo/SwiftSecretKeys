import ArgumentParser
import Foundation
import SwiftSecretKeysCore

struct ValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Check config and resolve env vars without generating files."
    )

    @Option(name: .shortAndLong, help: "Configuration file path.")
    var config: String = "sskeys.yml"

    @Option(name: .long, help: "Path to a .env file to load before validation.")
    var envFile: String? = nil

    @Option(name: .shortAndLong, help: "Target environment to validate. Omit to validate all environments.")
    var environment: String? = nil

    mutating func run() throws {
        if let envFilePath = envFile {
            try DotEnvLoader.load(from: envFilePath)
        }

        let cwd = FileManager.default.currentDirectoryPath
        let configPath: String
        if config.hasPrefix("/") {
            configPath = config
        } else {
            configPath = URL(fileURLWithPath: cwd)
                .appendingPathComponent(config)
                .path
        }

        let contents: String
        do {
            contents = try String(contentsOfFile: configPath, encoding: .utf8)
        } catch {
            throw SSKeysError.configFileNotFound(path: configPath)
        }

        // Attempt load — if environmentRequired is thrown and no --environment provided,
        // fall back to validating all environments individually.
        do {
            let loadedConfig = try Config.load(from: contents, environment: environment)
            print("Config valid: \(loadedConfig.keys.count) key(s) resolved successfully.")
        } catch SSKeysError.environmentRequired {
            // All-environments fallback: probe environment names and validate each
            try validateAllEnvironments(contents: contents)
        }
    }

    // MARK: - Private

    private func validateAllEnvironments(contents: String) throws {
        let envNames = try Config.environmentNames(from: contents)

        guard !envNames.isEmpty else {
            throw SSKeysError.missingKeys
        }

        var allValid = true
        for envName in envNames {
            do {
                let envConfig = try Config.load(from: contents, environment: envName)
                print("Environment '\(envName)': valid — \(envConfig.keys.count) key(s) resolved successfully.")
            } catch {
                allValid = false
                let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                print("Environment '\(envName)': ERROR — \(description)")
            }
        }

        if !allValid {
            throw ExitCode.failure
        }
    }
}
