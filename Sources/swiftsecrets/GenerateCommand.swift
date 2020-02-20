import Foundation
import Regex
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

        let secrets = try Yams.load(yaml: contents) as? [String: Any]
        let keys = try readKeys(from: secrets)
        let output = secrets?["output"] as? String
        let generator = Generator(values: keys,
                                  outputPath: output ?? "",
                                  customFactor: factor ?? 32)
        try generator.generate()
    }

    func readKeys(from secrets: [String: Any]?) throws -> [String: String] {
        guard let keys = secrets?["keys"] as? [String: String] else {
            return [:]
        }

        var auxKeys = [String: String]()
        for (key, value) in keys {
            auxKeys[key] = try convertToRealValue(value)
        }

        return auxKeys
    }

    func convertToRealValue(_ value: String) throws -> String {
        if isEnvironment(value) {
            let filteredValue = value.replacingFirst(matching: "(\\$\\{)(\\w{1,})(\\})", with: "$2")
            guard let environmentValue = ProcessInfo.processInfo.environment[filteredValue] else {
                throw GeneratorError.invalidEnvironmentVariable
            }
            return environmentValue
        } else {
            return value
        }
    }

    func isEnvironment(_ value: String) -> Bool {
        return Regex("\\$\\{(\\w{1,})\\}").matches(value)
    }
}
