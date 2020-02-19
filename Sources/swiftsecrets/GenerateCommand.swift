import Foundation
import SwiftCLI
import SwiftShell
import Yams

enum GenerateCommandError: Error {
    case notFoundConfig
    case invalidConfig

    var localizedDescription: String {
        switch self {
        case .notFoundConfig:
            return "Error! Create a configuration file (SecretsConfig.yml) or set your custom path (--config)..."
        case .invalidConfig:
            return "Error! File cannot be generated (Verify the environments variables and the output path)..."
        }
    }
}

class GenerateCommand: Command {
    let name = "generate"
    var shortDescription: String = "Generate a file with secrets"

    @Key("-c", "--config", description: "Configuration file path")
    var config: String?

    @Key("-f", "--factor", description: "Custom cipher factor")
    var factor: Int?

    func execute() throws {
        let config: String

        if let givenConfig = self.config {
            config = givenConfig
        } else {
            config = "SecretsConfig.yml"
        }
        let path = main.currentdirectory + "/" + config
        let contents: String
        do {
            contents = try String(contentsOfFile: path)
        } catch {
            stdout <<< GenerateCommandError.notFoundConfig.localizedDescription
            return
        }

        do {
            let secrets = try Yams.load(yaml: contents) as? [String: Any]
            let values = secrets?["keys"] as? [String: String]
            let environmentValues = secrets?["environments"] as? [String]
            let output = secrets?["output"] as? String
            let generator = Generator(values: values ?? [:],
                                      environment: environmentValues ?? [],
                                      outputPath: output ?? "Secrets.swift", customFactor: factor ?? 32)
            try generator.generate()
        } catch {
            stdout <<< GenerateCommandError.invalidConfig.localizedDescription
            return
        }
    }
}
