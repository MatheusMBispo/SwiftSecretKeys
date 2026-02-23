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

        let loadedConfig = try Config.load(from: contents)
        print("Config valid: \(loadedConfig.keys.count) key(s) resolved successfully.")
    }
}
