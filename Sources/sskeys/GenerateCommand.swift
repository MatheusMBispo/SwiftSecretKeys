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

    @Flag(name: .long, help: "Print generated output to stdout without writing files.")
    var dryRun: Bool = false

    @Option(name: .shortAndLong, help: "Target environment (dev/staging/prod) when using environments: block.")
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

        let loadedConfig = try Config.load(from: contents, environment: environment)
        log("Config loaded: \(configPath) (\(loadedConfig.keys.count) keys)")
        let cipherLabel: String
        switch loadedConfig.cipher {
        case .xor: cipherLabel = "XOR"
        case .aesgcm: cipherLabel = "AES-256-GCM"
        case .chacha20: cipherLabel = "ChaCha20-Poly1305"
        }
        log("Cipher mode: \(cipherLabel)")

        let generator = Generator(config: loadedConfig, saltLength: factor)
        switch loadedConfig.cipher {
        case .aesgcm:
            log("Generating AES-256-GCM cipher (32-byte key, fresh nonce per key)...")
        case .chacha20:
            log("Generating ChaCha20-Poly1305 cipher (32-byte key, fresh nonce per key)...")
        case .xor:
            log("Generating cipher (salt length: \(factor) bytes)...")
        }
        try generator.generate(outputDirectory: outputDir, dryRun: dryRun)

        if !dryRun {
            let effectiveOutput: String
            if let dir = outputDir {
                effectiveOutput = dir
            } else {
                effectiveOutput = loadedConfig.output.isEmpty ? "./" : loadedConfig.output
            }
            log("Writing SecretKeys.swift to \(effectiveOutput)")
            print("Generated SecretKeys.swift at \(effectiveOutput)")
        }
    }

    private func log(_ message: String) {
        guard verbose else { return }
        let data = Data(("[sskeys] " + message + "\n").utf8)
        FileHandle.standardError.write(data)
    }
}
