import ArgumentParser
import Foundation
import SwiftSecretKeysCore

struct GenerateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate a .swift file with obfuscated secrets."
    )

    @Option(name: .shortAndLong, help: "Configuration file path.")
    var config: String = "sskeys.yml"

    @Option(name: .shortAndLong, help: "Custom cipher factor (salt length in bytes).")
    var factor: Int = 32

    @Flag(name: .shortAndLong, help: "Print processing steps to stderr.")
    var verbose: Bool = false

    @Option(name: .long, help: "Override output directory (used by SPM plugin).")
    var outputDir: String? = nil

    @Option(name: .long, help: "Path to a .env file to load before generation.")
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
        log("Config loaded: \(configPath) (\(loadedConfig.keys.count) keys)")
        log("Cipher mode: \(loadedConfig.cipher == .aesgcm ? "AES-256-GCM" : "XOR")")

        let generator = Generator(config: loadedConfig, saltLength: factor)
        if loadedConfig.cipher == .aesgcm {
            log("Generating AES-256-GCM cipher (32-byte key, fresh nonce per key)...")
        } else {
            log("Generating cipher (salt length: \(factor) bytes)...")
        }
        try generator.generate(outputDirectory: outputDir)

        let effectiveOutput: String
        if let dir = outputDir {
            effectiveOutput = dir
        } else {
            effectiveOutput = loadedConfig.output.isEmpty ? "./" : loadedConfig.output
        }
        log("Writing SecretKeys.swift to \(effectiveOutput)")
        print("Generated SecretKeys.swift at \(effectiveOutput)")
    }

    private func log(_ message: String) {
        guard verbose else { return }
        let data = Data(("[sskeys] " + message + "\n").utf8)
        FileHandle.standardError.write(data)
    }
}
