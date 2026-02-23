import Foundation
import PackagePlugin

@main
struct SwiftSecretKeysPlugin: BuildToolPlugin {
    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) throws -> [Command] {
        let sskeys = try context.tool(named: "sskeys")

        // Search for sskeys.yml: target directory first, then package root.
        let targetConfig = target.directoryURL
            .appendingPathComponent("sskeys.yml")
        let packageConfig = context.package.directoryURL
            .appendingPathComponent("sskeys.yml")

        let configFile: URL
        if FileManager.default.fileExists(atPath: targetConfig.path) {
            configFile = targetConfig
        } else if FileManager.default.fileExists(atPath: packageConfig.path) {
            configFile = packageConfig
        } else {
            Diagnostics.error(
                "sskeys.yml not found for target '\(target.name)'. " +
                "Place sskeys.yml in the target's source directory or package root. " +
                "Skipping SwiftSecretKeys code generation."
            )
            return []
        }

        let outputFile = context.pluginWorkDirectoryURL
            .appendingPathComponent("SecretKeys.swift")

        return [
            .buildCommand(
                displayName: "SwiftSecretKeys: Generate SecretKeys.swift",
                executable: sskeys.url,
                arguments: [
                    "generate",
                    "--config", configFile.path,
                    "--output-dir", context.pluginWorkDirectoryURL.path,
                ],
                inputFiles: [configFile],
                outputFiles: [outputFile]
            )
        ]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension SwiftSecretKeysPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(
        context: XcodePluginContext,
        target: XcodeTarget
    ) throws -> [Command] {
        let sskeys = try context.tool(named: "sskeys")

        let projectConfig = context.xcodeProject.directoryURL
            .appendingPathComponent("sskeys.yml")

        guard FileManager.default.fileExists(atPath: projectConfig.path) else {
            Diagnostics.error(
                "sskeys.yml not found for Xcode target '\(target.displayName)'. " +
                "Place sskeys.yml at the project root. " +
                "Skipping SwiftSecretKeys code generation."
            )
            return []
        }

        let outputFile = context.pluginWorkDirectoryURL
            .appendingPathComponent("SecretKeys.swift")

        return [
            .buildCommand(
                displayName: "SwiftSecretKeys: Generate SecretKeys.swift",
                executable: sskeys.url,
                arguments: [
                    "generate",
                    "--config", projectConfig.path,
                    "--output-dir", context.pluginWorkDirectoryURL.path,
                ],
                inputFiles: [projectConfig],
                outputFiles: [outputFile]
            )
        ]
    }
}
#endif
