import ArgumentParser
import Foundation
import SwiftSecretKeysCore

struct GenerateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate a Swift file with obfuscated secrets."
    )

    @Option(name: .shortAndLong, help: "Configuration file path.")
    var config: String = "sskeys.yml"

    @Option(name: .long, help: "Output directory (overrides config output path).")
    var outputDir: String? = nil

    @Option(name: .shortAndLong, help: "Salt length for XOR cipher.")
    var factor: Int = 32

    @Option(name: .shortAndLong, help: "Target environment name.")
    var environment: String? = nil

    @Option(name: .long, help: "Path to a .env file to load before generation.")
    var envFile: String? = nil

    @Flag(name: .shortAndLong, help: "Print verbose output.")
    var verbose: Bool = false

    @Flag(name: .long, help: "Print generated output to stdout instead of writing a file.")
    var dryRun: Bool = false

    mutating func run() throws {
        if let envFilePath = envFile {
            try DotEnvLoader.load(from: envFilePath)
        }

        let configPath: String
        if config.hasPrefix("/") {
            configPath = config
        } else {
            let cwd = FileManager.default.currentDirectoryPath
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

        if verbose {
            print("Config: \(configPath)")
            if let env = environment {
                print("Environment: \(env)")
            }
        }

        let loadedConfig = try Config.load(from: contents, environment: environment)

        if verbose {
            print("Keys: \(loadedConfig.keys.count)")
            print("Cipher: \(loadedConfig.cipher.rawValue)")
        }

        let generator = Generator(config: loadedConfig, saltLength: factor)
        try generator.generate(outputDirectory: outputDir, dryRun: dryRun)

        if verbose && !dryRun {
            print("Generated SecretKeys.swift successfully.")
        }
    }
}
